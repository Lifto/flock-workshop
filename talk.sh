#!/usr/bin/env bash
set -e
AUDIO=input.wav

echo "🎙️  Speak now..."
arecord -f S16_LE -r 16000 -d 5 -q "$AUDIO"

TRANSCRIPT=$(./whisper.cpp/build/bin/whisper-cli \
  -m ./whisper.cpp/models/ggml-base.en.bin \
  -f "$AUDIO" \
  | grep '^\[' \
  | sed -E 's/^\[[^]]+\][[:space:]]*//' \
  | tr -d '\n')
echo "🗣️  $TRANSCRIPT"

RESPONSE=$(
  LLAMA_LOG_VERBOSITY=1 ./llama.cpp/build/bin/llama-completion \
    -m ~/chatbot/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
    -p "$TRANSCRIPT" \
    -n 150 \
    -c 512 \
    -no-cnv \
    -r "<eor>" \
    --simple-io \
    --color off \
    --no-display-prompt
)

echo "🤖 $RESPONSE"
echo "$RESPONSE" | espeak
