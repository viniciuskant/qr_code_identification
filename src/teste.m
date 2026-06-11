function teste()
    arquivoTxt = '../matrix/t02.txt';
    M = load(arquivoTxt);
    M = round(M);
    M(isnan(M) | isinf(M)) = 0;
    
    M = (M ~= 0);
    M = double(M);

    [linhas, cols] = size(M);
    visitado = false(linhas, cols);
    proximoRotulo = 2;

    for i = 1:linhas
        for j = 1:cols
            if M(i, j) == 1 && ~visitado(i, j)
                pilha = [i, j];
                visitado(i, j) = true;
                objetoCoords = [];
                while ~isempty(pilha)
                    atual = pilha(end, :);
                    pilha(end, :) = [];
                    r = atual(1); c = atual(2);
                    objetoCoords = [objetoCoords; r, c];
                    
                    if r-1 >= 1 && M(r-1, c) == 1 && ~visitado(r-1, c)
                        visitado(r-1, c) = true;
                        pilha = [pilha; r-1, c];
                    end
                    if r+1 <= linhas && M(r+1, c) == 1 && ~visitado(r+1, c)
                        visitado(r+1, c) = true;
                        pilha = [pilha; r+1, c];
                    end
                    if c-1 >= 1 && M(r, c-1) == 1 && ~visitado(r, c-1)
                        visitado(r, c-1) = true;
                        pilha = [pilha; r, c-1];
                    end
                    if c+1 <= cols && M(r, c+1) == 1 && ~visitado(r, c+1)
                        visitado(r, c+1) = true;
                        pilha = [pilha; r, c+1];
                    end
                end
                % Atribuir rótulo
                for k = 1:size(objetoCoords, 1)
                    M(objetoCoords(k,1), objetoCoords(k,2)) = proximoRotulo;
                end
                proximoRotulo = proximoRotulo + 1;
            end
        end
    end

    % Exibir resultado
    fprintf('\nMatriz com objetos rotulados:\n');
    for i = 1:linhas
        for j = 1:cols
            fprintf('%d ', M(i, j));
        end
        fprintf('\n');
    end
    fprintf('\nTotal de objetos encontrados: %d\n', proximoRotulo - 2);
end
