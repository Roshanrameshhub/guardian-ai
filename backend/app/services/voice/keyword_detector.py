from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List


@dataclass
class KeywordMatchResult:
    detected: bool
    matched_keywords: List[str]
    repetition_count: int
    urgency_score: float  # 0.0 to 1.0


# Multi-tier distress lexicons
CRITICAL_KEYWORDS = {
    "help",
    "help me",
    "help please",
    "please help",
    "save me",
    "emergency",
    "sos",
    "attack",
    "let me go",
    "leave me alone",
    "stay away",
    "someone help",
    "call the police",
    "call police",
    "fire",
    "danger",
}

SECONDARY_KEYWORDS = {
    "scared",
    "stop",
    "no",
    "hurry",
    "follow",
    "following me",
    "unsafe",
    "hurt",
    "trapped",
    "threat",
}


def detect_distress_keywords(text: str | None) -> KeywordMatchResult:
    """Analyze transcribed text for distress keywords and calculate repetition."""
    if not text or not text.strip():
        return KeywordMatchResult(
            detected=False,
            matched_keywords=[],
            repetition_count=0,
            urgency_score=0.0,
        )

    clean_text = text.lower()
    words = re.findall(r"\b\w+\b", clean_text)
    
    matched: list[str] = []
    critical_count = 0
    secondary_count = 0

    # 1. Check phrase matches
    for kw in CRITICAL_KEYWORDS:
        if kw in clean_text:
            matched.append(kw)
            critical_count += 1

    for kw in SECONDARY_KEYWORDS:
        if kw in clean_text and kw not in matched:
            matched.append(kw)
            secondary_count += 1

    # 2. Check repetitions of core word 'help' or exclamation
    help_repetition = sum(1 for w in words if "help" in w)
    total_repetition = max(help_repetition, len(matched))

    detected = len(matched) > 0 or help_repetition > 0

    if not detected:
        return KeywordMatchResult(
            detected=False,
            matched_keywords=[],
            repetition_count=0,
            urgency_score=0.0,
        )

    # 3. Urgency scoring
    base_urgency = 0.50
    if critical_count > 0:
        base_urgency += min(0.35, critical_count * 0.15)
    if secondary_count > 0:
        base_urgency += min(0.15, secondary_count * 0.05)
    if total_repetition >= 3:
        base_urgency += 0.20
    elif total_repetition >= 2:
        base_urgency += 0.10

    # Check for all-caps / exclamation urgency in original text
    if "!" in text or text.isupper():
        base_urgency += 0.10

    urgency_score = min(1.0, round(base_urgency, 2))

    return KeywordMatchResult(
        detected=True,
        matched_keywords=list(set(matched)),
        repetition_count=total_repetition,
        urgency_score=urgency_score,
    )
