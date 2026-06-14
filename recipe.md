# DIY AI: Build a Private Chatbot on Lean Hardware with Fedora

Commands-only recipe for the Flock 2026 workshop.
Full blog posts: [Part 1](https://ai.fedoraproject.org/running-an-open-source-ai-chatbot-on-lean-hardware-with-fedora-part-1-our-first-chat/) · [Part 2](https://ai.fedoraproject.org/running-an-open-source-ai-chatbot-on-lean-hardware-with-fedora-part-2-lets-talk/) · [Part 3](https://ai.fedoraproject.org/running-an-open-source-ai-chatbot-on-lean-hardware-with-fedora-part-3-the-prompt/) · [Part 4](https://ai.fedoraproject.org/running-an-open-source-ai-chatbot-on-lean-hardware-with-fedora-part-4-knowledge/)

---

## Get the models (~5 min)

Three options — pick whichever works:

**USB drive** (from the front of the room):
```bash
mkdir -p ~/chatbot
cp /run/media/$USER/DISK_IMG/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf ~/chatbot/
cp /run/media/$USER/DISK_IMG/ggml-base.en.bin ~/chatbot/
cp /run/media/$USER/DISK_IMG/fedora-docs.sql ~/chatbot/
```

**Instructor's server** (check the slide for IP):
```bash
mkdir -p ~/chatbot && cd ~/chatbot
curl -O http://INSTRUCTOR_IP:8080/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf
curl -O http://INSTRUCTOR_IP:8080/ggml-base.en.bin
curl -O http://INSTRUCTOR_IP:8080/fedora-docs.sql
```

**Internet** (if WiFi is good):
```bash
mkdir -p ~/chatbot && cd ~/chatbot
curl -L -o microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
  https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf
```

> The LLM is 2.3 GB — USB is fastest. Start the copy, then move to Part 1 while it transfers.

---

## Part 1 — First Chat (~35 min)

```bash
sudo dnf install -y cmake make gcc git gcc-c++ libcurl-devel

cd ~/chatbot
git clone --branch b7783 --depth 1 https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DLLAMA_BUILD_EXAMPLES=ON
cmake --build . --config Release
```

> Build takes 5–10 minutes. Good time to stretch or help a neighbor.

```bash
mkdir -p ~/chatbot/llama.cpp/models
cp ~/chatbot/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf ~/chatbot/llama.cpp/models/

cd ~/chatbot/llama.cpp/build
./bin/llama-cli \
  -m ../models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
  -c 4096 \
  -p "You are a helpful assistant."
```

✓ You see a `>` prompt. Type a question. Try: *What should I have for lunch?*

`/exit` to quit.

---

## Part 2 — Voice Chat (~40 min)

```bash
sudo dnf install -y alsa-utils portaudio-devel espeak
```

### Test your microphone

```bash
cd ~/chatbot
arecord -f S16_LE -r 16000 -d 5 input.wav
```

✓ Speak for 5 seconds. You should see recording progress.

### Build whisper.cpp

```bash
cd ~/chatbot
git clone --branch v1.8.3 --depth 1 https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make
```

```bash
cp ~/chatbot/ggml-base.en.bin ~/chatbot/whisper.cpp/models/
```

### Test speech-to-text

```bash
cd ~/chatbot/whisper.cpp
./build/bin/whisper-cli -m models/ggml-base.en.bin -f ../input.wav
```

✓ You should see your words transcribed as text.

### Create talk.sh

Paste this entire block to create the script:

```bash
cat > ~/chatbot/talk.sh << 'TALKSCRIPT'
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
    -m ./llama.cpp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
    -p "$TRANSCRIPT" \
    -n 150 \
    -c 4096 \
    -no-cnv \
    -r "<eor>" \
    --simple-io \
    --color off \
    --no-display-prompt
)

echo "🤖 $RESPONSE"
echo "$RESPONSE" | espeak
TALKSCRIPT
chmod +x ~/chatbot/talk.sh
```

```bash
cd ~/chatbot
./talk.sh
```

✓ You speak → it transcribes → LLM responds → you hear it. Full loop!

Try: *Who are your favorite fictional artificial intelligences?*

---

## ⭐ Stretch Goals — if time permits

---

## Part 3 — The Prompt (~10 min)

Give your chatbot a personality. Replace `talk.sh` with this version:

```bash
cat > ~/chatbot/talk.sh << 'TALKSCRIPT'
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

PROMPT="You are Brim, a steadfast butler-like advisor created by Ellis.
Your pronouns are they/them. You are deeply caring, supportive, and empathetic, but never effusive.
You speak in a calm, friendly, casual tone suitable for text-to-speech.

Rules:
- Reply with only ONE short message directly to the user.
- Do not write any dialogue labels (User:, Assistant:, Q:, A:), or invent more turns.
- 100 words or less.
- End with a gentle question, then write <eor> and stop.

User: $TRANSCRIPT
Assistant:"

RESPONSE=$(
  LLAMA_LOG_VERBOSITY=1 ./llama.cpp/build/bin/llama-completion \
    -m ./llama.cpp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
    -p "$PROMPT" \
    -n 150 \
    -c 4096 \
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
TALKSCRIPT
chmod +x ~/chatbot/talk.sh
```

```bash
cd ~/chatbot && ./talk.sh
```

✓ Responses are shorter, friendlier, and end with a question.

Customize the prompt! Change the name, personality, tone, word limit — it's your chatbot.

---

## Part 4 — Knowledge / RAG (~15 min)

```bash
sudo dnf install -y uv podman podman-compose postgresql
uv python install 3.12

cd ~/chatbot
uvx --python 3.12 docs2db db-start
uvx --python 3.12 docs2db db-restore fedora-docs.sql
```

### Test a query

```bash
uvx --python 3.12 docs2db-api query \
  "What is the recommended tool for upgrading between major releases on Fedora Silverblue" \
  --format text --max-chars 2000 --no-refine
```

✓ You should see chunks of Fedora docs. One mentions *ostree*.

### Hook RAG into talk.sh

Replace `talk.sh` one last time:

```bash
cat > ~/chatbot/talk.sh << 'TALKSCRIPT'
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
    -m ./llama.cpp/models/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf \
    -p "$PROMPT" \
    -n 150 \
    -c 4096 \
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
TALKSCRIPT
chmod +x ~/chatbot/talk.sh
```

```bash
cd ~/chatbot && ./talk.sh
```

Ask: *What is the recommended tool for upgrading between major releases on Fedora Silverblue?*

✓ Answer should mention **ostree**.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `cmake` fails | Make sure `gcc-c++` is installed |
| `arecord` not found | `sudo dnf install alsa-utils` |
| No sound devices | `arecord -l` to list — you may need `pulseaudio-utils` |
| Whisper gives garbage | Make sure you recorded at 16000 Hz (`-r 16000`) |
| `espeak` silent | `pactl list sinks` — ensure output isn't muted |
| `docs2db db-start` fails | `sudo systemctl start podman` |
| Model download slow | Grab a USB from the front or use the local server |
| USB not showing up | `lsblk` to see devices, mount manually |
