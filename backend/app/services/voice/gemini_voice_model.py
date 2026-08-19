from __future__ import annotations

from typing import List, Optional

from app.core.config import get_settings
from app.core.logging import get_logger
from app.services.gemini_service import GeminiService
from app.services.voice.acoustic_analyzer import analyze_acoustics
from app.services.voice.keyword_detector import detect_distress_keywords
from app.services.voice.model_provider import (
    RuleBasedVoiceModel,
    VoiceDistressModel,
    VoiceDistressResult,
)

settings = get_settings()
log = get_logger("gemini_voice_model")


class GeminiVoiceDistressModel(VoiceDistressModel):
    """
    Advanced Voice Distress understanding powered by Google Gemini,
    fused with deterministic acoustic energy and keyword detection.
    """

    def __init__(self, gemini_service: Optional[GeminiService] = None) -> None:
        self._gemini = gemini_service or GeminiService()
        self._fallback_model = RuleBasedVoiceModel()

    async def predict(
        self,
        text_or_transcript: str,
        voice_intensity: float,
        pitch_variance: float,
        speech_rate_wpm: Optional[int],
        duration_ms: int,
    ) -> VoiceDistressResult:
        # 1. Compute deterministic acoustic score
        acoustic_score = analyze_acoustics(
            voice_intensity=voice_intensity,
            pitch_variance=pitch_variance,
            speech_rate_wpm=speech_rate_wpm,
            duration_ms=duration_ms,
        )

        # 2. Compute deterministic keyword match
        kw_result = detect_distress_keywords(text_or_transcript)

        # 3. Call Gemini if configured and text is provided
        gemini_result = None
        if self._gemini.is_configured and text_or_transcript.strip():
            gemini_result = await self._analyze_with_gemini(
                text=text_or_transcript,
                voice_intensity=voice_intensity,
                acoustic_score=acoustic_score,
            )

        if gemini_result:
            return self._fuse_gemini_with_acoustics(
                gemini_data=gemini_result,
                acoustic_score=acoustic_score,
                voice_intensity=voice_intensity,
                kw_result=kw_result,
            )

        # Fallback to deterministic model
        return await self._fallback_model.predict(
            text_or_transcript=text_or_transcript,
            voice_intensity=voice_intensity,
            pitch_variance=pitch_variance,
            speech_rate_wpm=speech_rate_wpm,
            duration_ms=duration_ms,
        )

    async def _analyze_with_gemini(
        self, text: str, voice_intensity: float, acoustic_score: float
    ) -> Optional[dict]:
        prompt = (
            f"Analyze the following spoken utterance in a personal safety context:\n"
            f'Utterance: "{text}"\n'
            f"Voice acoustic intensity: {voice_intensity:.2f}\n"
            f"Acoustic distress marker: {acoustic_score:.2f}\n\n"
            f"Return a JSON object with:\n"
            f"- transcript: (string, verified or cleaned transcript)\n"
            f"- help_requested: (boolean, true if speaker appears to ask for help or intervention)\n"
            f"- urgency: (string: 'low', 'medium', 'high', or 'critical')\n"
            f"- threat_context: (string, concise summary of threat if any, else empty)\n"
            f"- distress_language: (boolean, true if alarming or coercive terms present)\n"
            f"- confidence: (float between 0.0 and 1.0)\n"
        )

        system_instruction = (
            "You are a personal safety speech evaluator. "
            "Evaluate whether the speaker is asking for help or expressing distress. "
            "Do not diagnose physical harm or claim definitive danger; categorize language objectively."
        )

        return await self._gemini.generate_json(
            prompt=prompt, system_instruction=system_instruction
        )

    def _fuse_gemini_with_acoustics(
        self,
        gemini_data: dict,
        acoustic_score: float,
        voice_intensity: float,
        kw_result,
    ) -> VoiceDistressResult:
        urgency_raw = str(gemini_data.get("urgency", "low")).upper()
        if urgency_raw not in ("LOW", "MEDIUM", "HIGH", "CRITICAL"):
            urgency_raw = "LOW"

        urgency_base_scores = {
            "CRITICAL": 0.85,
            "HIGH": 0.65,
            "MEDIUM": 0.40,
            "LOW": 0.15,
        }
        semantic_score = urgency_base_scores.get(urgency_raw, 0.15)
        help_req = bool(gemini_data.get("help_requested", False))
        confidence = float(gemini_data.get("confidence", 0.80))

        # Weighting: 60% semantic + 40% acoustic
        combined_score = (semantic_score * 0.60) + (acoustic_score * 0.40)

        if help_req and voice_intensity >= 0.70:
            combined_score = min(1.0, combined_score + 0.15)

        distress_score = round(min(1.0, max(0.0, combined_score)), 2)

        # Re-evaluate final urgency tier
        if distress_score >= 0.80:
            final_urgency = "CRITICAL"
        elif distress_score >= 0.60:
            final_urgency = "HIGH"
        elif distress_score >= 0.35:
            final_urgency = "MEDIUM"
        else:
            final_urgency = "LOW"

        threat = gemini_data.get("threat_context", "")
        explanation = (
            f"Gemini Voice evaluated as {final_urgency} (score: {distress_score}). "
            f"{'Threat context: ' + threat if threat else 'Language context: ' + ('help requested' if help_req else 'ambient')}."
        )

        return VoiceDistressResult(
            distress_score=distress_score,
            urgency=final_urgency,
            help_keyword_detected=help_req or kw_result.detected,
            repetition_count=kw_result.repetition_count,
            voice_intensity=voice_intensity,
            model_confidence=round(confidence, 2),
            matched_keywords=kw_result.matched_keywords,
            explanation=explanation,
        )
