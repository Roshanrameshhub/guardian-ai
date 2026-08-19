from __future__ import annotations

from typing import Optional


def analyze_acoustics(
    voice_intensity: float,
    pitch_variance: float,
    speech_rate_wpm: Optional[int],
    duration_ms: int,
) -> float:
    """
    Evaluates acoustic markers associated with urgent or distressed vocalizations.
    
    Factors:
    - High RMS energy / volume intensity (shouting/screaming)
    - High pitch variance or extreme pitch shift (panic/inflection)
    - Rapid speech rate (>180 WPM) or extremely fragmented short bursts (<800ms)
    
    Returns an acoustic distress score from 0.0 to 1.0.
    """
    intensity_norm = max(0.0, min(1.0, voice_intensity))
    pitch_norm = max(0.0, min(1.0, pitch_variance))

    score = 0.0

    # 1. Voice Intensity / Volume contribution (40% weight)
    if intensity_norm >= 0.85:
        score += 0.40
    elif intensity_norm >= 0.65:
        score += 0.25
    elif intensity_norm >= 0.45:
        score += 0.10

    # 2. Pitch Instability / Variance (30% weight)
    if pitch_norm >= 0.80:
        score += 0.30
    elif pitch_norm >= 0.60:
        score += 0.20
    elif pitch_norm >= 0.40:
        score += 0.10

    # 3. Speech Rate / Burst Cadence (30% weight)
    if speech_rate_wpm is not None:
        if speech_rate_wpm > 200:  # Fast panicked speech
            score += 0.30
        elif speech_rate_wpm > 160:
            score += 0.18
        elif speech_rate_wpm < 60:  # Strained/gasping slow speech
            score += 0.15
    else:
        # If speech rate not supplied, allocate based on duration
        if duration_ms < 1000 and intensity_norm > 0.70:  # Short loud shout
            score += 0.25
        elif duration_ms < 2500 and intensity_norm > 0.60:
            score += 0.15

    return round(min(1.0, score), 2)
