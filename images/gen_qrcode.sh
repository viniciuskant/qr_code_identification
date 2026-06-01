if [ $# -ne 1 ]; then
    echo "Uso: $0 <quantidade>"
    exit 1
fi

QTD=$1

mkdir -p ref

for ((i=1; i<=QTD; i++)); do
    TOKEN=$(openssl rand -hex 16)
    URL="https://example.com/${TOKEN}"

    NUM=$(printf "%02d" "$i")
    ARQ="ref/qrcode_${NUM}.jpeg"

    qrencode "$URL" \
        -s 12 \
        -m 2  \
        -o "$ARQ" \
        --background=FFFFFF \
        --foreground=000000

    echo "Gerado: $ARQ"
done
