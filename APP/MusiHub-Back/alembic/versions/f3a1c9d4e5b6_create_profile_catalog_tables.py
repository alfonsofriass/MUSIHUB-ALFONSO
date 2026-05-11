"""create profile catalog tables

Revision ID: f3a1c9d4e5b6
Revises: 8c92cf6527c0
Create Date: 2026-05-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f3a1c9d4e5b6'
down_revision: Union[str, Sequence[str], None] = '8c92cf6527c0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'instruments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_instruments_name'), 'instruments', ['name'], unique=True)

    op.create_table(
        'music_styles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_music_styles_name'), 'music_styles', ['name'], unique=True)

    op.create_table(
        'profiles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('city', sa.String(length=120), nullable=True),
        sa.Column('province', sa.String(length=120), nullable=True),
        sa.Column('bio', sa.Text(), nullable=True),
        sa.Column('photo_url', sa.String(length=500), nullable=True),
        sa.Column('contact_email', sa.String(length=255), nullable=True),
        sa.Column('contact_phone', sa.String(length=30), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )

    op.create_table(
        'profile_instruments',
        sa.Column('profile_id', sa.Integer(), nullable=False),
        sa.Column('instrument_id', sa.Integer(), nullable=False),
        sa.Column('is_primary', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.ForeignKeyConstraint(['instrument_id'], ['instruments.id']),
        sa.ForeignKeyConstraint(['profile_id'], ['profiles.id']),
        sa.PrimaryKeyConstraint('profile_id', 'instrument_id'),
    )

    op.create_table(
        'profile_styles',
        sa.Column('profile_id', sa.Integer(), nullable=False),
        sa.Column('style_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['profile_id'], ['profiles.id']),
        sa.ForeignKeyConstraint(['style_id'], ['music_styles.id']),
        sa.PrimaryKeyConstraint('profile_id', 'style_id'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('profile_styles')
    op.drop_table('profile_instruments')
    op.drop_table('profiles')
    op.drop_index(op.f('ix_music_styles_name'), table_name='music_styles')
    op.drop_table('music_styles')
    op.drop_index(op.f('ix_instruments_name'), table_name='instruments')
    op.drop_table('instruments')
