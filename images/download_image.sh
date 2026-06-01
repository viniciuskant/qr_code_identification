#!/usr/bin/env bash

set -euo pipefail

DEST_DIR="$(pwd)"
TMP_DIR="/tmp"

download_zip() {
    local file_id="$1"
    local zip_name="$2"

    local zip_path="${TMP_DIR}/${zip_name}"
    local extract_dir

    extract_dir=$(mktemp -d)

    echo "Baixando ${zip_name}..."

    wget \
        -O "$zip_path" \
        "https://drive.usercontent.google.com/download?id=${file_id}&export=download&confirm=t"

    echo "Descompactando..."

    unzip -q "$zip_path" -d "$extract_dir"

    # Move todas as pastas extraídas
    find "$extract_dir" -mindepth 1 -maxdepth 1 -type d -exec mv -t "$DEST_DIR" {} +

    rm -rf "$extract_dir"
    rm -f "$zip_path"

    echo "OK: ${zip_name}"
}

download_jpg() {
    download_zip \
        "1AahVnQTOmREru_mV3GGIHfXNABSev0TM" \
        "jpg.zip"
}

download_png() {
    download_zip \
        "1fFg79pMWvzHSBQVMwdnL8BibhsokED0W" \
        "png.zip"
}

if [[ $# -eq 0 ]]; then
    download_jpg
    download_png
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        jpg) download_jpg ;;
        png) download_png ;;
        *)
            echo "Uso: $0 [jpg] [png]"
            exit 1
            ;;
    esac
done
