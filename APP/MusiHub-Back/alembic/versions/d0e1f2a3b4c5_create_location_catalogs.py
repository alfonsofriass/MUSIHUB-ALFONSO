"""create location catalogs

Revision ID: d0e1f2a3b4c5
Revises: c9d0e1f2a3b4
Create Date: 2026-05-29 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd0e1f2a3b4c5'
down_revision: Union[str, Sequence[str], None] = 'c9d0e1f2a3b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


LOCATION_SEED = {
    "Almería": ["Almería", "El Ejido", "Roquetas de Mar"],
    "Cádiz": ["Algeciras", "Cádiz", "Jerez de la Frontera", "San Fernando"],
    "Córdoba": ["Córdoba", "Lucena", "Puente Genil"],
    "Granada": [
        "Albolote",
        "Armilla",
        "Baza",
        "Granada",
        "Guadix",
        "Loja",
        "Maracena",
        "Motril",
    ],
    "Huelva": ["Huelva", "Isla Cristina", "Lepe"],
    "Jaén": ["Jaén", "Linares", "Úbeda"],
    "Málaga": ["Fuengirola", "Málaga", "Marbella", "Torremolinos", "Vélez-Málaga"],
    "Sevilla": ["Alcalá de Guadaíra", "Dos Hermanas", "Sevilla", "Utrera"],
}


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'provinces',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_provinces_name'), 'provinces', ['name'], unique=True)
    op.create_table(
        'cities',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('province_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.ForeignKeyConstraint(['province_id'], ['provinces.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('province_id', 'name', name='uq_cities_province_id_name'),
    )

    province_table = sa.table(
        'provinces',
        sa.column('id', sa.Integer),
        sa.column('name', sa.String),
    )
    city_table = sa.table(
        'cities',
        sa.column('province_id', sa.Integer),
        sa.column('name', sa.String),
    )
    connection = op.get_bind()

    for province_name, city_names in LOCATION_SEED.items():
        province_id = connection.execute(
            sa.insert(province_table)
            .values(name=province_name)
            .returning(province_table.c.id)
        ).scalar_one()
        connection.execute(
            sa.insert(city_table),
            [
                {"province_id": province_id, "name": city_name}
                for city_name in city_names
            ],
        )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('cities')
    op.drop_index(op.f('ix_provinces_name'), table_name='provinces')
    op.drop_table('provinces')
