import sys
import unicodedata
from pathlib import Path

def para_ascii(texto):
    resultado = []

    for c in texto:
        # Mantém ASCII normal
        if ord(c) < 128:
            resultado.append(c)
            continue

        # Tenta converter para equivalente ASCII
        normalizado = unicodedata.normalize("NFKD", c)
        ascii_str = normalizado.encode("ascii", "ignore").decode("ascii")

        if ascii_str:
            resultado.append(ascii_str)
        else:
            resultado.append(" ")

    return "".join(resultado)

def main():
    if len(sys.argv) != 2:
        print("Uso: python script.py <arquivo>")
        sys.exit(1)

    arquivo = Path(sys.argv[1])

    texto = arquivo.read_text(encoding="utf-8", errors="replace")
    texto_modificado = para_ascii(texto)

    novo_arquivo = arquivo.with_name(
        f"{arquivo.stem}_modificado{arquivo.suffix}"
    )

    novo_arquivo.write_text(texto_modificado, encoding="utf-8")

    print(f"Salvo em: {novo_arquivo}")

if __name__ == "__main__":
    main()