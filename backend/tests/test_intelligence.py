import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_voice_distress_analysis(client: AsyncClient, auth_headers: dict):
    # 1. Normal speech (no keywords, normal energy)
    normal_res = await client.post(
        "/api/v1/signals/voice",
        headers=auth_headers,
        json={
            "transcript_or_text": "I am walking home from work, having a nice day.",
            "voice_intensity": 0.4,
            "pitch_variance": 0.3,
        },
    )
    assert normal_res.status_code == 200
    normal_data = normal_res.json()
    assert normal_data["help_keyword"] is False
    assert normal_data["urgency"] == "LOW"
    assert normal_data["distress_score"] < 0.35

    # 2. Urgent distress speech ("help me please!", high volume)
    distress_res = await client.post(
        "/api/v1/signals/voice",
        headers=auth_headers,
        json={
            "transcript_or_text": "HELP ME PLEASE! SOMEONE HELP!",
            "voice_intensity": 0.9,
            "pitch_variance": 0.85,
            "duration_ms": 1500,
        },
    )
    assert distress_res.status_code == 200
    distress_data = distress_res.json()
    assert distress_data["help_keyword"] is True
    assert distress_data["repetition_count"] >= 2
    assert distress_data["distress_score"] >= 0.70
    assert distress_data["urgency"] in ("HIGH", "CRITICAL")


@pytest.mark.asyncio
async def test_motion_signal_processing(client: AsyncClient, auth_headers: dict):
    # 1. Shake signal
    shake_res = await client.post(
        "/api/v1/signals/motion",
        headers=auth_headers,
        json={
            "event_type": "SHAKE",
            "acceleration_peak": 3.2,
            "rotation_peak": 4.1,
            "duration_ms": 1200,
            "confidence": 0.8,
        },
    )
    assert shake_res.status_code == 200
    shake_data = shake_res.json()
    assert shake_data["event_type"] == "SHAKE_DETECTED"
    assert shake_data["evaluated_risk_contribution"] > 0.40

    # 2. Phone drop signal
    drop_res = await client.post(
        "/api/v1/signals/motion",
        headers=auth_headers,
        json={
            "event_type": "PHONE_DROP",
            "acceleration_peak": 4.5,
            "sudden_stop": True,
            "duration_ms": 400,
        },
    )
    assert drop_res.status_code == 200
    drop_data = drop_res.json()
    assert drop_data["event_type"] == "PHONE_DROP"
    assert drop_data["evaluated_risk_contribution"] >= 0.60


@pytest.mark.asyncio
async def test_multimodal_risk_fusion(client: AsyncClient, auth_headers: dict):
    # 1. Low risk with minor single signal
    low_res = await client.post(
        "/api/v1/risk/fuse",
        headers=auth_headers,
        json={
            "signals": [{"type": "MOTION_ANOMALY", "score": 0.20, "confidence": 0.7}],
            "guardian_mode_active": False,
        },
    )
    assert low_res.status_code == 200
    assert low_res.json()["risk_level"] == "LOW"
    assert low_res.json()["requires_user_prompt"] is False

    # 2. High/Critical risk with multiple synergistic signals (Voice + Drop + Deviation)
    critical_res = await client.post(
        "/api/v1/risk/fuse",
        headers=auth_headers,
        json={
            "signals": [
                {"type": "VOICE_DISTRESS", "score": 0.88, "confidence": 0.9},
                {"type": "PHONE_DROP", "score": 0.75, "confidence": 0.85},
                {"type": "ROUTE_DEVIATION", "score": 0.80, "confidence": 0.9},
            ],
            "guardian_mode_active": True,
            "nearby_safety_incident": True,
        },
    )
    assert critical_res.status_code == 200
    crit_data = critical_res.json()
    assert crit_data["risk_level"] in ("HIGH", "CRITICAL")
    assert crit_data["risk_score"] >= 0.75
    assert crit_data["requires_user_prompt"] is True
    assert len(crit_data["signals"]) == 3


@pytest.mark.asyncio
async def test_false_positive_feedback(client: AsyncClient, auth_headers: dict):
    fb_res = await client.post(
        "/api/v1/safety/false-positive",
        headers=auth_headers,
        json={
            "trigger_source": "SHAKE",
            "user_response": "I_AM_SAFE",
            "motion_score": 0.7,
            "notes": "Phone fell into gym bag",
        },
    )
    assert fb_res.status_code == 200
    fb_data = fb_res.json()
    assert fb_data["success"] is True
    assert fb_data["current_false_alarm_count"] >= 1


@pytest.mark.asyncio
async def test_safety_checkin_lifecycle(client: AsyncClient, auth_headers: dict):
    # 1. Start check-in
    start_res = await client.post(
        "/api/v1/checkins/start",
        headers=auth_headers,
        json={"title": "Night Run Check", "duration_minutes": 20},
    )
    assert start_res.status_code == 201
    checkin_data = start_res.json()
    checkin_id = checkin_data["id"]
    assert checkin_data["status"] == "ACTIVE"
    assert checkin_data["duration_minutes"] == 20

    # 2. List check-ins
    list_res = await client.get("/api/v1/checkins", headers=auth_headers)
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 1

    # 3. Confirm check-in
    confirm_res = await client.post(
        f"/api/v1/checkins/{checkin_id}/confirm", headers=auth_headers
    )
    assert confirm_res.status_code == 200
    assert confirm_res.json()["status"] == "CONFIRMED"


@pytest.mark.asyncio
async def test_offline_event_sync(client: AsyncClient, auth_headers: dict):
    idempotency_key = "test_sync_key_12345"
    sync_res = await client.post(
        "/api/v1/sync/events",
        headers=auth_headers,
        json={
            "events": [
                {
                    "idempotency_key": idempotency_key,
                    "entity_type": "MOTION",
                    "timestamp": "2026-08-15T10:00:00Z",
                    "payload": {"acceleration": 2.1},
                }
            ]
        },
    )
    assert sync_res.status_code == 200
    assert sync_res.json()["synced_count"] == 1
    assert sync_res.json()["duplicate_count"] == 0

    # Second sync with identical key (idempotency check)
    dup_res = await client.post(
        "/api/v1/sync/events",
        headers=auth_headers,
        json={
            "events": [
                {
                    "idempotency_key": idempotency_key,
                    "entity_type": "MOTION",
                    "timestamp": "2026-08-15T10:00:00Z",
                    "payload": {"acceleration": 2.1},
                }
            ]
        },
    )
    assert dup_res.status_code == 200
    assert dup_res.json()["synced_count"] == 0
    assert dup_res.json()["duplicate_count"] == 1


@pytest.mark.asyncio
async def test_recommendations(client: AsyncClient, auth_headers: dict):
    rec_res = await client.get("/api/v1/safety/recommendations", headers=auth_headers)
    assert rec_res.status_code == 200
    recs = rec_res.json()
    assert isinstance(recs, list)
