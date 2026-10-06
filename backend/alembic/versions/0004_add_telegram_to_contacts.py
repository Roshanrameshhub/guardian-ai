"""add telegram to contacts

Revision ID: 0004_add_telegram_to_contacts
Revises: 0003_reconcile_schema
Create Date: 2026-10-06 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0004_add_telegram_to_contacts'
down_revision: Union[str, None] = '0003_reconcile_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('trusted_contacts', sa.Column('telegram_chat_id', sa.String(length=100), nullable=True))
    op.add_column('trusted_contacts', sa.Column('telegram_link_token', sa.String(length=50), nullable=True))
    op.add_column('trusted_contacts', sa.Column('telegram_link_expires', sa.DateTime(timezone=True), nullable=True))
    op.create_index(op.f('ix_trusted_contacts_telegram_link_token'), 'trusted_contacts', ['telegram_link_token'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_trusted_contacts_telegram_link_token'), table_name='trusted_contacts')
    op.drop_column('trusted_contacts', 'telegram_link_expires')
    op.drop_column('trusted_contacts', 'telegram_link_token')
    op.drop_column('trusted_contacts', 'telegram_chat_id')
