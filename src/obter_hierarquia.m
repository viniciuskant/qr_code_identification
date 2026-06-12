function profundidades = obter_hierarquia(arvore)
    profundidades = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
    function dfs(valor, tipo, prof_atual)
        if tipo == 'o'
            profundidades(valor) = prof_atual;
            if isKey(arvore.obj_children, valor)
                for filho = arvore.obj_children(valor)
                    dfs(filho, 'f', prof_atual + 1);
                end
            end
        else
            if isKey(arvore.fundo_children, valor)
                for filho = arvore.fundo_children(valor)
                    dfs(filho, 'o', prof_atual + 1);
                end
            end
        end
    end
    dfs(0, 'f', 0);
end

