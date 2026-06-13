from __future__ import annotations

import hashlib
import math
import re

import httpx


LOCAL_EMBEDDING_MODEL = "vyla-local-hash-embedding-v1"
LOCAL_EMBEDDING_DIMENSIONS = 96

REAL_EMBEDDING_MODEL = "text-embedding-3-small"
REAL_EMBEDDING_DIMENSIONS = 1536
REAL_EMBEDDING_INPUT_LIMIT = 8192  # chars; well within token limit for short memory summaries


class AIMemoryEmbeddingService:
    """Hash-based bag-of-words embedder — zero dependencies, used for SQLite/tests."""

    def __init__(self, *, dimensions: int = LOCAL_EMBEDDING_DIMENSIONS):
        self.dimensions = dimensions

    def embed(self, text: str) -> list[float]:
        vector = [0.0] * self.dimensions
        for token in self._tokens(text):
            digest = hashlib.sha256(token.encode("utf-8")).digest()
            index = int.from_bytes(digest[:4], "big") % self.dimensions
            sign = 1.0 if digest[4] % 2 == 0 else -1.0
            vector[index] += sign
        norm = math.sqrt(sum(value * value for value in vector))
        if norm == 0:
            return vector
        return [round(value / norm, 6) for value in vector]

    def cosine_similarity(self, left: list[float] | None, right: list[float] | None) -> float:
        if not left or not right:
            return 0.0
        length = min(len(left), len(right))
        if length == 0:
            return 0.0
        return float(sum(float(left[index]) * float(right[index]) for index in range(length)))

    def _tokens(self, text: str) -> list[str]:
        return [
            token
            for token in re.findall(r"[a-z0-9]{3,}", text.lower())
            if token not in {"what", "when", "does", "with", "about", "this", "that", "have", "today"}
        ]


class OpenAIEmbeddingService:
    """Real semantic embeddings via OpenAI-compatible /v1/embeddings endpoint."""

    def __init__(self, *, api_key: str, base_url: str, model: str = REAL_EMBEDDING_MODEL):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.dimensions = REAL_EMBEDDING_DIMENSIONS

    def embed(self, text: str) -> list[float]:
        response = httpx.post(
            f"{self.base_url}/embeddings",
            headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
            json={"model": self.model, "input": text[:REAL_EMBEDDING_INPUT_LIMIT]},
            timeout=30.0,
        )
        response.raise_for_status()
        return response.json()["data"][0]["embedding"]

    def cosine_similarity(self, left: list[float] | None, right: list[float] | None) -> float:
        if not left or not right:
            return 0.0
        norm_l = math.sqrt(sum(x * x for x in left))
        norm_r = math.sqrt(sum(x * x for x in right))
        if not norm_l or not norm_r:
            return 0.0
        return sum(a * b for a, b in zip(left, right)) / (norm_l * norm_r)
