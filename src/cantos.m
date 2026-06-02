function cantos()
    pastaEntrada = 'output/binarizacao';
    pastaSaida = 'output/cantos';
    pastaSaidaPontos = 'output/cantosPontos';

    if ~exist(pastaSaida, 'dir')
        mkdir(pastaSaida);
    end

    if ~exist(pastaSaidaPontos, 'dir')
        mkdir(pastaSaidaPontos);
    end

    arquivos = dir(fullfile(pastaEntrada, '*.tif'));
    if isempty(arquivos)
        error('Nenhum arquivo .tif encontrado em %s', pastaEntrada);
    end

    for i = 1:length(arquivos)
        nomeArquivo = arquivos(i).name;
        caminhoImagem = fullfile(pastaEntrada, nomeArquivo);
        imgBin = imread(caminhoImagem);
        corners = detectar_cantos(imgBin);
        [~, nomeBase, ~] = fileparts(nomeArquivo);
        salvar_cantos(imgBin, corners, nomeBase, pastaSaida, pastaSaidaPontos);        
        fprintf('Processado: %s -> detectados %d cantos\n', nomeArquivo, size(corners,1));
    end

end


function salvar_cantos(imgBin, corners, nomeBase, pastaSaida, pastaSaidaPontos)
    imgGray = uint8(imgBin) * 255;
    imgRGB = cat(3, imgGray, imgGray, imgGray);

    imgPontos = zeros(size(imgRGB), 'uint8');

    for j = 1:size(corners, 1)
        y = corners(j, 1);
        x = corners(j, 2);

        ymin = max(1, y-2);
        ymax = min(size(imgRGB,1), y+2);
        xmin = max(1, x-2);
        xmax = min(size(imgRGB,2), x+2);

        imgRGB(ymin:ymax, xmin:xmax, 1) = 255;
        imgRGB(ymin:ymax, xmin:xmax, 2) = 0;
        imgRGB(ymin:ymax, xmin:xmax, 3) = 0;

        imgPontos(ymin:ymax, xmin:xmax, :) = 255;
    end

    nomeSaida = [nomeBase '.png'];
    caminhoSaida = fullfile(pastaSaida, nomeSaida);
    imwrite(imgRGB, caminhoSaida);

    nomeSaidaPontos = [nomeBase '.png'];
    caminhoSaidaPontos = fullfile(pastaSaidaPontos, nomeSaidaPontos);
    imwrite(imgPontos, caminhoSaidaPontos);

end