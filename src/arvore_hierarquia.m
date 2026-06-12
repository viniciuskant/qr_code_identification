function arvore = arvore_hierarquia(bordas, verbose)

    if nargin < 2
        verbose = false;
    end

    valores = unique(bordas);
    fundos = valores(mod(valores,2) == 0 & valores >= 0);
    objetos = unique(abs(valores(mod(abs(valores),2) == 1)));
    
    % fundo -> lista de objetos filhos diretos
    fundo_children = containers.Map('KeyType','int32','ValueType','any');
    for f = fundos'
        fundo_children(f) = [];
    end

    % objeto -> lista de fundos filhos diretos
    obj_children = containers.Map('KeyType','int32','ValueType','any');
    for obj = objetos'
        obj_children(obj) = [];
    end
    
    %para cada objeto descobrir seu fundo pai, procuramos a borda externa do objeto (positivo)
    for obj = objetos'
        pai_detectado = 0; % Fallback padrão: raiz
        [lin, col] = find(abs(bordas) == obj);
        
        % varre as bordas dos pixels do objeto para achar o fundo adjacente
        achou = false;
        for k = 1:length(lin)
            r = lin(k); c = col(k);
            for vizinhanca = [0 -1; 0 1; -1 0; 1 0]'
                nr = r + vizinhanca(1); nc = c + vizinhanca(2);
                if nr >= 1 && nr <= size(bordas,1) && nc >= 1 && nc <= size(bordas,2)
                    viz = bordas(nr,nc);
                    % Se for um fundo e diferente do próprio objeto
                    if mod(viz,2) == 0 && viz >= 0
                        % parao pai: o pixel onde o objeto é positivo (borda externa de entrada)
                        if bordas(r,c) > 0
                            pai_detectado = viz;
                            achou = true;
                            break;
                        end
                    end
                end
            end
            if achou, break; end
        end
        
        % adiciona a relação Pai (Fundo) -> Filho (Objeto)
        if isKey(fundo_children, pai_detectado)
            fundo_children(pai_detectado) = unique([fundo_children(pai_detectado), obj]);
        end
    end
    
    % para cada filho fundo, descobrir qual objeto o contém borda interna (neagtiva)
    for obj = objetos'
        [lin, col] = find(bordas == -obj); % apenas pixels negativos
        
        for k = 1:length(lin)
            r = lin(k); c = col(k);
            for vizinhanca = [0 -1; 0 1; -1 0; 1 0]'
                nr = r + vizinhanca(1); nc = c + vizinhanca(2);
                if nr >= 1 && nr <= size(bordas,1) && nc >= 1 && nc <= size(bordas,2)
                    viz = bordas(nr,nc);
                    % Se o vizinho for um fundo, ele é um fundo "filho" deste objeto
                    if mod(viz,2) == 0 && viz >= 0 && viz ~= 0
                        obj_children(obj) = unique([obj_children(obj), viz]);
                    end
                end
            end
        end
    end
    
    % arrumo as redundâncias:
        % se um fundo B foi classificado como filho de um objeto, ele NÃO pode ser 
        % filho direto do fundo raiz 0.
    todos_fundos_filhos = [];
    for obj = objetos'
        todos_fundos_filhos = [todos_fundos_filhos, obj_children(obj)];
    end
    todos_fundos_filhos = unique(todos_fundos_filhos);
    
    % print
    arvore = struct('raiz', 0, 'fundo_children', fundo_children, 'obj_children', obj_children);
    
    function print_node(val, nivel, tipo)
        indent = '';
        if nivel > 0
            indent = [repmat('    ', 1, nivel-1), '└── '];
        end
        
        if tipo == 'f'
            fprintf('%s[Fundo %d]\n', indent, val);
            if isKey(fundo_children, val)
                filhos = fundo_children(val);
                % rm da raiz fundos que já sabemos que estão dentro de objetos
                if val == 0
                     % filtro para não duplicar na raiz o que é interno
                end
                for child = filhos
                    % só imprime se o pai real dele for esse fundo
                    print_node(child, nivel+1, 'o');
                end
            end
        else
            fprintf('%s(Objeto %d)\n', indent, val);
            if isKey(obj_children, val)
                for child = obj_children(val)
                    print_node(child, nivel+1, 'f');
                end
            end
        end
    end
    
    if verbose
        print_node(0, 0, 'f');
    end
end