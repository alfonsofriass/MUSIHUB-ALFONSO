"""add author band to opportunities

Revision ID: e4f5a6b7c8d9
Revises: d2e3f4a5b6c7
Create Date: 2026-05-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e4f5a6b7c8d9'
down_revision: Union[str, Sequence[str], None] = 'd2e3f4a5b6c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'opportunities',
        sa.Column('author_band_id', sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        'fk_opportunities_author_band_id_bands',
        'opportunities',
        'bands',
        ['author_band_id'],
        ['id'],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        'fk_opportunities_author_band_id_bands',
        'opportunities',
        type_='foreignkey',
    )
    op.drop_column('opportunities', 'author_band_id')
