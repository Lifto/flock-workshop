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

echo "📚 Searching documentation..."
CONTEXT=$(uvx --python 3.12 docs2db-api query "$TRANSCRIPT" \
  --format text --max-chars 2000 --no-refine 2>/dev/null || echo "")

PROMPT="You are Brim, a steadfast butler-like advisor created by Ellis.
Your pronouns are they/them. You are deeply caring, supportive, and empathetic, but never effusive.
You speak in a calm, friendly, casual tone suitable for text-to-speech.

Rules:
- Reply with only ONE short message directly to the user.
- Do not write any dialogue labels (User:, Assistant:, Q:, A:), or invent more turns.
- 100 words or less.
- If the documentation below is relevant, use it to inform your answer.
- End with a gentle question, then write <eor> and stop.

Relevant Fedora Documentation:
$CONTEXT

User: $TRANSCRIPT
Assistant:"

RESPONSE=$(
  LLAMA_LOG_VERBOSITY=1 ./llama.cpp/build/bin/llama-completion \
    -m ~/chatbot/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
    -p "$PROMPT" \
    -n 150 \
    -c 512 \
    -no-cnv \
    -r "<eor>" \
    --simple-io \
    --color off \
    --no-display-prompt
)

RESPONSE_CLEAN=$(echo "$RESPONSE" | sed -E 's/<eor>.*//I')
RESPONSE_CLEAN=$(echo "$RESPONSE_CLEAN" | sed -E 's/^[[:space:]]*Assistant:[[:space:]]*//I')

echo "🤖 $RESPONSE_CLEAN"
echo "$RESPONSE_CLEAN" | espeak
