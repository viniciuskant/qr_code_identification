function bordas()
    pastaBinarizada = 'output/binarizacao';
    pastaDebug = 'output/debug';
    pastaRetas = 'output/retas';       % nova pasta para imagens com retas

    % Criar pastas se não existirem
    if ~exist(pastaDebug, 'dir')
        mkdir(pastaDebug);
    end
    if ~exist(pastaRetas, 'dir')
        mkdir(pastaRetas);
    end

    arquivos = dir(fullfile(pastaBinarizada, '*.tif'));

    for k = 1:length(arquivos)
        nomeArquivo = arquivos(k).name;
        imgBin = imread(fullfile(pastaBinarizada, nomeArquivo));
        imgBin = imgBin > 128;

        % ========== PRÉ-PROCESSAMENTO: REMOVER 10% DAS BORDAS ==========
        [h, w] = size(imgBin);
        corteTopo = round(0.05 * h);
        corteBase = round(0.05 * h);
        corteEsq = round(0.05 * w);
        corteDir = round(0.05 * w);

        % Aplicar o corte (5% em cada borda)
        imgBin = imgBin(corteTopo+1 : h-corteBase, corteEsq+1 : w-corteDir);
        % ================================================================

        [~, nomeBase, ~] = fileparts(nomeArquivo);

        larguraBorda = 2;
        [imgCandidatas, listaPixels] = pintarBordas(imgBin, larguraBorda);
        imwrite(imgCandidatas, fullfile(pastaDebug, [nomeBase '_candidatas_janelas.png']));

        % Detectar linhas
        arquivoHough = fullfile(pastaDebug, [nomeBase '_espaco_hough.png']);
        [linhasDetectadas, acum] = detectarLinhasPorHough(listaPixels, 1800, 50, arquivoHough, 5, 15, 0.05);

        fprintf('%s: %d linhas detectadas\n', nomeBase, size(linhasDetectadas,1));

        % ========== DESENHAR E SALVAR IMAGEM COM RETAS ==========
        % Usar a imagem binarizada (já cortada) para gerar a imagem RGB
        imgRetas = repmat(uint8(imgBin)*255, [1 1 3]); % converte para RGB (branco e preto)
        imgRetas = desenharRetas(imgRetas, linhasDetectadas, size(imgBin));
        imwrite(imgRetas, fullfile(pastaRetas, [nomeBase '_retas.png']));
    end

    fprintf('Concluído!\n');
end

function imgOut = desenharRetas(imgRGB, rhoTheta, tamanhoImagem)
    % Desenha retas na imagem RGB
    % rhoTheta: matriz Nx2 onde cada linha é [rho, theta]
    % tamanhoImagem: [altura, largura] da imagem original

    imgOut = imgRGB;
    [h, w, ~] = size(imgOut);
    cor = [255, 0, 0]; % vermelho (R,G,B)

    for i = 1:size(rhoTheta,1)
        rho = rhoTheta(i,1);
        theta = rhoTheta(i,2);

        % Se o cosseno for próximo de zero, reta vertical (theta ~ pi/2)
        if abs(cos(theta)) < 1e-6
            % x constante
            x = rho / sin(theta);   % pois rho = x*cos(theta)+y*sin(theta) => x*0 + y*1 = rho
            if x >= 1 && x <= w
                % Desenha linha vertical em x
                for y = 1:h
                    imgOut(y, round(x), :) = cor;
                end
            end
        else
            % Calcular dois pontos: y=0 e y=h
            x1 = (rho - 0*sin(theta)) / cos(theta);
            y1 = 0;
            x2 = (rho - h*sin(theta)) / cos(theta);
            y2 = h;

            % Clipar para dentro da imagem
            pontos = cliparReta(x1, y1, x2, y2, w, h);
            if ~isempty(pontos)
                % Desenhar linha usando algoritmo de Bresenham
                imgOut = desenharLinha(imgOut, pontos(1,1), pontos(1,2), pontos(2,1), pontos(2,2), cor);
            end
        end
    end
end

function pts = cliparReta(x1, y1, x2, y2, w, h)
    % Recorta a reta para dentro da caixa [0,w]x[0,h] (coordenadas de pixels)
    % Retorna dois pontos [x1,y1; x2,y2] após clipping, ou vazio se fora.
    % Implementação simples de clipping de linha (Cohen-Sutherland)
    INSIDE = 0; LEFT = 1; RIGHT = 2; BOTTOM = 4; TOP = 8;
    xmin = 1; xmax = w; ymin = 1; ymax = h;

    function code = compCode(x,y)
        code = INSIDE;
        if x < xmin, code = code + LEFT; end
        if x > xmax, code = code + RIGHT; end
        if y < ymin, code = code + BOTTOM; end
        if y > ymax, code = code + TOP; end
    end

    x = [x1, x2];
    y = [y1, y2];
    code1 = compCode(x1,y1);
    code2 = compCode(x2,y2);
    accept = false;
    while true
        if (code1 == INSIDE && code2 == INSIDE)
            accept = true;
            break;
        elseif (bitand(code1, code2) ~= 0)
            break;
        else
            codeOut = code1;
            if code1 == INSIDE, codeOut = code2; end
            if bitand(codeOut, LEFT)   % intersect with left edge x = xmin
                y = y1 + (y2 - y1) * (xmin - x1) / (x2 - x1);
                x = xmin;
            elseif bitand(codeOut, RIGHT)
                y = y1 + (y2 - y1) * (xmax - x1) / (x2 - x1);
                x = xmax;
            elseif bitand(codeOut, BOTTOM)
                x = x1 + (x2 - x1) * (ymin - y1) / (y2 - y1);
                y = ymin;
            elseif bitand(codeOut, TOP)
                x = x1 + (x2 - x1) * (ymax - y1) / (y2 - y1);
                y = ymax;
            end
            if codeOut == code1
                x1 = x; y1 = y;
                code1 = compCode(x1,y1);
            else
                x2 = x; y2 = y;
                code2 = compCode(x2,y2);
            end
        end
    end
    if accept
        pts = [round(x1), round(y1); round(x2), round(y2)];
    else
        pts = [];
    end
end

function img = desenharLinha(img, x0, y0, x1, y1, cor)
    % Algoritmo de Bresenham para linha em imagem RGB
    dx = abs(x1 - x0);
    dy = -abs(y1 - y0);
    sx = sign(x1 - x0);
    sy = sign(y1 - y0);
    err = dx + dy;
    while true
        if x0>=1 && x0<=size(img,2) && y0>=1 && y0<=size(img,1)
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

function [rhoTheta, acumulador] = detectarLinhasPorHough(pontos, resolucaoTheta, numLinhas, arquivoSaida, tamanhoQuad, minDistLinhas, toleranciaAngular)
    % Detecta linhas pela transformada de Hough com supressão de retas próximas.
    % Parâmetros:
    %   pontos: [y x] coordenadas dos pixels de borda
    %   resolucaoTheta: número de bins para theta (0 a pi)
    %   numLinhas: número máximo de linhas a retornar (antes da supressão)
    %   arquivoSaida: caminho para salvar imagem do espaço de Hough
    %   tamanhoQuad: tamanho do quadrado de votação (ímpar)
    %   minDistLinhas: distância mínima (em pixels) entre retas quase paralelas (default = 10)
    %   toleranciaAngular: tolerância em radianos para considerar ângulos semelhantes (default = 0.05 rad ~ 3 graus)

    if nargin < 5
        tamanhoQuad = 5;
    end
    if nargin < 6
        minDistLinhas = 10;   % distância mínima de 10 pixels
    end
    if nargin < 7
        toleranciaAngular = 0.05; % cerca de 2.86 graus
    end

    x = pontos(:,2);
    y = pontos(:,1);

    theta = linspace(0, pi, resolucaoTheta);
    cosTheta = cos(theta);
    sinTheta = sin(theta);

    rhoMax = ceil(sqrt(max(x)^2 + max(y)^2));
    rhoMin = -rhoMax;
    rhoStep = 10;          % passo de rho (ajustável)
    rhoVals = rhoMin:rhoStep:rhoMax;

    % Inicializa acumulador
    acumulador = zeros(length(rhoVals), resolucaoTheta);

    % Votação vetorizada
    for i = 1:length(x)
        rhos = x(i) * cosTheta + y(i) * sinTheta;
        idxRho = round((rhos - rhoMin) / rhoStep) + 1;
        validos = idxRho >= 1 & idxRho <= size(acumulador,1);
        idxRho = idxRho(validos);
        idxTheta = find(validos);
        ind = sub2ind(size(acumulador), idxRho, idxTheta);
        acumulador(ind) = acumulador(ind) + 1;
    end

    % Convolução para suavização (votação regional)
    kernel = ones(tamanhoQuad) / (tamanhoQuad^2);
    acumuladorSuave = conv2(acumulador, kernel, 'same');

    % Pega todos os picos ordenados (mais do que numLinhas para depois filtrar)
    [valores, idx] = sort(acumuladorSuave(:), 'descend');
    numPicos = min(length(idx), numLinhas * 3); % pega mais picos para garantir após supressão
    picos = [];
    for k = 1:numPicos
        [idxRho, idxTheta] = ind2sub(size(acumulador), idx(k));
        rho = rhoVals(idxRho);
        thetaLinha = theta(idxTheta);
        picos = [picos; rho, thetaLinha, valores(k), idxRho, idxTheta];
    end

    % ================================================
    % Supressão de picos com base na distância entre retas
    % ================================================
    selecionados = [];
    for i = 1:size(picos,1)
        rho_i = picos(i,1);
        theta_i = picos(i,2);
        % Verifica se este pico está muito próximo de algum já selecionado
        redundante = false;
        for j = 1:size(selecionados,1)
            rho_j = selecionados(j,1);
            theta_j = selecionados(j,2);
            % Se os ângulos são próximos (quase paralelos)
            if abs(theta_i - theta_j) < toleranciaAngular
                % Distância entre as retas no espaço imagem = |rho_i - rho_j|
                if abs(rho_i - rho_j) < minDistLinhas
                    redundante = true;
                    break;
                end
            end
        end
        if ~redundante
            selecionados = [selecionados; picos(i,:)];
            if size(selecionados,1) >= numLinhas
                break;
            end
        end
    end

    % Prepara saída
    numEncontradas = size(selecionados,1);
    rhoTheta = zeros(numEncontradas, 2);
    for k = 1:numEncontradas
        rhoTheta(k,1) = selecionados(k,1);
        rhoTheta(k,2) = selecionados(k,2);
    end

    % Atualiza os índices dos picos para o plot (apenas os selecionados)
    idxRhoPeak = selecionados(:,4);
    idxThetaPeak = selecionados(:,5);

    % Gerar figura do espaço de Hough
    fig = figure('Visible','off','Color','white');
    imagesc(theta, rhoVals, acumuladorSuave);
    axis xy;
    colormap(jet);
    colorbar;
    xlabel('\theta (rad)');
    ylabel('\rho');
    title(['Espaço de Hough (quadrado = ', num2str(tamanhoQuad), 'x', num2str(tamanhoQuad), ...
           ', minDist = ', num2str(minDistLinhas), 'px, tolAng = ', num2str(toleranciaAngular), ' rad)']);
    hold on;
    if ~isempty(selecionados)
        plot(theta(idxThetaPeak), rhoVals(idxRhoPeak), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    end
    hold off;
    saveas(fig, arquivoSaida);
    close(fig);
end

function [imgRGB, listaPixels] = pintarBordas(imgBin, largura)
    % Garantir que seja lógica
    if ~islogical(imgBin)
        imgBin = imgBin > 0;
    end

    % 1. Borda fina (perímetro)
    bordaFina = bwperim(imgBin);

    % 2. Espessar a borda
    if largura <= 1
        bordaGrossa = bordaFina;
    else
        raio = ceil(largura / 2);
        se = strel('disk', raio);
        bordaGrossa = imdilate(bordaFina, se);
    end
    % bordaGrossa é do tipo logical

    % 3. Criar imagem RGB (fundo preto)
    imgRGB = zeros([size(imgBin), 3], 'uint8');
    imgRGB(:,:,1) = uint8(imgBin) * 255;
    imgRGB(:,:,2) = uint8(imgBin) * 255;
    imgRGB(:,:,3) = uint8(imgBin) * 255;

    % 4. Pintar as bordas de vermelho usando índices lineares (eficiente)
    %    Encontra os índices lineares dos pixels de borda na imagem 2D
    indBorda = find(bordaGrossa);   % vetor coluna com índices lineares
    nPixels = numel(bordaGrossa);   % total de pixels da imagem (linhas * colunas)
    
    % Canal vermelho (R): índice original
    imgRGB(indBorda) = 255;
    % Canal verde (G): índice deslocado por nPixels
    imgRGB(indBorda + nPixels) = 0;
    % Canal azul (B): índice deslocado por 2*nPixels
    imgRGB(indBorda + 2*nPixels) = 0;

    % 5. Listar coordenadas dos pixels de borda (opcional)
    [rows, cols] = find(bordaGrossa);
    listaPixels = [rows, cols];
end