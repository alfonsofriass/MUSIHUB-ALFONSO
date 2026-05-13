"""create opportunity tables

Revision ID: b1c2d3e4f5a6
Revises: 4a9b7c6d5e2f
Create Date: 2026-05-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b1c2d3e4f5a6'
down_revision: Union[str, Sequence[str], None] = '4a9b7c6d5e2f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


opportunity_type_table = sa.table(
    'opportunity_types',
    sa.column('code', sa.String),
    sa.column('name', sa.String),
)

OPPORTUNITY_TYPES = [
    {'code': 'clases', 'name': 'Clases'},
    {'code': 'bolos_sustituciones', 'name': 'Bolos o sustituciones'},
    {'code': 'busqueda_miembros', 'name': 'Búsqueda de miembros'},
    {'code': 'eventos', 'name': 'Eventos'},
    {'code': 'compraventa', 'name': 'Compraventa'},
]


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'opportunity_types',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('code', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_opportunity_types_code'),
        'opportunity_types',
        ['code'],
        unique=True,
    )

    op.create_table(
        'opportunities',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('type_id', sa.Integer(), nullable=False),
        sa.Column('author_user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=160), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('city', sa.String(length=120), nullable=False),
        sa.Column('province', sa.String(length=120), nullable=False),
        sa.Column('event_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('price_amount', sa.Numeric(10, 2), nullable=True),
        sa.Column('contact_method', sa.String(length=30), nullable=False),
        sa.Column('contact_value', sa.String(length=255), nullable=False),
        sa.Column('status', sa.String(length=20), server_default=sa.text("'active'"), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['author_user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['type_id'], ['opportunity_types.id']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'opportunity_styles',
        sa.Column('opportunity_id', sa.Integer(), nullable=False),
        sa.Column('style_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['opportunity_id'], ['opportunities.id']),
        sa.ForeignKeyConstraint(['style_id'], ['music_styles.id']),
        sa.PrimaryKeyConstraint('opportunity_id', 'style_id'),
    )

    op.create_table(
        'opportunity_instruments',
        sa.Column('opportunity_id', sa.Integer(), nullable=False),
        sa.Column('instrument_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['instrument_id'], ['instruments.id']),
        sa.ForeignKeyConstraint(['opportunity_id'], ['opportunities.id']),
        sa.PrimaryKeyConstraint('opportunity_id', 'instrument_id'),
    )

    op.bulk_insert(opportunity_type_table, OPPORTUNITY_TYPES)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('opportunity_instruments')
    op.drop_table('opportunity_styles')
    op.drop_table('opportunities')
    op.drop_index(op.f('ix_opportunity_types_code'), table_name='opportunity_types')
    op.drop_table('opportunity_types')
