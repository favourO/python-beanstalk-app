#!/usr/bin/env python3
import json
import os
import re
import ssl
import sys
import time
from pathlib import Path
from urllib import request

import certifi


MODEL = "llama2:13b"
OLLAMA_API_URL = "http://127.0.0.1:11434/api/generate"
OPENAI_API_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1/chat/completions")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")
CHUNK_SIZE = 40
SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())

LANGS = {
    "fr": "French",
    "de": "German",
    "es": "Spanish",
    "pt": "Portuguese",
}

NON_TRANSLATABLE_KEYS = {"@@locale"}
PROVIDER = "ollama"


def load_be_env() -> None:
    env_path = Path(__file__).resolve().parents[2] / "BE" / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def call_ollama(prompt: str) -> str:
    payload = json.dumps(
        {
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.1,
            },
        }
    ).encode()
    req = request.Request(
        API_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=600, context=SSL_CONTEXT) as resp:
        body = json.loads(resp.read().decode())
    return body["response"]


def call_openai(prompt: str) -> str:
    api_key = os.getenv("OPENAI_API_KEY") or os.getenv("PHORA_LLM_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY or PHORA_LLM_API_KEY is required for provider=openai")
    payload = json.dumps(
        {
            "model": OPENAI_MODEL,
            "messages": [
                {
                    "role": "system",
                    "content": "You are a professional localization translator. Return valid JSON only.",
                },
                {
                    "role": "user",
                    "content": prompt,
                },
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }
    ).encode()
    req = request.Request(
        OPENAI_API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=600, context=SSL_CONTEXT) as resp:
        body = json.loads(resp.read().decode())
    return body["choices"][0]["message"]["content"]


def extract_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.S)
    if not match:
        raise ValueError(f"No JSON object found in response:\n{text}")
    return json.loads(match.group(0))


def translate_chunk(language_name: str, chunk: dict) -> dict:
    prompt = f"""Translate the JSON values into {language_name}.
Rules:
- Return JSON only.
- Keep all keys exactly unchanged.
- Preserve placeholders like {{count}}, {{name}}, {{start}}, {{end}}, newline escapes, punctuation, and emoji.
- Do not translate proper nouns like Phora, Apple Watch, HRV, LH, BBT, PCOS.
- Translate UI copy naturally for a women's health app.
- If a value is already a locale code, leave it unchanged.
JSON:
{json.dumps(chunk, ensure_ascii=False, indent=2)}
"""
    raw = call_openai(prompt) if PROVIDER == "openai" else call_ollama(prompt)
    translated = extract_json(raw)
    if set(translated.keys()) != set(chunk.keys()):
        raise ValueError("Translated keys do not match source keys")
    return translated


def translate_file(src_path: Path, dst_path: Path, language_code: str, limit: int | None = None):
    language_name = LANGS[language_code]
    source = json.loads(src_path.read_text())
    output = {}
    translatable_keys = []
    for key, value in source.items():
        if key.startswith("@") or key in NON_TRANSLATABLE_KEYS:
            output[key] = value
        else:
            translatable_keys.append(key)

    if limit is not None:
        translatable_keys = translatable_keys[:limit]

    for idx in range(0, len(translatable_keys), CHUNK_SIZE):
        keys = translatable_keys[idx : idx + CHUNK_SIZE]
        chunk = {key: source[key] for key in keys}
        translated = translate_chunk(language_name, chunk)
        output.update(translated)
        time.sleep(0.2)

    if limit is not None:
        for key in source.keys():
            if key not in output:
                output[key] = source[key]

    output["@@locale"] = language_code
    for key, value in source.items():
        if key.startswith("@") and key != "@@locale":
            output[key] = value

    ordered = {key: output[key] for key in source.keys()}
    dst_path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n")


def main():
    global PROVIDER
    load_be_env()
    root = Path(__file__).resolve().parents[1] / "lib" / "l10n"
    src = root / "app_en.arb"
    requested = sys.argv[1:] or list(LANGS.keys())
    if requested and requested[:2] == ["--provider", "openai"]:
        PROVIDER = "openai"
        requested = requested[2:]
    elif requested and requested[:2] == ["--provider", "ollama"]:
        PROVIDER = "ollama"
        requested = requested[2:]
    limit = None
    if requested and requested[-2:-1] == ["--limit"]:
        limit = int(requested[-1])
        requested = requested[:-2]
    for lang_code in requested:
        translate_file(src, root / f"app_{lang_code}.arb", lang_code, limit=limit)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
