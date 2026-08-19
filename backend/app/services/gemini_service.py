from __future__ import annotations

import json
from typing import Any, Dict, Optional
import httpx

from app.core.config import get_settings
from app.core.logging import get_logger

settings = get_settings()
log = get_logger("gemini_service")


class GeminiService:
    """
    Lightweight, high-performance async client for Google Gemini API.
    Uses standard REST endpoints with zero heavyweight dependencies.
    """

    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None) -> None:
        self._api_key = api_key or settings.gemini_api_key
        self._model = model or settings.gemini_model or "gemini-1.5-flash"

    @property
    def is_configured(self) -> bool:
        return bool(self._api_key and self._api_key != "your_gemini_api_key")

    async def generate_text(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> Optional[str]:
        """Generate plain text from Gemini."""
        if not self.is_configured:
            return None

        url = f"{self.BASE_URL}/models/{self._model}:generateContent?key={self._api_key}"
        
        contents = []
        contents.append({"role": "user", "parts": [{"text": prompt}]})

        body: Dict[str, Any] = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens,
            },
        }

        if system_instruction:
            body["systemInstruction"] = {
                "parts": [{"text": system_instruction}]
            }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                resp = await client.post(url, json=body)
                if resp.status_code == 200:
                    data = resp.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        parts = candidates[0].get("content", {}).get("parts", [])
                        if parts:
                            return parts[0].get("text", "")
                else:
                    log.warning("gemini_api_error", status_code=resp.status_code, body=resp.text[:200])
        except Exception as e:
            log.warning("gemini_call_failed", error=str(e))

        return None

    async def generate_json(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.2,
    ) -> Optional[Dict[str, Any]]:
        """Generate structured JSON object from Gemini."""
        if not self.is_configured:
            return None

        url = f"{self.BASE_URL}/models/{self._model}:generateContent?key={self._api_key}"
        
        body: Dict[str, Any] = {
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": temperature,
                "responseMimeType": "application/json",
                "maxOutputTokens": settings.ai_max_context_tokens,
            },
        }

        if system_instruction:
            body["systemInstruction"] = {
                "parts": [{"text": system_instruction}]
            }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                resp = await client.post(url, json=body)
                if resp.status_code == 200:
                    data = resp.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        parts = candidates[0].get("content", {}).get("parts", [])
                        if parts:
                            raw_text = parts[0].get("text", "").strip()
                            # Clean possible markdown wrapping
                            if raw_text.startswith("```json"):
                                raw_text = raw_text.split("```json", 1)[1]
                            if raw_text.endswith("```"):
                                raw_text = raw_text.rsplit("```", 1)[0]
                            return json.loads(raw_text.strip())
                else:
                    log.warning("gemini_json_api_error", status_code=resp.status_code)
        except Exception as e:
            log.warning("gemini_json_call_failed", error=str(e))

        return None
