
function binarizar_png(pastaEntrada)
    if ~exist(pastaEntrada, 'dir')
        error('A pasta especificada não existe.');
    end

    pastaBinarizada = 'output/binarizacao';

    if ~exist(pastaBinarizada, 'dir'), mkdir(pastaBinarizada); end

    arquivos = dir(fullfile(pastaEntrada, '*.png'));

    for k = 1:length(arquivos)
        nomeArquivo = arquivos(k).name;
        caminhoImagem = fullfile(pastaEntrada, nomeArquivo);

        img = imread(caminhoImagem);
        img = rgb2gray(img);
        img = im2double(img);

        % binarizacao adaptativa
        janela = round(min(size(img)) / 8); %janela usando 1/8 da mernor dimensão
        if mod(janela,2)==0, janela = janela+1; end  % ímpar
        sensibilidade = 0.15;  % entre 0 e 1; quanto menor, mais escuro

        imgBin = adaptivethresh(img, janela, sensibilidade);

        % remove pequenos ruídos isolados
        % imgBin = mediana(imgBin, 3); funcionou, mas muito lento
        imgBin = medfilt2(imgBin, [3 3]); 

        % salva
        [~, nomeBase, ~] = fileparts(nomeArquivo);
        caminhoBIN = fullfile(pastaBinarizada, [nomeBase '.tif']);
        imwrite(imgBin, caminhoBIN);

        fprintf('Processado: %s (binarização adaptativa)\n', nomeArquivo);
    end

    fprintf('Concluído! Imagens adaptativas salvas em: %s\n', pastaBinarizada);
end

function bw = adaptivethresh(I, janela, sensibilidade)
    % calcula imagem integral
    intImg = preCalcArea(I);

    % metade do tamanho da janela
    half = floor(janela/2);
    bw = zeros(size(I));

    % para cada pixel, calcula a média na janela centrada
    for r = 1:size(I,1)
        for c = 1:size(I,2)
            r1 = max(1, r-half);
            r2 = min(size(I,1), r+half);
            c1 = max(1, c-half);
            c2 = min(size(I,2), c+half);
            area = (r2-r1+1)*(c2-c1+1);
            % fazendo os caculos de maneira rápida, apenas subtraindo as áreas, diagrama de venn
            soma = intImg(r2+1,c2+1) - intImg(r1,c2+1) - intImg(r2+1,c1) + intImg(r1,c1);
            media = soma / area;

            %para cada janela tem um limiar diferente
            bw(r,c) = I(r,c) > (media * (1 - sensibilidade));
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

function imgFiltrada = mediana(img, tamanhoJanela)
    if mod(tamanhoJanela, 2) == 0
        error('O tamanho da janela deve ser ímpar.');
    end

    [M, N] = size(img);
    raio = floor(tamanhoJanela / 2);
    imgFiltrada = zeros(M, N);

    for i = 1:M
        for j = 1:N
            % limites da janela (com espelhamento nas bordas)
            i1 = max(1, i - raio);
            i2 = min(M, i + raio);
            j1 = max(1, j - raio);
            j2 = min(N, j + raio);

            % Extrai a janela e a transforma em vetor
            janela = img(i1:i2, j1:j2);
            vetor = janela(:);

            % Calcula a mediana (para imagens binárias é o valor que aparece mais vezes)
            mediana = median(vetor);

            imgFiltrada(i, j) = mediana;
        end
    end

end


% mative para colocar no relatório que esse método não funciona
function binarizar_png_original(pastaEntrada)
    if ~exist(pastaEntrada, 'dir')
        error('A pasta especificada não existe.');
    end

    % Pastas de saída
    pastaBinarizada = 'output/binarizacao';

    if ~exist(pastaBinarizada, 'dir')
        mkdir(pastaBinarizada);
    end

    arquivos = dir(fullfile(pastaEntrada, '*.png'));

    for k = 1:length(arquivos)
        nomeArquivo = arquivos(k).name;
        caminhoImagem = fullfile(pastaEntrada, nomeArquivo);

        img = imread(caminhoImagem);
        img = rgb2gray(img);
        img = im2double(img);  % intensidade em [0,1]

        dados = img(:);
        gm = fitgmdist(dados, 2);
        medias = sort(gm.mu);
        limiar = mean(medias);   % ponto médio entre as duas médias

        imgBin = img >= limiar;

        [~, nomeBase, ~] = fileparts(nomeArquivo);
        caminhoBIN = fullfile(pastaBinarizada, [nomeBase '.tif']);
        imwrite(imgBin, caminhoBIN);

        fprintf('Processado: %s (limiar = %.4f)\n', nomeArquivo, limiar);
    end

    fprintf('Concluído!\n');
    fprintf('Imagens binarizadas em: %s\n', pastaBinarizada);
    fprintf('Histogramas salvos em:   %s\n', pastaHistogramas);
end