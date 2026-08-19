from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, List, Optional


@dataclass
class VoiceDistressResult:
    distress_score: float  # 0.0 to 1.0
    urgency: str  # LOW, MEDIUM, HIGH, CRITICAL
    help_keyword_detected: bool
    repetition_count: int
    voice_intensity: float
    model_confidence: float
    matched_keywords: List[str]
    explanation: str


class VoiceDistressModel(ABC):
    """Abstract interface for voice distress and emotion models."""

    @abstractmethod
    async def predict(
        self,
        text_or_transcript: str,
        voice_intensity: float,
        pitch_variance: float,
        speech_rate_wpm: Optional[int],
        duration_ms: int,
    ) -> VoiceDistressResult:
        """Evaluate distress score and urgency from acoustic + textual features."""
        pass


class RuleBasedVoiceModel(VoiceDistressModel):
    """
    Deterministic rule-based Voice Distress evaluator.
    Combines keyword lexicons, repetition count, shouting/energy, and speech rate.
    """

    async def predict(
        self,
        text_or_transcript: str,
        voice_intensity: float,
        pitch_variance: float,
        speech_rate_wpm: Optional[int],
        duration_ms: int,
    ) -> VoiceDistressResult:
        from app.services.voice.acoustic_analyzer import analyze_acoustics
        from app.services.voice.keyword_detector import detect_distress_keywords

        # 1. Keyword analysis
        kw_match = detect_distress_keywords(text_or_transcript)

        # 2. Acoustic analysis
        acoustic_score = analyze_acoustics(
            voice_intensity=voice_intensity,
            pitch_variance=pitch_variance,
            speech_rate_wpm=speech_rate_wpm,
            duration_ms=duration_ms,
        )

        # 3. Fuse keyword + acoustic signals
        # Base score from keyword urgency and repetition
        keyword_weight = 0.55 if kw_match.detected else 0.20
        acoustic_weight = 0.45 if kw_match.detected else 0.80

        raw_score = (kw_match.urgency_score * keyword_weight) + (acoustic_score * acoustic_weight)
        
        # Boost on severe repetition (e.g. "help help help")
        if kw_match.repetition_count >= 3:
            raw_score = min(1.0, raw_score + 0.20)
        elif kw_match.repetition_count >= 2:
            raw_score = min(1.0, raw_score + 0.10)

        # High voice intensity + distress keyword = High distress multiplier
        if kw_match.detected and voice_intensity >= 0.75:
            raw_score = min(1.0, raw_score * 1.25)

        distress_score = round(min(1.0, max(0.0, raw_score)), 2)

        # Determine Urgency
        if distress_score >= 0.80:
            urgency = "CRITICAL"
        elif distress_score >= 0.60:
            urgency = "HIGH"
        elif distress_score >= 0.35:
            urgency = "MEDIUM"
        else:
            urgency = "LOW"

        confidence = 0.85 if kw_match.detected else 0.70

        explanation = (
            f"Voice distress score {distress_score} ({urgency}) determined from "
            f"{'detected keywords: ' + ', '.join(kw_match.matched_keywords) if kw_match.detected else 'no keywords'} "
            f"and voice intensity {voice_intensity:.2f}."
        )

        return VoiceDistressResult(
            distress_score=distress_score,
            urgency=urgency,
            help_keyword_detected=kw_match.detected,
            repetition_count=kw_match.repetition_count,
            voice_intensity=voice_intensity,
            model_confidence=confidence,
            matched_keywords=kw_match.matched_keywords,
            explanation=explanation,
        )
