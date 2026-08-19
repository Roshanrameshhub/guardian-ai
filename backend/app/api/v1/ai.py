from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.core.dependencies import CurrentUserId, DbSession
from app.models.ai import AiConversation, AiMessage, AiMessageRole
from app.schemas.common import ApiMessageResponse

router = APIRouter(prefix="/ai", tags=["AI Safety Assistant"])


class ChatRequest(ApiMessageResponse):
    """Re-using for simplicity."""
    conversation_id: str | None = None
    user_message: str = ""

    # Override parent fields with defaults
    success: bool = True
    message: str = ""


class ChatResponse(ApiMessageResponse):
    conversation_id: str = ""
    assistant_message: str = ""
    context_used: list[str] = []


class InsightItem(ApiMessageResponse):
    category: str = ""
    insight: str = ""
    evidence: str = ""
    action: str | None = None
    success: bool = True
    message: str = ""


@router.post("/chat", response_model=ChatResponse)
async def ai_chat(
    req: ChatRequest,
    user_id: CurrentUserId,
    db: DbSession,
) -> ChatResponse:
    """
    AI Safety Assistant chat endpoint.
    Uses ContextBuilder to collect permitted context before calling AI provider.
    """
    from app.services.ai_service import AIChatService
    svc = AIChatService(db)
    return await svc.chat(user_id, req.user_message, req.conversation_id)


@router.get("/conversations")
async def list_conversations(user_id: CurrentUserId, db: DbSession) -> list[dict]:
    """List AI conversation history for the current user."""
    conversations = (
        await db.scalars(
            select(AiConversation)
            .where(AiConversation.user_id == user_id)
            .order_by(AiConversation.updated_at.desc())
            .limit(20)
        )
    ).all()
    return [{"id": c.id, "title": c.title, "updated_at": c.updated_at.isoformat()} for c in conversations]


@router.get("/conversations/{conversation_id}")
async def get_conversation(
    conversation_id: str, user_id: CurrentUserId, db: DbSession
) -> dict:
    """Get messages for a specific conversation."""
    from app.core.exceptions import ForbiddenError, NotFoundError

    conv = await db.get(AiConversation, conversation_id)
    if not conv:
        raise NotFoundError("Conversation not found.")
    if conv.user_id != user_id:
        raise ForbiddenError()

    messages = (
        await db.scalars(
            select(AiMessage)
            .where(AiMessage.conversation_id == conversation_id)
            .order_by(AiMessage.created_at)
        )
    ).all()

    return {
        "id": conv.id,
        "title": conv.title,
        "messages": [
            {"role": m.role.value, "content": m.content, "created_at": m.created_at.isoformat()}
            for m in messages
        ],
    }


@router.get("/insights")
async def get_insights(user_id: CurrentUserId, db: DbSession) -> list[dict]:
    """
    Get AI-generated safety insights based on user's journey history.
    Based purely on evidence — no fabricated predictions.
    """
    from app.services.ai_service import AIInsightService
    svc = AIInsightService(db)
    return await svc.generate_insights(user_id)
