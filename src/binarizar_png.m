function binarizar_png()

    pastaEntrada = '../images/frontais';

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

        sensibilidade = 0.1; % preferi tratar rúido de pixels pretos do que o qrcode ficar falhado
        imgBin = adaptivethresh(img, janela, sensibilidade);

        % usei mediana para a remoção de ruído, mas isso acabava suavisando as bordas e me dificultou depois
        imgBin = remover_regioes_caoticas(imgBin);
        imgBin = remover_pretos_isolados(imgBin);

        grade = round(min(size(imgBin))/20);

        imgBin = remover_blocos_esparsos(imgBin, grade);
        imgBin = filtrar_regioes_grade(imgBin, grade);

        % isso melhora e remove regições que foram consideradas quadradas, mas não são (como uma reta diagonal), mas é um custo que talvez não seja necessário ter
        % grade = round(min(size(imgBin))/10);
        % imgBin = remover_blocos_esparsos(imgBin, grade);

        % Adiciona grade apenas para visualização
        % imgBin = adicionar_grade(imgBin, grade);

        [~, nomeBase, ~] = fileparts(nomeArquivo);
        caminhoBIN = fullfile(pastaBinarizada, [nomeBase '.tif']);

        imgBin = rot90(imgBin, -1);
        imwrite(uint8(imgBin)*255, caminhoBIN, 'Compression', 'none');
        fprintf('Processado: %s\n', nomeArquivo);

    end

    fprintf('Concluído! Imagens salvas em: %s\n', pastaBinarizada);

end

function imgOut = filtrar_regioes_grade(imgBin, grade)
    gradeBin = construir_grade_binaria(imgBin, grade);
    regioes = encontrar_regioes_grade(gradeBin);
    imgOut = imgBin;

    for i = 1:length(regioes)
        reg = regioes{i};

        ys = reg(:,1);
        xs = reg(:,2);

        xmin = min(xs);
        xmax = max(xs);

        ymin = min(ys);
        ymax = max(ys);

        largura = (xmax - xmin + 1) * grade;
        altura  = (ymax - ymin + 1) * grade;
        aspecto = largura / altura;

        if aspecto < 0.71 || aspecto > 1.40
            for j = 1:size(reg,1)

                y0 = (reg(j,1)-1)*grade + 1;
                y1 = min(reg(j,1)*grade, size(imgBin,1));

                x0 = (reg(j,2)-1)*grade + 1;
                x1 = min(reg(j,2)*grade, size(imgBin,2));

                imgOut(y0:y1, x0:x1) = 1;

            end
        end
    end
end

function regioes = encontrar_regioes_grade(gradeBin)
    [h, w] = size(gradeBin);
    visitado = false(h, w);
    regioes = {};
    dx = [1 -1 0 0];
    dy = [0 0 1 -1];

    for y = 1:h
        for x = 1:w
            if gradeBin(y,x) == 1 && ~visitado(y,x)
                fila = [y x];
                visitado(y,x) = true;
                reg = [];
                while ~isempty(fila)
                    p = fila(1,:);
                    fila(1,:) = [];
                    reg(end+1,:) = p;

                    for k = 1:4
                        ny = p(1) + dy(k);
                        nx = p(2) + dx(k);

                        if ny>=1 && ny<=h && nx>=1 && nx<=w
                            if gradeBin(ny,nx) == 1 && ~visitado(ny,nx)
                                visitado(ny,nx) = true;
                                fila(end+1,:) = [ny nx];
                            end
                        end
                    end
                end

                regioes{end+1} = reg;
            end
        end
    end
end

function gradeBin = construir_grade_binaria(imgBin, grade)
    [h, w] = size(imgBin);
    nY = ceil(h / grade);
    nX = ceil(w / grade);

    gradeBin = false(nY, nX);

    for gy = 1:nY
        y1 = (gy-1)*grade + 1;
        y2 = min(gy*grade, h);

        for gx = 1:nX
            x1 = (gx-1)*grade + 1;
            x2 = min(gx*grade, w);

            bloco = imgBin(y1:y2, x1:x2);
            % se tiver qualquer preto, bloco ativo, pois a etapa antirior definidou oq é branco
            gradeBin(gy, gx) = any(bloco(:) == 0);

        end
    end
end

function imgOut = remover_blocos_esparsos(imgBin, blocoTam)
    fun = @(bs) processar_bloco(bs.data);
    imgOut = blockproc(imgBin, [blocoTam blocoTam], fun);

end

function blocoProcessado = processar_bloco(bloco, ~)
    totalPixels = numel(bloco);
    pretos = sum(bloco(:) == 0);
    porcentagemPretos = pretos / totalPixels;
    
    if porcentagemPretos < 0.05
        % menos de 5% de pretos: torna bloco todo branco 
        blocoProcessado = ones(size(bloco), 'like', bloco);
    else
        % mantem o bloco original
        blocoProcessado = bloco;
    end
end


function imgComGrade = adicionar_grade(img, espacamento)
    if nargin < 2
        espacamento = 100;
    end

    imgComGrade = img;
    [h, w] = size(img);
    for x = espacamento:espacamento:w
        imgComGrade(:,x) = false; 
    end
    for y = espacamento:espacamento:h
        imgComGrade(y,:) = false;
    end
end

function imgOut = reduzir_resolucao(imgIn, fator)
    if fator <= 1
        imgOut = imgIn;
        return;
    end

    imgOut = imresize(imgIn, 1/fator, 'bilinear');
end

function imgBin = remover_regioes_caoticas(imgBin)
    janela = 16;
    [h,w] = size(imgBin);
    for y = 1:janela:h-janela+1
        for x = 1:janela:w-janela+1
            bloco = imgBin(y:y+janela-1, x:x+janela-1);
            tx = sum(sum(abs(diff(bloco,1,2)))); % transições horizontais
            ty = sum(sum(abs(diff(bloco,1,1)))); % transições verticais

            score = tx + ty;
            if score > 50
                imgBin(y:y+janela-1, x:x+janela-1) = 1;
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

% mantive para colocar no relatório que esse método não funciona
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