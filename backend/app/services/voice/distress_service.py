from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import VoiceDistressEvent
from app.schemas.intelligence import VoiceAnalysisRequest, VoiceDistressResponse
from app.services.voice.gemini_voice_model import GeminiVoiceDistressModel
from app.services.voice.model_provider import RuleBasedVoiceModel, VoiceDistressModel


class VoiceDistressService:
    def __init__(
        self, db: AsyncSession, model: VoiceDistressModel | None = None
    ) -> None:
        self._db = db
        self._model = model or GeminiVoiceDistressModel()

    async def analyze_voice(
        self, user_id: str, req: VoiceAnalysisRequest
    ) -> VoiceDistressResponse:
        # Run voice analysis through the configured model
        result = await self._model.predict(
            text_or_transcript=req.transcript_or_text or "",
            voice_intensity=req.voice_intensity,
            pitch_variance=req.pitch_variance,
            speech_rate_wpm=req.speech_rate_wpm,
            duration_ms=req.duration_ms,
        )

        # Record event in DB
        event = VoiceDistressEvent(
            user_id=user_id,
            journey_id=req.journey_id,
            distress_score=result.distress_score,
            urgency=result.urgency,
            help_keyword_detected=result.help_keyword_detected,
            repetition_count=result.repetition_count,
            voice_intensity=result.voice_intensity,
            model_confidence=result.model_confidence,
            matched_keywords=result.matched_keywords,
        )
        self._db.add(event)
        await self._db.commit()

        return VoiceDistressResponse(
            signal="VOICE_DISTRESS",
            distress_score=result.distress_score,
            urgency=result.urgency,
            help_keyword=result.help_keyword_detected,
            repetition_count=result.repetition_count,
            voice_intensity=result.voice_intensity,
            model_confidence=result.model_confidence,
            matched_keywords=result.matched_keywords,
            message=result.explanation,
        )
