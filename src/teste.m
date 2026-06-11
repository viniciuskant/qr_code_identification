function teste()
    arquivoTxt = '../matrix/t05.txt';
    M = load(arquivoTxt);
    M = round(M);
    M(isnan(M) | isinf(M)) = 0;
    
    M = (M ~= 0);
    
    [linhas, cols] = size(M);
    
    % rotulo as regiões de fundo (zeros) com números pares, subdividindo ela em varios fundos
    rotuloFundo = -ones(linhas, cols);
    proximoPar = 0;   % começamos com 0
    
    % identifico todos os pixels de fundo (M == 0) usando 8‑vizinhança
    for i = 1:linhas
        for j = 1:cols
            if M(i, j) == 0 && rotuloFundo(i, j) == -1
                % BFS/DFS para rotular este componente de fundo
                pilha = [i, j];
                rotuloFundo(i, j) = proximoPar;
                coords = [];
                while ~isempty(pilha)
                    atual = pilha(end, :);
                    pilha(end, :) = [];
                    r = atual(1); c = atual(2);
                    coords = [coords; r, c];
                    for dr = -1:1
                        for dc = -1:1
                            if dr == 0 && dc == 0
                                continue;
                            end
                            nr = r + dr;
                            nc = c + dc;
                            if nr >= 1 && nr <= linhas && nc >= 1 && nc <= cols && ...
                            M(nr, nc) == 0 && rotuloFundo(nr, nc) == -1
                                rotuloFundo(nr, nc) = proximoPar;
                                pilha = [pilha; nr, nc];
                            end
                        end
                    end
                end
                proximoPar = proximoPar + 2;
            end
        end
    end
    
    % garantir que o fundo que toca a borda da imagem seja rotulado como 0
    % se o primeiro componente rotulado não tocar a borda, trocamos os rótulos.
    % Assim evitando o caso de uma linha dividindo a imagem e desconiderando que é o mesmo fundo
    tocaBorda = false;
    for i = 1:linhas
        for j = 1:cols
            if rotuloFundo(i,j) == 0
                if i==1 || i==linhas || j==1 || j==cols
                    tocaBorda = true;
                    break;
                end
            end
        end
    end
    if ~tocaBorda
        %encontra algum componente que toca a borda e troca com o 0
        for i = 1:linhas
            for j = 1:cols
                if rotuloFundo(i,j) ~= -1 && (i==1 || i==linhas || j==1 || j==cols)
                    rotuloToca = rotuloFundo(i,j);
                    % trocar todos com rótulo 0 por rotuloToca, e vice-versa
                    rotuloFundo(rotuloFundo == 0) = -2; % temporário
                    rotuloFundo(rotuloFundo == rotuloToca) = 0;
                    rotuloFundo(rotuloFundo == -2) = rotuloToca;
                    break;
                end
            end
        end
    end
    
    %###############################
    % rotular objetos (uns) com números ímpares (1,3,5,...)
    visitado = false(linhas, cols);
    proximoImpar = 1;
    % Matriz de saída (inicializada com os rótulos de fundo)
    saida = rotuloFundo;
    
    for i = 1:linhas
        for j = 1:cols
            if M(i, j) == 1 && ~visitado(i, j)
                % Coleta todos os pixels do objeto via DFS
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
                
                % determinar o "fundo de chegada" do objeto
                rotulosVizinhos = [];
                for k = 1:size(objetoCoords,1)
                    r = objetoCoords(k,1); c = objetoCoords(k,2);
                    if r-1 >= 1 && M(r-1,c) == 0
                        rotulosVizinhos = [rotulosVizinhos; rotuloFundo(r-1,c)];
                    end
                    if r+1 <= linhas && M(r+1,c) == 0
                        rotulosVizinhos = [rotulosVizinhos; rotuloFundo(r+1,c)];
                    end
                    if c-1 >= 1 && M(r,c-1) == 0
                        rotulosVizinhos = [rotulosVizinhos; rotuloFundo(r,c-1)];
                    end
                    if c+1 <= cols && M(r,c+1) == 0
                        rotulosVizinhos = [rotulosVizinhos; rotuloFundo(r,c+1)];
                    end
                end
                % fundo de chegada e a prioridade é o fundo externo (0)
                if any(rotulosVizinhos == 0)
                    fundoChegada = 0;
                else
                    % caso contrário, pega o menor rótulo de fundo encontrado
                    if ~isempty(rotulosVizinhos)
                        fundoChegada = min(rotulosVizinhos);
                    else
                        fundoChegada = []; % objeto sem contato com fundo (ilha isolada)
                    end
                end
                
                rotuloObj = proximoImpar;
                %classifica de cada pixel baseada no fundo de chegada
                for k = 1:size(objetoCoords,1)
                    r = objetoCoords(k,1); c = objetoCoords(k,2);
                    vizinhosFundo = [];
                    if r-1 >= 1 && M(r-1,c) == 0
                        vizinhosFundo = [vizinhosFundo; rotuloFundo(r-1,c)];
                    end
                    if r+1 <= linhas && M(r+1,c) == 0
                        vizinhosFundo = [vizinhosFundo; rotuloFundo(r+1,c)];
                    end
                    if c-1 >= 1 && M(r,c-1) == 0
                        vizinhosFundo = [vizinhosFundo; rotuloFundo(r,c-1)];
                    end
                    if c+1 <= cols && M(r,c+1) == 0
                        vizinhosFundo = [vizinhosFundo; rotuloFundo(r,c+1)];
                    end
                    
                    if isempty(vizinhosFundo)
                        saida(r,c) = rotuloObj;
                    elseif any(vizinhosFundo == fundoChegada)
                        saida(r,c) = rotuloObj;
                    else
                        saida(r,c) = -rotuloObj;
                    end
                end
                
                proximoImpar = proximoImpar + 2;
            end
        end
    end
    
    fprintf('\nMatriz:\n');
    for i = 1:linhas
        for j = 1:cols
            fprintf('%3d ', saida(i, j));
        end
        fprintf('\n');
    end
    
    totalObjetos = (proximoImpar - 1) / 2;
    fprintf('\nTotal de objetos encontrados: %d\n', totalObjetos);
end