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
                % imagem do grupo selecionado (ciano)
                img_path = fullfile(pastaDebug, [nomeBase '_etapa3_0_grupo_selecionado.png']);
                [img_melhor_grupo, melhor_grupo] = escolhe_melhor_grupo (bordas, candidatos, grupos, img_path, VERBOSE);
                
                % Sub‑seleção por triângulo se houver mais de 3
                if length(melhor_grupo) > 3
                    %img com a escolha dos melhores 3 pontos em verde
                    img_path = fullfile(pastaDebug, [nomeBase '_etapa3_1_filtro_grupo_selecionado.png']);
                    [img_triangulo, melhor_grupo] = melhor_combinacao_maior_3(bordas, candidatos, melhor_grupo, img_path, VERBOSE);
                end
                
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
        if ~isempty(finder_labels)
            imwrite(img3, fullfile(pastaQRcode, [nomeBase '.png']));
            fprintf('Finder patterns encontrados (após relaxamento/filtro): %s\n', mat2str(finder_labels));
        else
            fprintf('Nenhum finder pattern encontrado em %s (mesmo com relaxamento)\n', nomeBase);
        end

        % painel final: binarizada | profundidade | quadrados final | finder final
        painel = [img_bin, img1, img_candidatos, img_grupos, img3];
        imwrite(painel, fullfile(pastaDebug, [nomeBase '_etapa5_painel_final.png']));

        fprintf('Fim do processamento para: %s\n', nomeArquivo);
    end
end


function [img_triangulo, melhor_grupo] = melhor_combinacao_maior_3(bordas, candidatos, melhor_grupo, img_path, VERBOSE)
    if nargin < 5 VERBOSE = false; end

    combos = nchoosek(melhor_grupo, 3);
    melhor_raio = inf;
    melhor_combo = [];
    for c = 1:size(combos,1)
        idxs = combos(c,:);
        p1 = candidatos(idxs(1)).centro;
        p2 = candidatos(idxs(2)).centro;
        p3 = candidatos(idxs(3)).centro;
        raio = circumradius(p1, p2, p3);
        if raio < melhor_raio
            melhor_raio = raio;
            melhor_combo = idxs;
        end
    end
    melhor_grupo = melhor_combo;
    
    % Imagem do triângulo escolhido
    img_triangulo = zeros([size(bordas), 3], 'uint8');
    for idx = melhor_grupo
        for ii = 1:length(candidatos(idx).lin)
            img_triangulo(candidatos(idx).lin(ii), candidatos(idx).col(ii), 2) = 255;
        end
        img_triangulo = desenhar_poligono(img_triangulo, candidatos(idx).corners, [0,255,0]);
    end
    % Desenhar linhas do triângulo
    pts = [candidatos(melhor_grupo(1)).centro;
            candidatos(melhor_grupo(2)).centro;
            candidatos(melhor_grupo(3)).centro];
    for i = 1:3
        p1 = round(pts(i,:));
        p2 = round(pts(mod(i,3)+1,:));
        img_triangulo = desenhar_linha(img_triangulo, p1(2), p1(1), p2(2), p2(1), [255,255,255]);
    end

    if VERBOSE imwrite(img_triangulo, img_path); end
end

function [img_melhor_grupo, melhor_grupo] = escolhe_melhor_grupo(bordas, candidatos, grupos, img_path, VERBOSE)
    if nargin < 5 VERBOSE = false; end

    grupos_tres = {};
    grupos_outros = {};
    for g = 1:length(grupos)
        if length(grupos{g}) == 3
            grupos_tres{end+1} = grupos{g};
        else
            grupos_outros{end+1} = grupos{g};
        end
    end

    if ~isempty(grupos_tres)
        % entre os grupos de tamanho 3, escolhe o de menor raio circunscrito
        melhor_raio = inf;
        melhor_grupo = [];
        for g = 1:length(grupos_tres)
            idxs = grupos_tres{g};
            p1 = candidatos(idxs(1)).centro;
            p2 = candidatos(idxs(2)).centro;
            p3 = candidatos(idxs(3)).centro;
            raio = circumradius(p1, p2, p3);
            if raio < melhor_raio
                melhor_raio = raio;
                melhor_grupo = idxs;
            end
        end
    else
        % TODO: aqui há um problema se houver um ruído que foi considerado quadrado pela hierarquia, ver como reslver esse probelma
        % para grupos com tamanho diferente de 3: tamanho
        melhor_idx = 1;
        melhor_dist = abs(length(grupos{1}) - 3);
        tamanhos_primeiro = [candidatos(grupos{1}).tamanho];
        melhor_tamanho = mean(tamanhos_primeiro);
        for g = 2:length(grupos)
            dist_atual = abs(length(grupos{g}) - 3);
            tamanhos_atual = [candidatos(grupos{g}).tamanho];
            tam_atual = mean(tamanhos_atual);
            if (dist_atual < melhor_dist) || (dist_atual == melhor_dist && tam_atual > melhor_tamanho)
                melhor_dist = dist_atual;
                melhor_tamanho = tam_atual;
                melhor_idx = g;
            end
        end
        melhor_grupo = grupos{melhor_idx};
    end

    img_melhor_grupo = zeros([size(bordas), 3], 'uint8');
    for idx = melhor_grupo
        for ii = 1:length(candidatos(idx).lin)
            img_melhor_grupo(candidatos(idx).lin(ii), candidatos(idx).col(ii), 1) = 0;
            img_melhor_grupo(candidatos(idx).lin(ii), candidatos(idx).col(ii), 2) = 255;
            img_melhor_grupo(candidatos(idx).lin(ii), candidatos(idx).col(ii), 3) = 255;
        end
        img_melhor_grupo = desenhar_poligono(img_melhor_grupo, candidatos(idx).corners, [0,255,255]);
    end
    if VERBOSE imwrite(img_melhor_grupo, img_path); end

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

    if VERBOSE fprintf('%d objeto(s): %s\n', length(profundidade), mat2str(profundidade)); end 

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