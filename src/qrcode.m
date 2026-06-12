function qrcode()
    pastaBinarizada = 'output/binarizacao';
    pastaDebug = 'output/debug';
    pastaHierarquia = 'output/hierarquia';
    pastaQRcode = 'output/qrcode';

    if ~exist(pastaDebug, 'dir'), mkdir(pastaDebug); end
    if ~exist(pastaHierarquia, 'dir'), mkdir(pastaHierarquia); end
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

        hierarquia = obter_hierarquia(arvore);
        obj_profundos = []; 
        for obj = hierarquia.keys()
            if hierarquia(obj{1}) >= 3
                obj_profundos(end+1) = obj{1};
            end
        end

        if isempty(obj_profundos)
            fprintf('Nenhum objeto profundo em %s\n', nomeBase);
            continue;
        end
        fprintf('%d objeto(s) profundo(s) em %s: %s\n', ...
            length(obj_profundos), nomeBase, mat2str(obj_profundos));

        % --- Imagem 1: objetos profundos em vermelho ---
        img1 = zeros([size(bordas), 3], 'uint8');
        todos_objetos = unique(abs(bordas(abs(bordas)>0)));
        for obj = todos_objetos'
            [lin, col] = find(abs(bordas) == obj);
            if ismember(obj, obj_profundos)
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
        imwrite(img1, fullfile(pastaHierarquia, [nomeBase '.png']));

        % --- Imagem 2: objetos profundos com aspecto próximo de 1 (azul) ---
        img2 = zeros([size(bordas), 3], 'uint8');
        finder_labels = [];
        for obj = obj_profundos
            [lin, col] = find(abs(bordas) == obj);
            [corners, largura, altura] = obter_retangulo_orientado(lin, col);
            razao = largura / altura;
            if (razao >= 0.7 && razao <= 1.3) || (1/razao >= 0.7 && 1/razao <= 1.3)
                if verificar_finder_pattern(arvore, bordas, obj)
                    finder_labels(end+1) = obj;
                    for idx = 1:length(lin)
                        img2(lin(idx), col(idx), 2) = 255;
                    end
                else
                    for idx = 1:length(lin)
                        img2(lin(idx), col(idx), 3) = 255;
                    end
                end
                img2 = desenhar_poligono(img2, corners, [255,255,255]);
            else
                for idx = 1:length(lin)
                    img2(lin(idx), col(idx), 1) = 80;
                    img2(lin(idx), col(idx), 2) = 80;
                    img2(lin(idx), col(idx), 3) = 80;
                end
            end
        end
        imwrite(img2, fullfile(pastaQRcode, [nomeBase '.png']));

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
            fprintf('Finder patterns encontrados: %s\n', mat2str(finder_labels));
        else
            fprintf('Nenhum finder pattern encontrado em %s\n', nomeBase);
        end

        painel = [img_bin, img1, img2, img3];
        imwrite(painel, fullfile(pastaDebug, [nomeBase '.png']));

        fprintf('Fim do processamento para: %s\n', nomeArquivo);
    end
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


function is_finder = verificar_finder_pattern(arvore, saida, obj)
    % Verifica se o objeto 'obj' (número ímpar) é um finder pattern
    is_finder = false;
    % 1) Objeto deve ter exatamente 1 fundo filho
    if ~isKey(arvore.obj_children, obj)
        return;
    end
    filhos_fundo = arvore.obj_children(obj);
    if length(filhos_fundo) ~= 1
        return;
    end
    fundo_interno = filhos_fundo(1);
    
    % 2) Esse fundo deve ter exatamente 1 objeto filho
    if ~isKey(arvore.fundo_children, fundo_interno)
        return;
    end
    filhos_obj = arvore.fundo_children(fundo_interno);
    if length(filhos_obj) ~= 1
        return;
    end
    obj_interno = filhos_obj(1);
    
    % 3) Calcular centros (média das coordenadas) de cada componente
    [lin_ext, col_ext] = find(abs(saida) == obj);
    [lin_int, col_int] = find(abs(saida) == obj_interno);
    [lin_fundo, col_fundo] = find(saida == fundo_interno); % fundo positivo
    
    if isempty(lin_ext) || isempty(lin_int) || isempty(lin_fundo)
        return;
    end
    
    centro_ext = [mean(col_ext), mean(lin_ext)];
    centro_int = [mean(col_int), mean(lin_int)];
    centro_fundo = [mean(col_fundo), mean(lin_fundo)];
    
    % Distância entre centros (em pixels)
    dist_ext_int = norm(centro_ext - centro_int);
    dist_ext_fundo = norm(centro_ext - centro_fundo);
    if dist_ext_int > 5 || dist_ext_fundo > 5   % tolerância
        return;
    end
    
    % 4) Razão de tamanhos: bounding boxes orientados
    [~, larg_ext, alt_ext] = obter_retangulo_orientado(lin_ext, col_ext);
    [~, larg_int, alt_int] = obter_retangulo_orientado(lin_int, col_int);
    tamanho_ext = mean([larg_ext, alt_ext]);
    tamanho_int = mean([larg_int, alt_int]);
    razao = tamanho_ext / tamanho_int;
    % Razão esperada ~ 7/3 ≈ 2.33 (com margem)
    if razao >= 1.8 && razao <= 3.0
        is_finder = true;
    end
end

% =========================================================================
% Desenha um polígono fechado (conectando os pontos) numa imagem RGB
% =========================================================================
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