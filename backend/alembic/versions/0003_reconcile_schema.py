"""reconcile schema

Revision ID: 0003_reconcile_schema
Revises: 0002_safety_police_tables
Create Date: 2026-08-20 02:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from app.core.database import Base
import app.models  # noqa: F401

# revision identifiers, used by Alembic.
revision: str = '0003_reconcile_schema'
down_revision: Union[str, None] = '0002_safety_police_tables'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Safely create any missing tables (idempotent IF NOT EXISTS)
    # This ensures production DB has all tables like guardian_sessions, police_stations
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)

def downgrade() -> None:
    pass
