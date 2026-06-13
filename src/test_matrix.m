function test_matrix()
    arquivoTxt = '../matrix/t06.txt';
    M = load(arquivoTxt);
    M = round(M);
    M(isnan(M) | isinf(M)) = 0;
    
    M = (M ~= 0);  
    [linhas, cols] = size(M);

    saida = bordas(M);

    fprintf('\nMatriz:\n');
    for i = 1:linhas
        for j = 1:cols
            fprintf('%3d ', saida(i, j));
        end
        fprintf('\n');
    end
    fprintf('\n\n');
    arvore = arvore_hierarquia(saida, true);
end