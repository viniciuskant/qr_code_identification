function qrcode()
    pastaHierarquia = 'output/hierarquia';
    pastaCoordenadas = 'output/coordenadas';
    pastaBinarizada = 'output/binarizacao';
    pastaDebug = 'output/debug';
    VERBOSE = false;
    
    if ~exist(pastaHierarquia, 'dir') && VERBOSE, mkdir(pastaHierarquia); end
    if ~exist(pastaCoordenadas, 'dir'), mkdir(pastaCoordenadas); end
    if ~exist(pastaBinarizada, 'dir'), binariza(); end
    if ~exist(pastaDebug, 'dir'), mkdir(pastaDebug); end

    arquivos = dir(fullfile(pastaBinarizada, '*.tif'));
    if isempty(arquivos)
        fprintf('Nenhum arquivo .tif encontrado em "%s".\n', pastaBinarizada);
        return;
    end

    for k = 1:length(arquivos)
        nomeArquivo = arquivos(k).name;
        [~, nomeBase, ~] = fileparts(nomeArquivo);
        caminhoCompleto = fullfile(pastaBinarizada, nomeArquivo);
        
        img = imread(caminhoCompleto);
        M = (img ~= 0);  
        M(isnan(M) | isinf(M)) = 0;
        img_bin = repmat(uint8(M) * 255, [1, 1, 3]);
        bordas = bordas_op(M);
        arvore = arvore_hierarquia(bordas);
        
        hierarquia_img = obter_hierarquia(arvore);

        % imagem auxiliar, filtro de profundidade (vermelho)
        img_path = fullfile(pastaHierarquia, [nomeBase '_profundidade.png']);
        [profundidade, img_profundidade] = filtro_por_profundidade(hierarquia_img, bordas, 3, img_path, VERBOSE);
        if img_profundidade == -1 continue; end

        % imagem auxiliar para candidatos (amarelo)
        img_path = fullfile(pastaDebug, [nomeBase '_etapa1_candidatos.png']);
        [candidatos, img_candidatos] = filtro_por_formato(arvore, profundidade, bordas, img_path, VERBOSE);
        
        finder_labels = [];
        img_grupos = zeros([size(bordas), 3], 'uint8');
        img_patterns = zeros([size(bordas), 3], 'uint8');

        if length(candidatos) >= 3
            % imagem auxiliar de agrupamento por tamanho (varias cores)
            img_path =  fullfile(pastaDebug, [nomeBase '_etapa2_grupos_por_tamanho.png']);
            [img_grupos, grupos] = agrupa_por_tamanho(candidatos, img_grupos, img_path, VERBOSE);

            if ~isempty(grupos)
                %img com a escolha dos melhores 3 pontos em verde
                img_path = fullfile(pastaDebug, [nomeBase '_etapa3_filtro_grupo_selecionado.png']);
                altura = size(bordas, 1);
                largura = size(bordas, 2);
                min_area = round((largura * altura ) * 0.05);
                min_ratio = 0.6;
                max_angulo = 0.1;
                colinear_threshold = 0.15;
                [img_patterns, melhor_grupo] = melhor_combinacao_3(bordas, candidatos, grupos, img_path, min_area, min_ratio, max_angulo, colinear_threshold, VERBOSE);
                
                finder_labels = [candidatos(melhor_grupo).obj];
            end
        else
            fprintf('Menos de 3 candidatos, impossível formar grupo.\n');
        end

        arquivo_coord = fullfile(pastaCoordenadas, [nomeBase '.txt']);
        fid = fopen(arquivo_coord, 'w');
        if fid == -1
            warning('Não foi possível criar o arquivo %s', arquivo_coord);
        else
            if ~isempty(finder_labels) && ~isempty(melhor_grupo) && length(melhor_grupo) == 3
                x1 = candidatos(melhor_grupo(1)).centro(1);
                y1 = candidatos(melhor_grupo(1)).centro(2);
                x2 = candidatos(melhor_grupo(2)).centro(1);
                y2 = candidatos(melhor_grupo(2)).centro(2);
                x3 = candidatos(melhor_grupo(3)).centro(1);
                y3 = candidatos(melhor_grupo(3)).centro(2);
                coords = round([x1, y1, x2, y2, x3, y3]);
                fprintf(fid, '%d %d %d %d %d %d', coords);
                fprintf('Coordenadas salvas em %s: %s\n', arquivo_coord, num2str(coords));
            else
                fprintf(fid, '0 0 0 0 0 0');
                fprintf('Nenhum finder pattern encontrado para %s -> zeros salvos em %s\n', nomeBase, arquivo_coord);
            end
            fclose(fid);
        end

        painel = [img_bin, img_profundidade, img_candidatos, img_grupos, img_patterns];
        imwrite(painel, fullfile(pastaDebug, [nomeBase '_etapa5_painel_final.png']));

        fprintf('Fim do processamento para: %s\n\n', nomeArquivo);
    end
end


function [img_patterns, melhor_grupo] = melhor_combinacao_3(bordas, candidatos, grupos, img_path, min_area, min_ratio, max_angulo, colinear_threshold, VERBOSE)
    if nargin < 5, min_area = 10; end
    if nargin < 6, min_ratio = 0.7; end
    if nargin < 7, max_angulo = 0.1; end
    if nargin < 8, colinear_threshold = 0.15; end
    if nargin < 9, VERBOSE = false; end

    %todas as combinações de 3 a partir de todos os grupos
    combos_cell = {};
    for g = 1:length(grupos)
        grupo_atual = grupos{g};
        if length(grupo_atual) >= 3
            combos_grupo = nchoosek(grupo_atual, 3);
            for c = 1:size(combos_grupo, 1)
                combos_cell{end+1} = combos_grupo(c, :);
            end
        end
    end

    if ~isempty(combos_cell)
        combos = cell2mat(combos_cell'); 
    else
        combos = [];
    end

    best_excelente = []; best_excelente_score = -inf;
    best_bom = []; best_bom_angulo = inf;
    best_razovel = []; best_razovel_ratio = -inf;
    best_minimo_razovel = []; best_minimo_razovel_area = -inf;
    best_minimo_extremo = []; best_maximo_extremo_angulo = inf;
    best_fallback = []; best_fallback_ratio = -inf; % ignora colinearidade

    for c = 1:size(combos, 1)
        idxs = combos(c, :);
        p1 = candidatos(idxs(1)).centro;
        p2 = candidatos(idxs(2)).centro;
        p3 = candidatos(idxs(3)).centro;

        % razões
        d12 = norm(p1-p2);
        d13 = norm(p1-p3);
        d23 = norm(p2-p3);
        ratio1 = min(d12,d13)/max(d12,d13);
        ratio2 = min(d12,d23)/max(d12,d23);
        ratio3 = min(d13,d23)/max(d13,d23);
        min_ratio_combo = min([ratio1, ratio2, ratio3]);

        %colinearidade
        area = abs((p2(1)-p1(1))*(p3(2)-p1(2)) - (p3(1)-p1(1))*(p2(2)-p1(2))) / 2;
        d_max = max([d12, d13, d23]);
        colinearidade = area / (d_max^2);

        % angulo
        angulo = escolhe_melhor_angulo(p1, p2, p3);
        % fprintf('angulo %.4f\n', angulo)

        % Fallback – sempre atualiza com maior razão
        if min_ratio_combo > best_fallback_ratio
            best_fallback_ratio = min_ratio_combo;
            best_fallback = idxs;
        end

        % Se for colinear demais, pula (não serve para nenhum critério geométrico)
        if colinearidade <= colinear_threshold
            continue;
        end

        % MINIMO_EXTREMO (apenas colinear)
        if angulo < best_maximo_extremo_angulo
            best_maximo_extremo_angulo = angulo;
            best_minimo_extremo = idxs;
        end

        % MINIMO_RAZOAVEL (angulo <= max_angulo + colinear)
        if angulo <= max_angulo
            if area > best_minimo_razovel_area
                best_minimo_razovel_area = area;
                best_minimo_razovel = idxs;
            end

            % RAZOAVEL (area >= min_area + angulo + colinear)
            if area >= min_area
                if min_ratio_combo > best_razovel_ratio
                    best_razovel_ratio = min_ratio_combo;
                    best_razovel = idxs;
                end

                % BOM (ratio >= min_ratio + area + angulo + colinear)
                if min_ratio_combo >= min_ratio
                    if angulo < best_bom_angulo
                        best_bom_angulo = angulo;
                        best_bom = idxs;
                    end

                    % EXCELENTE
                    if (min_ratio_combo >= min([1.2 * min_ratio, 1])) && (angulo <= 0.4 * max_angulo)
                        score_excelente = min_ratio_combo;
                        if score_excelente > best_excelente_score
                            best_excelente_score = score_excelente;
                            best_excelente = idxs;
                        end
                    end
                end
            end
        end
    end

    % Seleção final pela ordem de prioridade
    if ~isempty(best_excelente)
        melhor_combo = best_excelente;
        if VERBOSE
            fprintf('\nSelecionado: EXCELENTE\n');
        end
    elseif ~isempty(best_bom)
        melhor_combo = best_bom;
        if VERBOSE
            fprintf('\nSelecionado: BOM (razão>=%.2f + área>=%d + ângulo>=%.2f + colinear, desempate: menor ângulo = %.2f)\n', ...
                min_ratio, min_area, max_angulo, best_bom_angulo);
        end
    elseif ~isempty(best_razovel)
        melhor_combo = best_razovel;
        if VERBOSE
            fprintf('\nSelecionado: RAZOÁVEL (área>=%d + ângulo>=%.2f + colinear, desempate: maior razão = %.4f)\n', ...
                min_area, max_angulo, best_razovel_ratio);
        end
    elseif ~isempty(best_minimo_razovel)
        melhor_combo = best_minimo_razovel;
        if VERBOSE
            fprintf('\nSelecionado: MÍNIMO_RAZOÁVEL (ângulo>=%.2f + colinear, desempate: maior área = %.2f)\n', ...
                max_angulo, best_minimo_razovel_area);
        end
    elseif ~isempty(best_minimo_extremo)
        melhor_combo = best_minimo_extremo;
        if VERBOSE
            fprintf('\nSelecionado: MÍNIMO_EXTREMO (apenas colinear, desempate: menor angulo = %.4f)\n', ...
                best_maximo_extremo_angulo);
        end
    else
        melhor_combo = best_fallback;
        if VERBOSE
            fprintf('\nSelecionado: FALLBACK (ignora colinearidade, maior razão = %.4f)\n', best_fallback_ratio);
        end
    end
    
    melhor_grupo = melhor_combo;
    
    img_patterns = zeros([size(bordas), 3], 'uint8');
    if isempty(melhor_grupo)
        fprintf('Nenhum candidato\n');
    else 
        for idx = melhor_grupo
            for ii = 1:length(candidatos(idx).lin)
                img_patterns(candidatos(idx).lin(ii), candidatos(idx).col(ii), 2) = 255;
            end
        end
    end

    if VERBOSE imwrite(img_patterns, img_path); end
end

function melhor_dist_vertice = escolhe_melhor_angulo(p1, p2, p3)
    % produto interno
    v12 = p2 - p1;
    v13 = p3 - p1;

    erro1 = abs(dot(v12,v13)) / (norm(v12)*norm(v13));

    v21 = p1 - p2;
    v23 = p3 - p2;

    erro2 = abs(dot(v21,v23)) / (norm(v21)*norm(v23));

    v31 = p1 - p3;
    v32 = p2 - p3;

    erro3 = abs(dot(v31,v32)) / (norm(v31)*norm(v32));

    melhor_dist_vertice = min([erro1 erro2 erro3]);
end

function [img_grupos, grupos] = agrupa_por_tamanho(candidatos, img_grupos, img_path, VERBOSE)
    if nargin < 4, VERBOSE = false; end

    n_cand = length(candidatos);
    similar = false(n_cand);
    for i = 1:n_cand
        for j = i+1:n_cand
            if abs(candidatos(i).tamanho - candidatos(j).tamanho)  / max(candidatos(i).tamanho, candidatos(j).tamanho) <= 0.20
                similar(i,j) = true;
                similar(j,i) = true;
            end
        end
    end
    
    grupos = {};
    visitado = false(1, n_cand);
    for i = 1:n_cand
        if ~visitado(i)
            grupo = [];
            pilha = i;
            while ~isempty(pilha)
                atual = pilha(1);
                pilha(1) = [];
                if ~visitado(atual)
                    visitado(atual) = true;
                    grupo(end+1) = atual;
                    for j = 1:n_cand
                        if similar(atual, j) && ~visitado(j)
                            pilha(end+1) = j;
                        end
                    end
                end
            end
            if length(grupo) >= 3
                grupos{end+1} = grupo;
            end
        end
    end
    
    % imagem dos grupos (cada grupo uma cor)
    cores = [255,0,0; 0,255,0; 0,0,255; 255,255,0; 255,0,255; 0,255,255];
    for g = 1:length(grupos)
        cor = cores(mod(g-1, size(cores,1))+1,:);
        for idx = grupos{g}
            for ii = 1:length(candidatos(idx).lin)
                img_grupos(candidatos(idx).lin(ii), candidatos(idx).col(ii), 1) = cor(1);
                img_grupos(candidatos(idx).lin(ii), candidatos(idx).col(ii), 2) = cor(2);
                img_grupos(candidatos(idx).lin(ii), candidatos(idx).col(ii), 3) = cor(3);
            end
            img_grupos = desenhar_poligono(img_grupos, candidatos(idx).corners);
        end
    end
    if VERBOSE imwrite(img_grupos, img_path); end
end

function [candidatos, img_candidatos] = filtro_por_formato(arvore, profundidade, bordas, img_path, VERBOSE)
    if nargin < 3, VERBOSE = false; end

    img_candidatos = zeros([size(bordas), 3], 'uint8');
    
    candidatos = [];
    for obj = profundidade
        [lin, col] = find(abs(bordas) == obj);
        [corners, largura, altura] = obter_retangulo_orientado(lin, col);
        razao = largura / altura;
        if (razao >= 0.7 && razao <= 1.3) || (1/razao >= 0.7 && 1/razao <= 1.3)
            if isKey(arvore.obj_children, obj) && ~isempty(arvore.obj_children(obj))
                tamanho = (largura + altura) / 2;
                centro = [mean(lin), mean(col)];
                candidatos(end+1).obj = obj;
                candidatos(end).tamanho = tamanho;
                candidatos(end).centro = centro;
                candidatos(end).corners = corners;
                candidatos(end).lin = lin;
                candidatos(end).col = col;
                for idx = 1:length(lin)
                    img_candidatos(lin(idx), col(idx), 1) = 255;
                    img_candidatos(lin(idx), col(idx), 2) = 255;
                    img_candidatos(lin(idx), col(idx), 3) = 0;
                end
                img_candidatos = desenhar_poligono(img_candidatos, corners);
            end
        end
    end

    if VERBOSE imwrite(img_candidatos, img_path); end
end

function  [profundidade, img_profundidade] = filtro_por_profundidade(hierarquia_img, bordas, profundidade_min, img_path, VERBOSE)
    if nargin < 5, VERBOSE = false; end

    profundidade = []; 
    for obj = hierarquia_img.keys()
        if hierarquia_img(obj{1}) >= profundidade_min
            profundidade(end+1) = obj{1};
        end
    end

    if isempty(profundidade)
        fprintf('Nenhuma hierarquia em %s\n', nomeBase);
        img_profundidade = -1;
        return;
    end

    % objetos com mais de x hierarquias em vermelho
    img_profundidade = zeros([size(bordas), 3], 'uint8');
    todos_objetos = unique(abs(bordas(abs(bordas)>0)));
    for obj = todos_objetos'
        [lin, col] = find(abs(bordas) == obj);
        if ismember(obj, profundidade)
            for idx = 1:length(lin)
                img_profundidade(lin(idx), col(idx), 1) = 255;
            end
        else
            for idx = 1:length(lin)
                img_profundidade(lin(idx), col(idx), 1) = 128;
                img_profundidade(lin(idx), col(idx), 2) = 128;
                img_profundidade(lin(idx), col(idx), 3) = 128;
            end
        end
    end

    if VERBOSE imwrite(img_profundidade, img_path); end
end

function [corners, largura, altura] = obter_retangulo_orientado(lin, col)
    pontos = [col, lin];
    pontos = unique(pontos, 'rows');
    n = size(pontos, 1);
    
    if n < 3
        % Objeto com 1 ou 2 pontos: bounding box alinhado
        min_x = min(pontos(:,1)); max_x = max(pontos(:,1));
        min_y = min(pontos(:,2)); max_y = max(pontos(:,2));
        largura = max_x - min_x;
        altura = max_y - min_y;
        corners = [min_x, min_y; max_x, min_y; max_x, max_y; min_x, max_y];
        return;
    end
    
    % Calcula o convex hull, tratando colinearidade
    try
        hull_idx = convhull(pontos(:,1), pontos(:,2));
    catch
        % Se falhar, usa bounding box alinhado
        min_x = min(pontos(:,1)); max_x = max(pontos(:,1));
        min_y = min(pontos(:,2)); max_y = max(pontos(:,2));
        largura = max_x - min_x;
        altura = max_y - min_y;
        corners = [min_x, min_y; max_x, min_y; max_x, max_y; min_x, max_y];
        return;
    end
    
    hull = pontos(hull_idx, :);
    n_hull = size(hull, 1);
    if n_hull <= 2
        min_x = min(pontos(:,1)); max_x = max(pontos(:,1));
        min_y = min(pontos(:,2)); max_y = max(pontos(:,2));
        largura = max_x - min_x;
        altura = max_y - min_y;
        corners = [min_x, min_y; max_x, min_y; max_x, max_y; min_x, max_y];
        return;
    end
    
    % Rotating calipers (igual ao original)
    area_min = inf;
    angulo_opt = 0;
    ret_opt = [];
    for i = 1:n_hull-1
        p1 = hull(i, :);
        p2 = hull(i+1, :);
        vetor = p2 - p1;
        angulo = atan2(vetor(2), vetor(1));
        R = [cos(-angulo), -sin(-angulo); sin(-angulo), cos(-angulo)];
        pts_rot = (R * pontos')';
        min_x = min(pts_rot(:,1)); max_x = max(pts_rot(:,1));
        min_y = min(pts_rot(:,2)); max_y = max(pts_rot(:,2));
        area = (max_x - min_x) * (max_y - min_y);
        if area < area_min
            area_min = area;
            angulo_opt = angulo;
            ret_opt = [min_x, max_x, min_y, max_y];
        end
    end
    min_x = ret_opt(1); max_x = ret_opt(2);
    min_y = ret_opt(3); max_y = ret_opt(4);
    rect_local = [min_x, min_y; max_x, min_y; max_x, max_y; min_x, max_y];
    R_inv = [cos(angulo_opt), -sin(angulo_opt); sin(angulo_opt), cos(angulo_opt)];
    corners = (R_inv * rect_local')';
    largura = max_x - min_x;
    altura = max_y - min_y;
end

function img = desenhar_poligono(img, pontos, cor)
    if nargin < 3, cor = [255, 51, 153]; end

    pontos = round(pontos);
    n = size(pontos, 1);

    for i = 1:n
        p1 = pontos(i, :);
        p2 = pontos(mod(i, n) + 1, :);
        img = desenhar_linha(img, p1(1), p1(2), p2(1), p2(2), cor);
    end

    centro = mean(pontos, 1);
    cx = round(centro(1));
    cy = round(centro(2));

    tamanho_mais = 2;

    img = desenhar_linha(img, cx - tamanho_mais, cy, cx + tamanho_mais, cy, cor);
    img = desenhar_linha(img, cx, cy - tamanho_mais, cx, cy + tamanho_mais, cor);
end

function img = desenhar_linha(img, x0, y0, x1, y1, cor)
    % Algoritmo de Bresenham
    dx = abs(x1 - x0);
    dy = -abs(y1 - y0);
    sx = sign(x1 - x0);
    sy = sign(y1 - y0);
    err = dx + dy;
    while true
        if x0 >= 1 && x0 <= size(img,2) && y0 >= 1 && y0 <= size(img,1)
            img(y0, x0, 1) = cor(1);
            img(y0, x0, 2) = cor(2);
            img(y0, x0, 3) = cor(3);
        end
        if x0 == x1 && y0 == y1, break; end
        e2 = 2 * err;
        if e2 >= dy
            err = err + dy;
            x0 = x0 + sx;
        end
        if e2 <= dx
            err = err + dx;
            y0 = y0 + sy;
        end
    end
end

function r = circumradius(p1, p2, p3)
    % Calcula o raio da circunferência circunscrita a três pontos (x,y)
    % Entrada: p1, p2, p3 = [x, y] ou [lin, col]
    % Fórmula: r = (a*b*c) / (4*area)
    a = norm(p2 - p3);
    b = norm(p1 - p3);
    c = norm(p1 - p2);
    area = abs(det([p2-p1; p3-p1])) / 2;
    if area < 1e-10
        r = inf;  % pontos colineares
    else
        r = (a * b * c) / (4 * area);
    end
end