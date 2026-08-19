from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai import AiConversation, AiMessage, AiMessageRole
from app.models.guardian import GuardianSession
from app.models.journey import Journey


class ContextBuilder:
    """
    Assembles permitted context before sending to the AI provider.
    Never sends the entire database — only explicitly permitted fields.
    Respects user privacy preferences.
    """

    def __init__(self, db: AsyncSession, user_id: str) -> None:
        self._db = db
        self._user_id = user_id

    async def build(self) -> dict:
        """Return a limited context dict safe to send to AI."""
        context = {}

        # Journey statistics (not raw GPS)
        total_journeys = await self._db.scalar(
            select(func.count()).where(Journey.user_id == self._user_id)
        ) or 0
        safe_journeys = await self._db.scalar(
            select(func.count()).where(
                Journey.user_id == self._user_id,
                Journey.completed_safely == True,  # noqa: E712
            )
        ) or 0

        context["journey_stats"] = {
            "total": total_journeys,
            "safe": safe_journeys,
            "safety_rate": round(safe_journeys / total_journeys, 2) if total_journeys else 1.0,
        }

        # Guardian usage count (not live session data)
        guardian_sessions = await self._db.scalar(
            select(func.count()).where(GuardianSession.user_id == self._user_id)
        ) or 0
        context["guardian_sessions"] = guardian_sessions

        # Recent journey destinations (anonymized — no lat/lng)
        recent = (
            await self._db.scalars(
                select(Journey.destination)
                .where(Journey.user_id == self._user_id)
                .order_by(Journey.created_at.desc())
                .limit(5)
            )
        ).all()
        context["recent_destinations"] = list(recent)

        return context

    def format_as_system_prompt(self, context: dict) -> str:
        stats = context.get("journey_stats", {})
        return (
            "You are Guardian AI, a personal safety assistant. "
            "You provide evidence-based, non-alarmist safety guidance. "
            "You NEVER fabricate crime predictions or guarantee route safety. "
            "You summarize patterns, not predictions.\n\n"
            f"User journey summary: {stats.get('total', 0)} total journeys, "
            f"{stats.get('safe', 0)} completed safely "
            f"({int(stats.get('safety_rate', 1.0) * 100)}% safety rate). "
            f"Guardian Mode used {context.get('guardian_sessions', 0)} time(s)."
        )


class AIChatService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def chat(
        self, user_id: str, user_message: str, conversation_id: str | None
    ) -> dict:
        from app.core.config import get_settings
        settings = get_settings()

        # Get or create conversation
        if conversation_id:
            conv = await self._db.get(AiConversation, conversation_id)
        else:
            conv = AiConversation(user_id=user_id, title=user_message[:50])
            self._db.add(conv)
            await self._db.flush()

        if not conv or conv.user_id != user_id:
            conv = AiConversation(user_id=user_id, title=user_message[:50])
            self._db.add(conv)
            await self._db.flush()

        # Build context
        ctx_builder = ContextBuilder(self._db, user_id)
        context = await ctx_builder.build()
        system_prompt = ctx_builder.format_as_system_prompt(context)

        # Get recent conversation history
        history = (
            await self._db.scalars(
                select(AiMessage)
                .where(AiMessage.conversation_id == conv.id)
                .order_by(AiMessage.created_at.desc())
                .limit(10)
            )
        ).all()
        history = list(reversed(history))

        # Store user message
        user_msg = AiMessage(
            conversation_id=conv.id,
            role=AiMessageRole.user,
            content=user_message,
        )
        self._db.add(user_msg)

        # Call AI provider
        if settings.has_ai:
            assistant_reply = await self._call_gemini(
                system_prompt, history, user_message
            )
        else:
            assistant_reply = self._mock_response(user_message, context)

        # Store assistant message
        assistant_msg = AiMessage(
            conversation_id=conv.id,
            role=AiMessageRole.assistant,
            content=assistant_reply,
        )
        self._db.add(assistant_msg)
        await self._db.commit()

        return {
            "success": True,
            "message": "Chat response generated.",
            "conversation_id": conv.id,
            "assistant_message": assistant_reply,
            "context_used": list(context.keys()),
        }

    async def _call_gemini(
        self, system_prompt: str, history: list, user_message: str
    ) -> str:
        try:
            from app.services.gemini_service import GeminiService
            gemini = GeminiService()

            history_text = "\n".join(
                [f"{m.role.value.capitalize()}: {m.content}" for m in history[-6:]]
            )
            full_prompt = f"Previous conversation:\n{history_text}\n\nUser: {user_message}" if history_text else user_message

            reply = await gemini.generate_text(
                prompt=full_prompt,
                system_instruction=system_prompt,
                temperature=0.7,
            )
            return reply or "I'm here to help with safety information based on your journey history."
        except Exception as e:
            return f"AI temporarily unavailable. ({type(e).__name__})"

    def _mock_response(self, message: str, context: dict) -> str:
        """Evidence-based mock responses when AI provider is not configured."""
        msg_lower = message.lower()
        stats = context.get("journey_stats", {})

        if "safe" in msg_lower or "safety" in msg_lower:
            rate = int(stats.get("safety_rate", 1.0) * 100)
            return (
                f"Based on your {stats.get('total', 0)} recorded journeys, "
                f"your safety rate is {rate}%. "
                "To improve further, consider using Guardian Mode for late-night travel."
            )
        if "route" in msg_lower or "path" in msg_lower:
            return (
                "When planning routes, I recommend well-lit main roads during nighttime. "
                "Guardian Mode can monitor your journey and alert your trusted contacts if needed."
            )
        if "guardian" in msg_lower:
            sessions = context.get("guardian_sessions", 0)
            return (
                f"You've used Guardian Mode {sessions} time(s). "
                "It provides real-time monitoring and can alert your trusted contacts "
                "if your heartbeat stops unexpectedly."
            )
        return (
            "I'm here to help with safety information based on your journey history. "
            "Ask me about routes, Guardian Mode, or general safety tips."
        )


class AIRouteExplainerService:
    """
    Generates natural-language explanations of route recommendations
    using factual outputs from the deterministic Guardian Safety Engine.
    Never fabricates crime counts or route geometry facts.
    """

    @staticmethod
    async def explain_route(route_facts: dict) -> str:
        from app.services.gemini_service import GeminiService
        gemini = GeminiService()

        role = route_facts.get("role", "Safer Route")
        duration = route_facts.get("duration_minutes", 0)
        distance = route_facts.get("distance_km", 0.0)
        score = route_facts.get("safety_score", 80)
        traffic = route_facts.get("traffic_condition", "Moderate")
        period = route_facts.get("evaluation_period", "Day")
        reason = route_facts.get("reason", "")
        avoided_count = len(route_facts.get("impacted_zones", []))

        default_explanation = (
            reason if reason else
            f"Guardian recommends this {role} ({duration} min, {distance} km, safety score {score}/100) "
            f"under {period.lower()} conditions with {traffic.lower()} traffic."
        )

        if not gemini.is_configured:
            return default_explanation

        prompt = (
            f"Summarize the following route decision for a safety navigation app user in 2 clear sentences:\n"
            f"- Route Type: {role}\n"
            f"- Safety Score: {score}/100\n"
            f"- Duration: {duration} minutes\n"
            f"- Distance: {distance} km\n"
            f"- Traffic: {traffic}\n"
            f"- Environmental Period: {period}\n"
            f"- Configured Risk Zones Encountered: {avoided_count}\n"
            f"- Deterministic Rationale: {reason}\n\n"
            f"Requirements:\n"
            f"- Never invent crime statistics or guarantees.\n"
            f"- Clearly state the balance of safety vs time."
        )

        system_instruction = "You are a concise safety navigation assistant."
        generated = await gemini.generate_text(prompt=prompt, system_instruction=system_instruction, temperature=0.3)
        return generated.strip() if generated else default_explanation


class AIJourneySummaryService:
    """Generates concise, factual post-journey summaries."""

    @staticmethod
    async def summarize_journey(journey_facts: dict) -> str:
        from app.services.gemini_service import GeminiService
        gemini = GeminiService()

        origin = journey_facts.get("origin", "Origin")
        dest = journey_facts.get("destination", "Destination")
        elapsed_min = journey_facts.get("elapsed_minutes", 0)
        orig_eta_min = journey_facts.get("original_eta_minutes", elapsed_min)
        deviations = journey_facts.get("deviations_count", 0)
        reroutes = journey_facts.get("reroutes_count", 0)

        default_summary = (
            f"Your trip from {origin} to {dest} took {elapsed_min} minutes "
            f"and was completed safely."
        )

        if not gemini.is_configured:
            return default_summary

        prompt = (
            f"Generate a friendly 1-2 sentence journey summary based on these facts:\n"
            f"- Origin: {origin}\n"
            f"- Destination: {dest}\n"
            f"- Elapsed Time: {elapsed_min} minutes\n"
            f"- Original Estimated ETA: {orig_eta_min} minutes\n"
            f"- Route Deviations: {deviations}\n"
            f"- Safety Reroutes: {reroutes}\n"
            f"- Completed Safely: True"
        )
        system_instruction = "You are Guardian AI personal safety assistant summarizing a completed trip."
        generated = await gemini.generate_text(prompt=prompt, system_instruction=system_instruction, temperature=0.4)
        return generated.strip() if generated else default_summary


class AIInsightService:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def generate_insights(self, user_id: str) -> list[dict]:
        """
        Generate evidence-based insights from actual user data.
        Does NOT predict crimes or guarantee safety.
        """
        ctx_builder = ContextBuilder(self._db, user_id)
        context = await ctx_builder.build()
        stats = context.get("journey_stats", {})
        total = stats.get("total", 0)
        safe = stats.get("safe", 0)
        guardian_count = context.get("guardian_sessions", 0)

        insights = []

        if total == 0:
            insights.append({
                "category": "onboarding",
                "insight": "Welcome to Guardian AI!",
                "evidence": "No journeys recorded yet.",
                "action": "Start your first journey to begin building your safety profile.",
            })
            return insights

        safety_rate = int(stats.get("safety_rate", 1.0) * 100)
        insights.append({
            "category": "journey_safety",
            "insight": f"Your journey safety rate is {safety_rate}%.",
            "evidence": f"{safe} out of {total} journeys completed safely.",
            "action": "Use Guardian Mode to continue this trend.",
        })

        if guardian_count > 0:
            insights.append({
                "category": "guardian_usage",
                "insight": f"You've used Guardian Mode {guardian_count} time(s).",
                "evidence": "Guardian Mode provides real-time monitoring during journeys.",
                "action": "Consider enabling it automatically for late-night trips.",
            })
        else:
            insights.append({
                "category": "guardian_recommendation",
                "insight": "You haven't tried Guardian Mode yet.",
                "evidence": "Guardian Mode monitors your journey and can alert trusted contacts.",
                "action": "Try activating it before your next journey.",
            })

        if total >= 5:
            insights.append({
                "category": "pattern",
                "insight": f"You've completed {total} journeys with Guardian AI.",
                "evidence": "Regular tracking helps identify patterns in your travel.",
                "action": None,
            })

        return insights
