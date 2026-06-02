import cv2
import numpy as np
from pathlib import Path

input_dir = Path("output/binarizacao")

output_dir = Path("output/hierarquia")
output_dir.mkdir(parents=True, exist_ok=True)

coords_dir = Path("output/coords")
coords_dir.mkdir(parents=True, exist_ok=True)


def get_quad_vertices(contour):
    # aproxima o contorno para polígono
    epsilon = 0.02 * cv2.arcLength(contour, True)
    approx = cv2.approxPolyDP(contour, epsilon, True)

    # queremos apenas quadrados/quadriláteros
    if len(approx) != 4:
        return None

    return approx.reshape(4, 2)


def is_qrcode_anchor(idx, hierarchy, contours):
    child1 = hierarchy[idx][2]
    if child1 == -1:
        return False

    child2 = hierarchy[child1][2]
    if child2 == -1:
        return False

    if hierarchy[child2][2] != -1:
        return False

    for cidx in [idx, child1, child2]:
        x, y, w, h = cv2.boundingRect(contours[cidx])
        ratio = w / h
        if not (0.83 <= ratio <= 1.2):
            return False

    return True


for img_path in sorted(input_dir.iterdir()):
    print(f"processando {img_path.name}...")

    binary = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
    if binary is None:
        print(f"erro ao ler {img_path}")
        continue

    contours, hierarchy = cv2.findContours(
        binary, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE
    )

    if hierarchy is None:
        print(f"sem contornos: {img_path.name}")
        continue

    hierarchy = hierarchy[0]

    vis = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)

    coords_file = coords_dir / f"{img_path.stem}.txt"

    with open(coords_file, "w") as f:

        for i in range(len(contours)):
            if is_qrcode_anchor(i, hierarchy, contours):
                child1 = hierarchy[i][2]
                child2 = hierarchy[child1][2]

                for cidx in [i, child1, child2]:
                    vertices = get_quad_vertices(contours[cidx])

                    if vertices is None:
                        continue

                    # salva no arquivo
                    line = " ".join(f"{x} {y}" for x, y in vertices)
                    f.write(line + "\n")

                    # desenha visualização
                    cv2.drawContours(vis, contours, cidx, (0, 0, 255), thickness=cv2.FILLED)

    output_file = output_dir / f"{img_path.stem}.png"
    cv2.imwrite(str(output_file), vis)

    print(f"Salvo imagem em {output_file}")
    print(f"Salvo coordenadas em {coords_file}")