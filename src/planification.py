import cv2
import numpy as np
from pathlib import Path

# Configuração dos diretórios (padrão do projeto)
bin_dir = Path("output/binarizacao")
coords_dir = Path("output/coords")
output_dir = Path("output/planificados")
output_dir.mkdir(parents=True, exist_ok=True)

# Tamanho final desejado para o QR Code plano de saída (colado na borda)
TAMANHO_SAIDA = 400

# Mapeamento dos 3 pontos de destino ocupando as extremidades cravadas (0 e 400)
# [Superior Esquerdo, Superior Direito, Inferior Esquerdo]
pts_destino = np.float32([
    [0, 0],                  # Canto superior esquerdo absoluto
    [TAMANHO_SAIDA, 0],      # Canto superior direito absoluto
    [0, TAMANHO_SAIDA]       # Canto inferior esquerdo absoluto
])

print("Iniciando a planificação sem bordas (área total)...")

for coords_file in sorted(coords_dir.glob("*.txt")):
    nome_base = coords_file.stem
    img_path = bin_dir / f"{nome_base}.tif"
    
    if not img_path.exists():
        continue
        
    print(f"Planificando: {nome_base}...")
    img = cv2.imread(str(img_path))
    
    with open(coords_file, "r") as f:
        linhas = f.readlines()
    
    if len(linhas) < 3:
        print(f"Erro: Coordenadas insuficientes em {coords_file.name}")
        continue
        
    # Função para extrair todos os 4 vértices do quadrado maior de uma quina
    def extrair_vertices_maiores(linha_str):
        coords = [float(x) for x in linha_str.split()]
        return np.array([
            [coords[0], coords[1]],
            [coords[2], coords[3]],
            [coords[4], coords[5]],
            [coords[6], coords[7]]
        ])

    # Pega os vértices externos de cada uma das 3 quinas detectadas
    v_quina1 = extrair_vertices_maiores(linhas[0])
    v_quina2 = extrair_vertices_maiores(linhas[3])
    v_quina3 = extrair_vertices_maiores(linhas[6])
    
    # Calcula os centros para descobrir a geometria global do triângulo
    c1 = np.mean(v_quina1, axis=0)
    c2 = np.mean(v_quina2, axis=0)
    c3 = np.mean(v_quina3, axis=0)
    
    # Centro de massa global (baricentro do QR Code)
    baricentro_global = (c1 + c2 + c3) / 3.0
    
    # Encontra a ponta mais externa de cada marcador para garantir o enquadramento completo
    def achar_vertice_externo(vertices, centro_global):
        distancias = [np.linalg.norm(pt - centro_global) for pt in vertices]
        return vertices[np.argmax(distancias)]

    p1_externo = achar_vertice_externo(v_quina1, baricentro_global)
    p2_externo = achar_vertice_externo(v_quina2, baricentro_global)
    p3_externo = achar_vertice_externo(v_quina3, baricentro_global)
    
    # --- IDENTIFICAÇÃO GEOMÉTRICA DA QUINA PIVOT (90 GRAUS) ---
    pontos = [p1_externo, p2_externo, p3_externo]
    melhor_pivot_idx = 0
    menor_produto_escalar = float('inf')
    
    for i in range(3):
        p_atual = pontos[i]
        p_outro1 = pontos[(i + 1) % 3]
        p_outro2 = pontos[(i + 2) % 3]
        
        v1 = p_outro1 - p_atual
        v2 = p_outro2 - p_atual
        v1_norm = v1 / np.linalg.norm(v1)
        v2_norm = v2 / np.linalg.norm(v2)
        
        prod_escalar = abs(np.dot(v1_norm, v2_norm))
        if prod_escalar < menor_produto_escalar:
            menor_produto_escalar = prod_escalar
            melhor_pivot_idx = i

    sup_esq = pontos[melhor_pivot_idx]
    quina_b = pontos[(melhor_pivot_idx + 1) % 3]
    quina_c = pontos[(melhor_pivot_idx + 2) % 3]
    
    # --- DETERMINAÇÃO DE ORIENTAÇÃO (HORIZONTAL VS VERTICAL) ---
    v_b = quina_b - sup_esq
    v_c = quina_c - sup_esq
    det = v_b[0] * v_c[1] - v_b[1] * v_c[0]
    
    if det > 0:
        sup_dir = quina_b
        inf_esq = quina_c
    else:
        sup_dir = quina_c
        inf_esq = quina_b

    # Monta a matriz de origem com os 3 pontos para a transformação Afim
    pts_origem = np.float32([sup_esq, sup_dir, inf_esq])
    
    # 4. Calcular a Matriz de Transformação Afim
    M = cv2.getAffineTransform(pts_origem, pts_destino)
    
    # 5. Aplicar o warp para esticar o QR Code até os cantos do arquivo
    qr_planificado = cv2.warpAffine(img, M, (TAMANHO_SAIDA, TAMANHO_SAIDA))
    
    # 6. Salvar o arquivo cortado rente às quinas
    output_file = output_dir / f"{nome_base}_plano.png"
    cv2.imwrite(str(output_file), qr_planificado)

print("\nConcluído! Todos os QR Codes foram planificados ocupando 100% da imagem.")