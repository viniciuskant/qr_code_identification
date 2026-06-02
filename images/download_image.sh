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

download_ref() {
    download_zip \
        "1wlIJQtHuurkuvMICShBXQ1-LB7FcUqFs" \
        "ref.zip"
}

download_frontais() {
    download_zip \
        "1PSepX05JDyY60Rl9X-RboDJdMbgvH40c" \
        "frontais.zip"
}
download_laterais() {
    download_zip \
        "1Sgx1-EcuoJ0V8uzzplhS3_Xl6g78Uzgu" \
        "laterais.zip"
}

download_todas() {
    download_zip \
        "1IylS2-objFMwU2AIgry2v8jpv62EUTlO" \
        "todas.zip"
}

if [[ $# -eq 0 ]]; then
    download_todas
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        ref) download_ref ;;
        frontais) download_frontais ;;
        laterais) download_laterais ;;
        todas) download_todas ;;
        *)
            echo "Uso: $0 [ref] [laterais] [frontais] [todas]"
            exit 1
            ;;
    esac
done
