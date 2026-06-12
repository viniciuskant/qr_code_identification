import sys
import random
import argparse

def create_random_matrix(rows, cols, p):
    return [[1 if random.random() < p else 0 for _ in range(cols)] for _ in range(rows)]

def create_pattern_matrix(size, thickness):
    if size % 2 == 0:
        size += 1
    center = size // 2
    matriz = [[0] * size for _ in range(size)]
    
    for i in range(size):
        for j in range(size):
            dist = max(abs(i - center), abs(j - center))
            layer = dist // thickness
            matriz[i][j] = 1 if (layer % 2 == 0) else 0
    return matriz

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('L', type=int, help='Número de linhas')
    parser.add_argument('C', type=int, help='Número de colunas')
    parser.add_argument('--pattern', type=int, metavar='N',
                        help='Gera padrão de anéis com espessura N (ignora p)')
    parser.add_argument('p', type=float, nargs='?', default=None,
                        help='Probabilidade de ser 1 (usado se --pattern não for fornecido)')
    args = parser.parse_args()

    if args.pattern is not None:

        size = max(args.L, args.C)
        matriz = create_pattern_matrix(size, args.pattern)
    else:
        if args.p is None:
            print("Erro: forneça a probabilidade p ou use a flag --pattern")
            sys.exit(1)
        matriz = create_random_matrix(args.L, args.C, args.p)

    for linha in matriz:
        print(' '.join(str(val) for val in linha))

if __name__ == "__main__":
    main()