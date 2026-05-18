"""create band tables

Revision ID: d2e3f4a5b6c7
Revises: c7d8e9f0a1b2
Create Date: 2026-05-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd2e3f4a5b6c7'
down_revision: Union[str, Sequence[str], None] = 'c7d8e9f0a1b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'bands',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=160), nullable=False),
        sa.Column('bio', sa.Text(), nullable=True),
        sa.Column('city', sa.String(length=120), nullable=True),
        sa.Column('province', sa.String(length=120), nullable=True),
        sa.Column('photo_url', sa.String(length=500), nullable=True),
        sa.Column('created_by_user_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['created_by_user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'band_members',
        sa.Column('band_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('role_in_band', sa.String(length=120), nullable=False),
        sa.Column('membership_status', sa.String(length=20), server_default=sa.text("'pending'"), nullable=False),
        sa.Column('is_visible_in_profile', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['band_id'], ['bands.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('band_id', 'user_id'),
    )

    op.create_table(
        'band_styles',
        sa.Column('band_id', sa.Integer(), nullable=False),
        sa.Column('style_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['band_id'], ['bands.id']),
        sa.ForeignKeyConstraint(['style_id'], ['music_styles.id']),
        sa.PrimaryKeyConstraint('band_id', 'style_id'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('band_styles')
    op.drop_table('band_members')
    op.drop_table('bands')
