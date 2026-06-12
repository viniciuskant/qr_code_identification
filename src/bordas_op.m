function saida = bordas_op(M)
    [linhas, cols] = size(M);
    
    % rotulo as regiões de fundo (zeros) com números pares, subdividindo ela em varios fundos
    % bwconncomp com conectividade 8
    cc_fundo = bwconncomp(~M, 8);
    num_fundos = cc_fundo.NumObjects;
    rotuloFundo = zeros(linhas, cols); % inicialmente 0

    toca_borda = false(1, num_fundos);
    for k = 1:num_fundos
        pixels = cc_fundo.PixelIdxList{k};
        [rows, cols_p] = ind2sub([linhas, cols], pixels);
        if any(rows==1 | rows==linhas | cols_p==1 | cols_p==cols)
            toca_borda(k) = true;
        end
    end

    % componente que toca a borda receberá rótulo 0, as outras recebem 2,4,6,...
    par_atual = 0;
    for k = 1:num_fundos
        if toca_borda(k)
            rotulo = 0;
        else
            par_atual = par_atual + 2;
            rotulo = par_atual;
        end
        rotuloFundo(cc_fundo.PixelIdxList{k}) = rotulo;
    end
    
    %###############################
    % rotular objetos (uns) com números ímpares (1,3,5,...)
    cc_obj = bwconncomp(M, 4);
    num_objetos = cc_obj.NumObjects;
    saida = rotuloFundo;
    
    % obter lista de pixels e classificar
    proximoImpar = 1;
    for k = 1:num_objetos
        pixel_idx = cc_obj.PixelIdxList{k}; % índices lineares
        [r, c] = ind2sub([linhas, cols], pixel_idx);
        coords = [r, c];
        
        % determinar o "fundo de chegada" do objeto
        rotulosVizinhos = [];
        for i = 1:length(r)
            ri = r(i); ci = c(i);
            if ri > 1 && M(ri-1, ci) == 0
                rotulosVizinhos(end+1) = rotuloFundo(ri-1, ci);
            end
            if ri < linhas && M(ri+1, ci) == 0
                rotulosVizinhos(end+1) = rotuloFundo(ri+1, ci);
            end
            if ci > 1 && M(ri, ci-1) == 0
                rotulosVizinhos(end+1) = rotuloFundo(ri, ci-1);
            end
            if ci < cols && M(ri, ci+1) == 0
                rotulosVizinhos(end+1) = rotuloFundo(ri, ci+1);
            end
        end
        % fundo de chegada e a prioridade é o fundo externo (0)
        if any(rotulosVizinhos == 0)
            fundoChegada = 0;
        elseif ~isempty(rotulosVizinhos) % caso contrário, pega o menor rótulo de fundo encontrado
            fundoChegada = min(rotulosVizinhos); % menor par (>0)
        else
            fundoChegada = []; % objeto não toca fundo
        end
        
        rotuloObj = proximoImpar;
        %classifica de cada pixel baseada no fundo de chegada
        for i = 1:length(r)
            ri = r(i); ci = c(i);
            viz_pixel = [];
            if ri > 1 && M(ri-1, ci) == 0
                viz_pixel(end+1) = rotuloFundo(ri-1, ci);
            end
            if ri < linhas && M(ri+1, ci) == 0
                viz_pixel(end+1) = rotuloFundo(ri+1, ci);
            end
            if ci > 1 && M(ri, ci-1) == 0
                viz_pixel(end+1) = rotuloFundo(ri, ci-1);
            end
            if ci < cols && M(ri, ci+1) == 0
                viz_pixel(end+1) = rotuloFundo(ri, ci+1);
            end
            
            if isempty(viz_pixel)
                saida(ri, ci) = rotuloObj; % interior
            elseif any(viz_pixel == fundo_chegada)
                saida(ri, ci) = rotuloObj; % borda positiva
            else
                saida(ri, ci) = -rotuloObj; % borda negativa
            end
        end
        
        proximoImpar = proximoImpar + 2;
    end
end