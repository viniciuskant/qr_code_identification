function corners = detectar_cantos(imgBin)
    I = double(imgBin);

    k = 0.1;
    limiarRel = 0.1;

    dimMenor = min(size(I));
    janela = max(3, min(31, round(dimMenor / 50))); 
    sigma = max(1, min(9, round(dimMenor / 60))); %valor de teste

    fprintf('uso janela = %d, sigma = %.1f\n', janela, sigma);
    
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
    
    janela = floor(janela/2);
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
