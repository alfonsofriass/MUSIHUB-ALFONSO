"""add alert preference instruments and styles

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-05-28 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c9d0e1f2a3b4'
down_revision: Union[str, Sequence[str], None] = 'b8c9d0e1f2a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'alert_preference_instruments',
        sa.Column('alert_preference_id', sa.Integer(), nullable=False),
        sa.Column('instrument_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ['alert_preference_id'],
            ['alert_preferences.id'],
        ),
        sa.ForeignKeyConstraint(['instrument_id'], ['instruments.id']),
        sa.PrimaryKeyConstraint(
            'alert_preference_id',
            'instrument_id',
        ),
    )
    op.create_table(
        'alert_preference_styles',
        sa.Column('alert_preference_id', sa.Integer(), nullable=False),
        sa.Column('style_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ['alert_preference_id'],
            ['alert_preferences.id'],
        ),
        sa.ForeignKeyConstraint(['style_id'], ['music_styles.id']),
        sa.PrimaryKeyConstraint(
            'alert_preference_id',
            'style_id',
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('alert_preference_styles')
    op.drop_table('alert_preference_instruments')
