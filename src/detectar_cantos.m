function corners = detectar_cantos(imgBin)
    I = double(imgBin);

    k = 0.08;
    limiarRel = 0.05;

    dimMenor = min(size(I));
    janela = max(3, min(31, round(dimMenor / 50))); 
    sigma = max(1, min(9, round(dimMenor / 60))); %valor de teste

    fprintf('Parâmetros adaptativos: janela = %d, sigma = %.1f\n', janela, sigma);
    
    hx = [-1 0 1; -2 0 2; -1 0 1];
    hy = hx';
    Ix = imfilter(I, hx, 'replicate');
    Iy = imfilter(I, hy, 'replicate');
    
    Ix2 = Ix.^2;
    Iy2 = Iy.^2;
    Ixy = Ix .* Iy;

    sigma = 9; 
    G = fspecial('gaussian', max(3, round(3*sigma)), sigma);

    Ix2 = imfilter(Ix2, G, 'replicate');
    Iy2 = imfilter(Iy2, G, 'replicate');
    Ixy = imfilter(Ixy, G, 'replicate');
    
    detM = Ix2 .* Iy2 - Ixy.^2;
    traceM = Ix2 + Iy2;
    R = detM - k * (traceM.^2);
    
    Rmax = max(R(:));
    threshold = limiarRel * Rmax;
    R(R < threshold) = 0;
    
    janela = floor(vizinhjanelaanca/2);
    corners = [];
    for y = 1+janela : size(R,1)-janela
        for x = 1+janela : size(R,2)-janela
            if R(y, x) > 0
                viz = R(y-janela:y+janela, x-janela:x+janela);
                if R(y,x) == max(viz(:))
                    corners = [corners; y x];
                end
            end
        end
    end
end


% funções criadas para tentar remover pontos, não funcionaram
function [dmin, idx1, idx2] = menor_distancia_cantos(corners)
    N = size(corners, 1);
    if N < 2
        dmin = Inf;
        idx1 = [];
        idx2 = [];
        return;
    end
    
    dmin = Inf;
    idx1 = 0;
    idx2 = 0;
    
    for i = 1:N-1
        for j = i+1:N
            dy = corners(i,1) - corners(j,1);
            dx = corners(i,2) - corners(j,2);
            d = sqrt(dy*dy + dx*dx);
            if d < dmin
                dmin = d;
                idx1 = i;
                idx2 = j;
            end
        end
    end
end

function corners_filtrados = remover_cantos_proximos(corners, dist_min)
    if isempty(corners)
        corners_filtrados = corners;
        fprintf('Nenhum canto para filtrar.\n');
        return;
    end
    
    N = size(corners, 1);
    manter = true(N, 1); 
    
    for i = 1:N
        if ~manter(i)
            continue;
        end
        for j = i+1:N
            if manter(j)
                d = sqrt((corners(i,1)-corners(j,1))^2 + (corners(i,2)-corners(j,2))^2);
                if d <= dist_min
                    manter(j) = false;
                end
            end
        end
    end
    
    removidos = sum(~manter);
    corners_filtrados = corners(manter, :);
    fprintf('Removidos %d cantos por proximidade (distância <= %d pixels)\n', removidos, dist_min);
end

function mask = filtro_densidade(corners, raio, min_vizinhos, max_vizinhos)
    N = size(corners,1);
    mask = false(N,1);
    for i = 1:N
        dist2 = (corners(:,1)-corners(i,1)).^2 + (corners(:,2)-corners(i,2)).^2;
        n_viz = sum(dist2 <= raio^2) - 1;
        mask(i) = (n_viz >= min_vizinhos) && (n_viz <= max_vizinhos);
    end
end

function corners_filtrados = filtrar_por_blocos(corners, imgSize, bloco, min_cantos, max_cantos)

    H = imgSize(1);
    W = imgSize(2);

    manter = false(size(corners,1),1);

    for y0 = 1:bloco:H
        for x0 = 1:bloco:W

            y1 = min(y0 + bloco - 1, H);
            x1 = min(x0 + bloco - 1, W);

            dentro = ...
                corners(:,1) >= y0 & corners(:,1) <= y1 & ...
                corners(:,2) >= x0 & corners(:,2) <= x1;

            idx = find(dentro);

            if length(idx) >= min_cantos & length(idx) <= max_cantos
                manter(idx) = true;
            end

        end
    end

    corners_filtrados = corners(manter,:);

    fprintf('Removidos %d cantos por blocos.\n', ...
        size(corners,1)-size(corners_filtrados,1));

end