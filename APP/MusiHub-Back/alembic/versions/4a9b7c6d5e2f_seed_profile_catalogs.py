"""seed profile catalogs

Revision ID: 4a9b7c6d5e2f
Revises: f3a1c9d4e5b6
Create Date: 2026-05-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4a9b7c6d5e2f'
down_revision: Union[str, Sequence[str], None] = 'f3a1c9d4e5b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


instrument_table = sa.table(
    'instruments',
    sa.column('name', sa.String),
)

music_style_table = sa.table(
    'music_styles',
    sa.column('name', sa.String),
)

INSTRUMENT_NAMES = [
    'Voz',
    'Guitarra',
    'Bajo',
    'Batería',
    'Piano',
    'Teclado',
    'Violín',
    'Saxofón',
    'Trompeta',
    'Flauta',
    'Percusión',
    'DJ',
]

MUSIC_STYLE_NAMES = [
    'Rock',
    'Pop',
    'Jazz',
    'Blues',
    'Flamenco',
    'Clásica',
    'Metal',
    'Indie',
    'Electrónica',
    'Hip hop',
    'Reggae',
    'Funk',
]


def upgrade() -> None:
    """Upgrade schema."""
    op.bulk_insert(
        instrument_table,
        [{'name': name} for name in INSTRUMENT_NAMES],
    )
    op.bulk_insert(
        music_style_table,
        [{'name': name} for name in MUSIC_STYLE_NAMES],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        sa.delete(instrument_table).where(
            instrument_table.c.name.in_(INSTRUMENT_NAMES)
        )
    )
    op.execute(
        sa.delete(music_style_table).where(
            music_style_table.c.name.in_(MUSIC_STYLE_NAMES)
        )
    )
