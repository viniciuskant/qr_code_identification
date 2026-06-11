import sys
import random

def main():
    if len(sys.argv) != 4:
        print("Uso: python create_matrix.py L C p")
        sys.exit(1)

    L = int(sys.argv[1])
    C = int(sys.argv[2])
    p = float(sys.argv[3])

    matriz = []
    for _ in range(L):
        linha = [1 if random.random() < p else 0 for _ in range(C)]
        matriz.append(linha)

    for linha in matriz:
        print(' '.join(str(val) for val in linha))

if __name__ == "__main__":
    main()