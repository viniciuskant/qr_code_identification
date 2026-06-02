# Projeto de Detecção de QR Codes

## Obtendo as imagens

As imagens utilizadas no projeto podem ser baixadas com:

```bash
cd images
./download_image.sh [ref] [laterais] [frontais] [todas]
```
basta escolher o pacote desejado.

### Diretório `ref`

O diretório `ref` não contém imagens capturadas. Ele contém QR Codes de referência gerados pelo script:

```bash
./gen_qrcode.sh <n>
```

## Processamento das imagens no MATLAB
Após obter as imagens, execute:

```matlab
binarizar_png
```

O script gera versões binarizadas das imagens e aplica supressão de ruído.

Os resultados são armazenados nos diretórios de saída correspondentes.

## Detecção de cantos

### `cantos.m`

Script auxiliar utilizado apenas para visualizar os cantos encontrados e verificar o posicionamento dos pontos detectados.

### `detectar_cantos.m`

Função responsável pela detecção efetiva dos cantos presentes na imagem.

## Implementação em Python

### `suzuri_abe.py`

Contém uma implementação inicial baseada no trabalho de Suzuri e Abe para localizar os padrões de localização (finder patterns) dos QR Codes.

Atualmente o código realiza a etapa inicial de identificação desses padrões. Salva em `output/hierarquia` a representação visual dos padrões candidatos encontrados na análise de contornos e hierarquia. E em `output/coords` armazena as coordenadas dos padrões detectados.

O formato é:

```text
x y  x y  x y  x y   (quadrado maior)
x y  x y  x y  x y   (quadrado intermediário)
x y  x y  x y  x y   (quadrado menor)
```

Cada grupo de três linhas representa um padrão de localização encontrado.

Esse formato é repetido para todos os padrões detectados na imagem.
