function binariza()

    fatorReducao = 4;

    pastaEntrada = '../images/reais';

    if ~exist(pastaEntrada, 'dir')
        error('A pasta especificada não existe.');
    end

    pastaBinarizada = 'output/binarizacao';

    if ~exist(pastaBinarizada, 'dir')
        mkdir(pastaBinarizada);
    end

    arquivos = dir(fullfile(pastaEntrada, '*.png'));

    for k = 1:length(arquivos)

        nomeArquivo = arquivos(k).name;
        caminhoImagem = fullfile(pastaEntrada, nomeArquivo);

        img = imread(caminhoImagem);

        if size(img,3) == 3
            img = rgb2gray(img);
        end

        img = im2double(img);

        janela = round(min(size(img))/18);

        if mod(janela,2) == 0
            janela = janela + 1;
        end

        sensibilidade = 0.09;

        imgBin = binarizacaoAdaptativa(img, janela, sensibilidade);

        imgBin = remover_regioes_caoticas(imgBin);
        imgBin = remover_pretos_isolados(imgBin);

        grade = round(min(size(imgBin))/40);

        imgBin = remover_blocos_esparsos(imgBin, grade);
        imgBin = remover_blocos_isolados(imgBin, grade);

        imgBin = remover_blocos_esparsos(imgBin, grade * 5);
        imgBin = remover_blocos_isolados(imgBin, grade * 5);

        imgBin = rot90(imgBin,-1);

        [~, nomeBase, ~] = fileparts(nomeArquivo);

        caminhoBIN = fullfile(pastaBinarizada,[nomeBase '.tif']);

        [h, w] = size(imgBin);
        novaAltura = round(h / fatorReducao);
        novaLargura = round(w / fatorReducao);
        imgBin = imresize(imgBin, [novaAltura, novaLargura]);

        imwrite(uint8(imgBin)*255, caminhoBIN, 'Compression','none');

        fprintf('Processado (resolução reduzida por %dx): %s\n', fatorReducao, nomeArquivo);

    end

    fprintf('Concluído!\n');

end

function imgOut = remover_blocos_esparsos(imgBin, blocoTam)

    [h,w] = size(imgBin);

    nLin = ceil(h/blocoTam);
    nCol = ceil(w/blocoTam);

    porcentagens = zeros(nLin,nCol);

    % Primeira passada: calcular porcentagens
    for i = 1:nLin
        for j = 1:nCol

            y1 = (i-1)*blocoTam + 1;
            y2 = min(i*blocoTam,h);

            x1 = (j-1)*blocoTam + 1;
            x2 = min(j*blocoTam,w);

            bloco = imgBin(y1:y2,x1:x2);

            porcentagens(i,j) = sum(bloco(:)==0) / numel(bloco);

        end
    end

    % Média dos blocos que possuem algum preto
    valores = porcentagens(porcentagens > 0);

    if isempty(valores)
        imgOut = imgBin;
        return;
    end

    limiar = mean(valores);

    % opcional: tornar mais permissivo
    limiar_minimo = 0.25 * limiar;
    limiar_maximo = 85;
    % limiar_maximo = max(3 * limiar, 1);

    imgOut = imgBin;
    % Segunda passada: remover blocos fora da faixa aceitável
    for i = 1:nLin
        for j = 1:nCol

            p = porcentagens(i,j);

            if (p < limiar_minimo) || (p > limiar_maximo)

                y1 = (i-1)*blocoTam + 1;
                y2 = min(i*blocoTam,h);

                x1 = (j-1)*blocoTam + 1;
                x2 = min(j*blocoTam,w);

                imgOut(y1:y2,x1:x2) = 1;

            end

        end
    end

end

function imgBin = remover_regioes_caoticas(imgBin)
    janela = 16;
    [h,w] = size(imgBin);
    for y = 1:janela:h-janela+1
        for x = 1:janela:w-janela+1
            bloco = imgBin(y:y+janela-1, x:x+janela-1);
            tx = sum(sum(abs(diff(bloco,1,2))));
            ty = sum(sum(abs(diff(bloco,1,1))));

            score = tx + ty;
            if score > 50
                imgBin(y:y+janela-1, x:x+janela-1) = 1;
            end
        end
    end
end

function imgOut = remover_blocos_isolados(imgBin, blocoTam)

    imgOut = imgBin;

    mudou = true;

    while mudou

        mudou = false;

        [h,w] = size(imgOut);

        nLin = floor(h/blocoTam);
        nCol = floor(w/blocoTam);

        mapa = false(nLin,nCol);

        % Detecta blocos com preto
        for i = 1:nLin
            for j = 1:nCol

                y1 = (i-1)*blocoTam + 1;
                y2 = i*blocoTam;

                x1 = (j-1)*blocoTam + 1;
                x2 = j*blocoTam;

                bloco = imgOut(y1:y2, x1:x2);

                mapa(i,j) = any(bloco(:) == 0);

            end
        end

        remover = false(nLin,nCol);

        for i = 1:nLin
            for j = 1:nCol

                if ~mapa(i,j)
                    continue;
                end

                % ---- vizinhos por direção ----
                temH = false; % esquerda/direita
                temV = false; % cima/baixo

                % esquerda
                if j > 1 && mapa(i,j-1)
                    temH = true;
                end

                % direita
                if j < nCol && mapa(i,j+1)
                    temH = true;
                end

                % cima
                if i > 1 && mapa(i-1,j)
                    temV = true;
                end

                % baixo
                if i < nLin && mapa(i+1,j)
                    temV = true;
                end

                % regra nova:
                % precisa ter conexão nas DUAS direções
                if ~(temH && temV)
                    remover(i,j) = true;
                end

            end
        end

        % aplica remoção
        for i = 1:nLin
            for j = 1:nCol

                if remover(i,j)

                    y1 = (i-1)*blocoTam + 1;
                    y2 = i*blocoTam;

                    x1 = (j-1)*blocoTam + 1;
                    x2 = j*blocoTam;

                    imgOut(y1:y2, x1:x2) = 1;
                    mudou = true;

                end

            end
        end

    end

end

function imgBin = remover_pretos_isolados(imgBin)
    [h,w] = size(imgBin);

    saida = imgBin;

    for y = 2:h-1
        for x = 2:w-1

            if imgBin(y,x) == 0
                pretos = 0;
                for dy = -1:1
                    for dx = -1:1
                        if dy == 0 && dx == 0
                            continue;
                        end
                        if imgBin(y+dy,x+dx) == 0
                            pretos = pretos + 1;
                        end
                    end
                end
                % menos de 2 vizinhos pretos => ruído
                if pretos < 2
                    saida(y,x) = 1;
                end

            end

        end
    end

    imgBin = saida;

end

function bw = binarizacaoAdaptativa(I, janela, sensibilidade)
    % Binarização adaptativa usando média e desvio padrão (método de Sauvola)
    % I: imagem em double no intervalo [0,1]
    % janela: tamanho da janela local (ímpar)
    % sensibilidade: fator k da fórmula de Sauvola (valores típicos: 0.2 a 0.5)

    % Constante de escala para o desvio padrão (range dinâmico máximo)
    R = 0.5;   % para imagens normalizadas, max std ≈ 0.5

    % Imagens integrais para média e média dos quadrados
    intImg = preCalcArea(I);
    intImg2 = preCalcArea(I.^2);

    half = floor(janela/2);
    bw = zeros(size(I));

    for r = 1:size(I,1)
        for c = 1:size(I,2)
            % Coordenadas da janela
            r1 = max(1, r-half);
            r2 = min(size(I,1), r+half);
            c1 = max(1, c-half);
            c2 = min(size(I,2), c+half);

            % Número de pixels da janela
            area = (r2-r1+1) * (c2-c1+1);

            % Soma dos valores e dos quadrados usando imagens integrais
            soma   = intImg(r2+1,c2+1) - intImg(r1,c2+1) - intImg(r2+1,c1) + intImg(r1,c1);
            soma2  = intImg2(r2+1,c2+1) - intImg2(r1,c2+1) - intImg2(r2+1,c1) + intImg2(r1,c1);

            media   = soma / area;
            variancia = (soma2 / area) - (media^2);
            % Evita valores negativos por erros de precisão
            if variancia < 0
                variancia = 0;
            end
            desvio = sqrt(variancia);

            % Limiar de Sauvola
            limiar = media * (1 + sensibilidade * (desvio / R - 1));

            % Classificação: se o pixel for mais claro que o limiar → branco (1), senão preto (0)
            bw(r,c) = I(r,c) > limiar;
        end
    end
end

function intImg = preCalcArea(I)
    I = double(I);
    [M, N] = size(I);

    % matriz de zeros com uma linha e coluna extras
    intImg = zeros(M+1, N+1);

    % preenche a imagem integral incrementalmente
    for y = 1:M
        linha_soma = 0; % soma acumulada na linha atual
        for x = 1:N
            linha_soma = linha_soma + I(y, x);
            intImg(y+1, x+1) = intImg(y, x+1) + linha_soma;
        end
    end
end
