#!/bin/bash

# run.sh [options]
# -l <lang>
# -m <model>

lang=en
model=large-v3-turbo

whisper-server -pr -pp -fa -l ${lang} -m /opt/whisper.cpp/models/ggml-${model}.bin --host 127.0.0.1 --port 8910 &
/opt/wyoming-whisper-api-client/.venv/bin/wyoming-whisper-api-client --api http://127.0.0.1:8910/inference --uri tcp://0.0.0.0:10300 &

wait -n
exit $?
