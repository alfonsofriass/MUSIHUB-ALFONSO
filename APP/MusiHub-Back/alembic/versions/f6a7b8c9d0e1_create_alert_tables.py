"""create alert tables

Revision ID: f6a7b8c9d0e1
Revises: e4f5a6b7c8d9
Create Date: 2026-05-21 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f6a7b8c9d0e1'
down_revision: Union[str, Sequence[str], None] = 'e4f5a6b7c8d9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'alert_preferences',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('frequency', sa.String(length=20), nullable=False),
        sa.Column('preferred_city', sa.String(length=120), nullable=True),
        sa.Column('preferred_province', sa.String(length=120), nullable=True),
        sa.Column(
            'notifications_enabled',
            sa.Boolean(),
            server_default=sa.text('true'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )

    op.create_table(
        'alert_preference_types',
        sa.Column('alert_preference_id', sa.Integer(), nullable=False),
        sa.Column('opportunity_type_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['alert_preference_id'], ['alert_preferences.id']),
        sa.ForeignKeyConstraint(['opportunity_type_id'], ['opportunity_types.id']),
        sa.PrimaryKeyConstraint('alert_preference_id', 'opportunity_type_id'),
    )

    op.create_table(
        'alerts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('opportunity_id', sa.Integer(), nullable=False),
        sa.Column('score', sa.Integer(), nullable=False),
        sa.Column('reason', sa.Text(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['opportunity_id'], ['opportunities.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'user_id',
            'opportunity_id',
            name='uq_alerts_user_id_opportunity_id',
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('alerts')
    op.drop_table('alert_preference_types')
    op.drop_table('alert_preferences')
