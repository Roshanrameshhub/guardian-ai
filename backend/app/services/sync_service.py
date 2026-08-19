from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.intelligence import SyncRecord
from app.schemas.intelligence import SyncBatchRequest, SyncBatchResponse


class OfflineSyncService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def process_sync_batch(
        self, user_id: str, req: SyncBatchRequest
    ) -> SyncBatchResponse:
        synced_count = 0
        duplicate_count = 0
        failed_count = 0

        for event_item in req.events:
            # Check idempotency key
            existing = await self._db.scalar(
                select(SyncRecord).where(
                    SyncRecord.idempotency_key == event_item.idempotency_key
                )
            )
            if existing:
                duplicate_count += 1
                continue

            try:
                # Record the sync log
                record = SyncRecord(
                    user_id=user_id,
                    idempotency_key=event_item.idempotency_key,
                    entity_type=event_item.entity_type,
                    payload=event_item.payload,
                    synced_at=datetime.now(tz=timezone.utc),
                )
                self._db.add(record)
                synced_count += 1
            except Exception:
                failed_count += 1

        if synced_count > 0:
            await self._db.commit()

        message = (
            f"Batch sync complete: {synced_count} events processed, "
            f"{duplicate_count} duplicates skipped, {failed_count} failures."
        )

        return SyncBatchResponse(
            success=failed_count == 0,
            synced_count=synced_count,
            duplicate_count=duplicate_count,
            failed_count=failed_count,
            message=message,
        )
