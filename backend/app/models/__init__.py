"""SQLAlchemy models package — imports all models so Alembic can discover them."""
from app.models.user import User, UserProfile, RefreshToken, UserPreference  # noqa: F401
from app.models.contact import TrustedContact  # noqa: F401
from app.models.journey import Journey, JourneyLocation, JourneyEvent  # noqa: F401
from app.models.guardian import GuardianSession  # noqa: F401
from app.models.notification import Notification, DeviceToken  # noqa: F401
from app.models.safety import SafetyEvent, SafetyAreaScore, PoliceStation, SafetyZone  # noqa: F401
from app.models.emergency import EmergencyEvent, EmergencyNotification  # noqa: F401
from app.models.achievement import Achievement, UserAchievement  # noqa: F401
from app.models.tools import FakeCall, FakeMessage  # noqa: F401
from app.models.ai import AiConversation, AiMessage  # noqa: F401
from app.models.cache import WeatherCache, NearbyServiceCache  # noqa: F401
from app.models.intelligence import (  # noqa: F401
    MotionAnomalyEvent,
    PersonalMotionProfile,
    VoiceDistressEvent,
    RiskAssessment,
    FalsePositiveRecord,
    SafetyCheckIn,
    LocationShareSession,
    SyncRecord,
)
