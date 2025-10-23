#!/bin/bash

# Usage: run.sh [ -l lang ] [ -m model ] [ -h ]
# Options:
#   -l lang     - Spoken language
#   -m model    - Model to load
#   -h          - Show this message

usage()
{
    cat <<EOF
Usage: $0 [ -l lang ] [ -m model ] [ -h]
Options:
    -l lang     - Spoken language
    -m model    - Model to load
    -h          - Show this message
EOF
}

lang=en
model=large-v3-turbo

while getopts "l:m:h" opt; do
    case ${opt} in
        l)
            lang=${OPTARG}
            ;;
        m)
            model=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

whisper-server -pr -pp -fa -l ${lang} -m /opt/whisper.cpp/models/ggml-${model}.bin --host 127.0.0.1 --port 8910 &
/opt/wyoming-whisper-api-client/.venv/bin/wyoming-whisper-api-client --api http://127.0.0.1:8910/inference --uri tcp://0.0.0.0:10300 &

wait -n
exit $?
