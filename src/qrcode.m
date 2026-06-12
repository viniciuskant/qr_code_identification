function qrcode()
    pastaHierarquia = 'output/hierarquia';
    pastaBinarizada = 'output/binarizacao';
    pastaDebug = 'output/debug';
    pastaQRcode = 'output/qrcode';
    VERBOSE = true;
    
    if ~exist(pastaHierarquia, 'dir'), mkdir(pastaHierarquia); end
    if ~exist(pastaBinarizada, 'dir'), binariza(); end
    if ~exist(pastaDebug, 'dir'), mkdir(pastaDebug); end
    if ~exist(pastaQRcode, 'dir'), mkdir(pastaQRcode); end

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
        [profundidade, img1] = filtro_por_profundidade(hierarquia_img, bordas, 3, img_path, VERBOSE);
        if img1 == -1 continue; end

        % imagem auxiliar para candidatos (amarelo)
        img_path = fullfile(pastaDebug, [nomeBase '_etapa1_candidatos.png']);
        [candidatos, img_candidatos] = filtro_por_formato(arvore, profundidade, bordas, img_path, VERBOSE);
        
        finder_labels = [];
        img_grupos = zeros([size(bordas), 3], 'uint8');
        if length(candidatos) >= 3
        
            % imagem auxiliar de agrupamento por tamanho (varias cores)
            img_path =  fullfile(pastaDebug, [nomeBase '_etapa2_grupos_por_tamanho.png']);
            [img_grupos, grupos] = agrupa_por_tamanho(candidatos, img_grupos, img_path, VERBOSE);

            if ~isempty(grupos)
                %img com a escolha dos melhores 3 pontos em verde
                img_path = fullfile(pastaDebug, [nomeBase '_etapa3_1_filtro_grupo_selecionado.png']);
                altura = size(bordas, 1);
                largura = size(bordas, 2);
                min_area = round((largura * altura ) * 0.05);
                min_ratio = 0.6;
                [img_triangulo, melhor_grupo] = melhor_combinacao_3(bordas, candidatos, grupos, img_path, min_area, min_ratio, VERBOSE);
                % end
                
                finder_labels = [candidatos(melhor_grupo).obj];
                % Atualiza img2 com os finders em verde
                for idxc = melhor_grupo
                    obj_cand = candidatos(idxc);
                    for ii = 1:length(obj_cand.lin)
                        img2(obj_cand.lin(ii), obj_cand.col(ii), 2) = 255;
                        img2(obj_cand.lin(ii), obj_cand.col(ii), 3) = 0;
                    end
                    img2 = desenhar_poligono(img2, obj_cand.corners, [255,255,255]);
                end
            end
        else
            fprintf('Menos de 3 candidatos, impossível formar grupo.\n');
        end
        
        % imagem 3: apenas os finder patterns (verde) sobre fundo preto 
        img3 = zeros([size(bordas), 3], 'uint8');
        for obj = finder_labels
            [lin, col] = find(abs(bordas) == obj);
            for idx = 1:length(lin)
                img3(lin(idx), col(idx), 2) = 255;
            end
            [corners, ~, ~] = obter_retangulo_orientado(lin, col);
            img3 = desenhar_poligono(img3, corners, [0,255,0]);
        end
        imwrite(img3, fullfile(pastaQRcode, [nomeBase '.png']));

        if ~isempty(finder_labels)
            fprintf('Finder patterns encontrados (após relaxamento/filtro): %s\n', mat2str(finder_labels));
        else
            fprintf('Nenhum finder pattern encontrado em %s\n', nomeBase);
        end

        % painel final: binarizada | profundidade | quadrados final | finder final
        painel = [img_bin, img1, img_candidatos, img_grupos, img3];
        imwrite(painel, fullfile(pastaDebug, [nomeBase '_etapa5_painel_final.png']));

        fprintf('Fim do processamento para: %s\n\n\n', nomeArquivo);
    end
end


function [img_triangulo, melhor_grupo] = melhor_combinacao_3(bordas, candidatos, grupos, img_path, min_area, min_ratio, VERBOSE)
    if nargin < 5, min_area = 10; end
    if nargin < 6, min_ratio = 0.7; end
    if nargin < 7, VERBOSE = false; end

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

    fprintf('Total de combinações de 3: %d\n', size(combos, 1));

    melhor_relaxado = []; % razão >= min_ratio & não colinear, desempate menor raio
    melhor_restrito = []; % razão >= min_ratio & área >= min_area & não colinear, desempate maior razao
    melhor_por_ratio = []; % não colinear, maior razao (ignora razão e área mínima)
    melhor_por_ratio_sem_colinear = []; % fallback: maior razao (ignora razão, área mínima e colinearidade)

    melhor_raio_relaxado = inf;
    melhor_area_fallback = -inf;

    melhor_ratio_restrito = -inf;
    melhor_ratio_fallback = -inf;
    melhor_ratio_fallback_sem_colinear = -inf;

    for c = 1:size(combos, 1)
        idxs = combos(c, :); 
        p1 = candidatos(idxs(1)).centro;
        p2 = candidatos(idxs(2)).centro;
        p3 = candidatos(idxs(3)).centro;
        
        % razões de proporção
        d12 = norm(p1-p2);
        d13 = norm(p1-p3);
        d23 = norm(p2-p3);
        ratio1 = min(d12,d13) / max(d12,d13);
        ratio2 = min(d12,d23) / max(d12,d23);
        ratio3 = min(d13,d23) / max(d13,d23);
        min_ratio_combo = min([ratio1, ratio2, ratio3]);
        
        % fallback por maior razao
        if min_ratio_combo > melhor_ratio_fallback_sem_colinear
            melhor_ratio_fallback_sem_colinear = min_ratio_combo;
            melhor_por_ratio_sem_colinear = idxs;
        end

        % fator de colinearidade
        area = abs((p2(1)-p1(1))*(p3(2)-p1(2)) - (p3(1)-p1(1))*(p2(2)-p1(2))) / 2;
        d_max = max([d12, d13, d23]);
        colinearidade = area / (d_max^2);
        if colinearidade < 0.15  
            continue;
        end

        % por maior ratio
        if min_ratio_combo > melhor_ratio_fallback
            melhor_ratio_fallback = min_ratio_combo;
            melhor_por_ratio = idxs;
        end
        
        % razão mínima
        if min_ratio_combo >= min_ratio
            raio = circumradius(p1,p2,p3);
            % relaxado: só razão
            if raio < melhor_raio_relaxado
                melhor_raio_relaxado = raio;
                melhor_relaxado = idxs;
            end
            %restrito: razão E área mínima
            if area >= min_area && melhor_ratio_restrito < min_ratio 
                melhor_ratio_restrito = min_ratio_combo;
                melhor_restrito = idxs;
            end
        end
    end
    
    % a melhor combinação segundo a hierarquia
    if ~isempty(melhor_restrito)
        melhor_combo = melhor_restrito;
        if VERBOSE
            fprintf('Usando critério restrito (razão≥%.2f e área≥%d px2)\n', min_ratio, min_area);
        end
    elseif ~isempty(melhor_relaxado)
        melhor_combo = melhor_relaxado;
        if VERBOSE
            fprintf('Usando critério relaxado (apenas razão≥%.2f)\n', min_ratio);
        end
    else
        if ~isempty(melhor_por_ratio)
            melhor_combo = melhor_por_ratio;
            if VERBOSE
                fprintf('Nenhuma combinação atende à razão mínima. Usando a de maior razão (%.2f)\n', melhor_ratio_fallback);
            end
        elseif ~isempty(melhor_por_ratio_sem_colinear)
            melhor_combo = melhor_por_ratio_sem_colinear;
            if VERBOSE
                fprintf('Nenhuma combinação!. Usando a de maior razão e colinear (%.2f)\n', melhor_ratio_fallback);
            end
        end
    end
    
    melhor_grupo = melhor_combo;
    
    img_triangulo = zeros([size(bordas), 3], 'uint8');
    if isempty(melhor_grupo)
        fprintf('Nenhum candidato\n');
    else 
        for idx = melhor_grupo
            for ii = 1:length(candidatos(idx).lin)
                img_triangulo(candidatos(idx).lin(ii), candidatos(idx).col(ii), 2) = 255;
            end
            img_triangulo = desenhar_poligono(img_triangulo, candidatos(idx).corners, [0,255,0]);
        end
        pts = [candidatos(melhor_grupo(1)).centro;
            candidatos(melhor_grupo(2)).centro;
            candidatos(melhor_grupo(3)).centro];
        for i = 1:3
            p1 = round(pts(i,:));
            p2 = round(pts(mod(i,3)+1,:));
            img_triangulo = desenhar_linha(img_triangulo, p1(2), p1(1), p2(2), p2(1), [255,255,255]);
        end
    end

    if VERBOSE
        imwrite(img_triangulo, img_path);
    end
end

function [img_grupos, grupos] = agrupa_por_tamanho(candidatos, img_grupos, img_path, VERBOSE)
    if nargin < 4; VERBOSE = false; end

    n_cand = length(candidatos);
    similar = false(n_cand);
    for i = 1:n_cand
        for j = i+1:n_cand
            if abs(candidatos(i).tamanho - candidatos(j).tamanho)  / max(candidatos(i).tamanho, candidatos(j).tamanho) <= 0.15
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
            img_grupos = desenhar_poligono(img_grupos, candidatos(idx).corners, cor);
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
                % Pinta de amarelo
                for idx = 1:length(lin)
                    img_candidatos(lin(idx), col(idx), 1) = 255;
                    img_candidatos(lin(idx), col(idx), 2) = 255;
                    img_candidatos(lin(idx), col(idx), 3) = 0;
                end
                img_candidatos = desenhar_poligono(img_candidatos, corners, [255,255,0]);
            end
        end
    end

    if VERBOSE imwrite(img_candidatos, img_path); end
end

function  [profundidade, img1] = filtro_por_profundidade(hierarquia_img, bordas, profundidade_min, img_path, VERBOSE)
    if nargin < 5, VERBOSE = false; end

    profundidade = []; 
    for obj = hierarquia_img.keys()
        if hierarquia_img(obj{1}) >= profundidade_min
            profundidade(end+1) = obj{1};
        end
    end

    if isempty(profundidade)
        fprintf('Nenhuma hierarquia em %s\n', nomeBase);
        img1 = -1;
        return;
    end

    % if VERBOSE fprintf('%d objeto(s): %s\n', length(profundidade), mat2str(profundidade)); end 

    % objetos com mais de x hierarquias em vermelho
    img1 = zeros([size(bordas), 3], 'uint8');
    todos_objetos = unique(abs(bordas(abs(bordas)>0)));
    for obj = todos_objetos'
        [lin, col] = find(abs(bordas) == obj);
        if ismember(obj, profundidade)
            for idx = 1:length(lin)
                img1(lin(idx), col(idx), 1) = 255;
            end
        else
            for idx = 1:length(lin)
                img1(lin(idx), col(idx), 1) = 128;
                img1(lin(idx), col(idx), 2) = 128;
                img1(lin(idx), col(idx), 3) = 128;
            end
        end
    end

    if VERBOSE imwrite(img1, img_path); end
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
    pontos = round(pontos);
    n = size(pontos, 1);
    for i = 1:n
        p1 = pontos(i, :);
        p2 = pontos(mod(i, n) + 1, :);
        img = desenhar_linha(img, p1(1), p1(2), p2(1), p2(2), cor);
    end
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