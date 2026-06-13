import cv2
import numpy as np
from pathlib import Path

# Diretórios
bin_dir = Path("output/binarizacao")
coords_dir = Path("output/coordenadas")
output_dir = Path("output/planificados")
output_dir.mkdir(parents=True, exist_ok=True)

TAMANHO_SAIDA = 400
EXPANSAO = 0.45

pts_destino = np.float32([
    [0, 0],
    [TAMANHO_SAIDA, 0],
    [0, TAMANHO_SAIDA]
])

print("Iniciando planificação com expansão dos pontos de origem...")

for coords_file in sorted(coords_dir.glob("*.txt")):
    nome_base = coords_file.stem
    img_path = bin_dir / f"{nome_base}.tif"
    if not img_path.exists():
        print(f"Imagem não encontrada: {img_path}")
        continue

    print(f"Planificando: {nome_base} ...")
    img = cv2.imread(str(img_path))
    if img is None:
        print(f"Erro ao ler {img_path}")
        continue

    with open(coords_file, "r") as f:
        linha = f.readline().strip()
    coords = list(map(float, linha.split()))
    if len(coords) != 6:
        print(f"Formato inválido em {coords_file.name}: esperado 6 números")
        continue

    centros = np.array([
        [coords[1], coords[0]],
        [coords[3], coords[2]],
        [coords[5], coords[4]]
    ])

    # Identifica o vértice do ângulo reto (canto superior esquerdo)
    melhor_idx = 0
    menor_produto = float('inf')
    for i in range(3):
        p = centros[i]
        a = centros[(i+1)%3] - p
        b = centros[(i+2)%3] - p
        norma_a = np.linalg.norm(a)
        norma_b = np.linalg.norm(b)
        if norma_a == 0 or norma_b == 0:
            continue
        a_norm = a / norma_a
        b_norm = b / norma_b
        produto = abs(np.dot(a_norm, b_norm))
        if produto < menor_produto:
            menor_produto = produto
            melhor_idx = i

    sup_esq = centros[melhor_idx]
    outros = [centros[(melhor_idx+1)%3], centros[(melhor_idx+2)%3]]

    # Determina superior direito (maior x) e inferior esquerdo (maior y)
    if outros[0][0] > outros[1][0]:
        sup_dir = outros[0]
    else:
        sup_dir = outros[1]

    if outros[0][1] > outros[1][1]:
        inf_esq = outros[0]
    else:
        inf_esq = outros[1]

    # Calcula o centróide do triângulo original
    centroide = (sup_esq + sup_dir + inf_esq) / 3.0

    # Expande cada vértice para fora do triângulo
    def expandir(ponto, centroide, fator):
        return ponto + (ponto - centroide) * fator

    sup_esq_exp = expandir(sup_esq, centroide, EXPANSAO)
    sup_dir_exp = expandir(sup_dir, centroide, EXPANSAO)
    inf_esq_exp = expandir(inf_esq, centroide, EXPANSAO)

    pts_origem = np.float32([sup_esq_exp, sup_dir_exp, inf_esq_exp])

    # Calcula e aplica a transformação afim
    M = cv2.getAffineTransform(pts_origem, pts_destino)
    qr_planificado = cv2.warpAffine(img, M, (TAMANHO_SAIDA, TAMANHO_SAIDA))

    out_path = output_dir / f"{nome_base}_plano.png"
    cv2.imwrite(str(out_path), qr_planificado)
    print(f"Salvo: {out_path}")

print("\nPlanificação concluída.")