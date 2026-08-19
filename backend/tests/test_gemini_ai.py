from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.services.ai_service import AIRouteExplainerService, AIJourneySummaryService
from app.services.voice.gemini_voice_model import GeminiVoiceDistressModel


@pytest.mark.asyncio
async def test_gemini_voice_distress_model():
    """Verify Gemini voice model evaluates text and acoustics with deterministic fallback."""
    model = GeminiVoiceDistressModel()
    result = await model.predict(
        text_or_transcript="Help me please, someone is following me!",
        voice_intensity=0.85,
        pitch_variance=0.75,
        speech_rate_wpm=210,
        duration_ms=2500,
    )
    assert result.distress_score >= 0.50
    assert result.urgency in ("MEDIUM", "HIGH", "CRITICAL")
    assert result.help_keyword_detected is True
    assert "help" in result.matched_keywords or "help me" in result.matched_keywords


@pytest.mark.asyncio
async def test_ai_route_explainer():
    """Verify route explainer creates a non-empty explanation without inventing facts."""
    route_facts = {
        "role": "Safer Route",
        "duration_minutes": 25,
        "distance_km": 11.2,
        "safety_score": 88,
        "traffic_condition": "Moderate",
        "evaluation_period": "Night",
        "reason": "Optimal night route prioritizing well-lit, populated corridors and active police presence.",
        "impacted_zones": [],
    }
    explanation = await AIRouteExplainerService.explain_route(route_facts)
    assert len(explanation) > 10
    assert "route" in explanation.lower() or "guardian" in explanation.lower() or "night" in explanation.lower()


@pytest.mark.asyncio
async def test_ai_journey_summary():
    """Verify journey summary creates a factual completion summary."""
    facts = {
        "origin": "Chennai Central",
        "destination": "Adyar",
        "elapsed_minutes": 32,
        "original_eta_minutes": 28,
        "deviations_count": 0,
        "reroutes_count": 0,
    }
    summary = await AIJourneySummaryService.summarize_journey(facts)
    assert len(summary) > 10
    assert "Chennai Central" in summary or "Adyar" in summary or "32" in summary


@pytest.mark.asyncio
async def test_voice_signal_api_endpoint(client: AsyncClient, auth_headers: dict):
    """Verify POST /api/v1/signals/voice processes distress requests."""
    payload = {
        "transcript_or_text": "Please help, emergency!",
        "voice_intensity": 0.8,
        "pitch_variance": 0.7,
        "speech_rate_wpm": 190,
        "duration_ms": 2000,
    }
    resp = await client.post("/api/v1/signals/voice", json=payload, headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["signal"] == "VOICE_DISTRESS"
    assert data["distress_score"] >= 0.50
    assert data["help_keyword"] is True


@pytest.mark.asyncio
async def test_ai_chat_endpoint(client: AsyncClient, auth_headers: dict):
    """Verify POST /api/v1/ai/chat returns contextual safety guidance."""
    payload = {
        "message": "Is it safe to walk at night near Central Station?",
    }
    resp = await client.post("/api/v1/ai/chat", json=payload, headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert "assistant_message" in data
    assert len(data["assistant_message"]) > 0
