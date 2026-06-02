"""seed base roles

Revision ID: a3b4c5d6e7f8
Revises: f2a3b4c5d6e7
Create Date: 2026-06-02 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3b4c5d6e7f8'
down_revision: Union[str, Sequence[str], None] = 'f2a3b4c5d6e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


BASE_ROLES = [
    ('musico', 'Músico'),
    ('venta', 'Venta'),
    ('sala_bar', 'Sala/bar'),
    ('academia_profesor', 'Academia/Profesor'),
]


def upgrade() -> None:
    """Upgrade schema."""
    connection = op.get_bind()
    for code, name in BASE_ROLES:
        connection.execute(
            sa.text(
                """
                INSERT INTO roles (code, name)
                VALUES (:code, :name)
                ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
                """
            ),
            {"code": code, "name": name},
        )


def downgrade() -> None:
    """Downgrade schema."""
    connection = op.get_bind()
    for code, _name in BASE_ROLES:
        connection.execute(
            sa.text(
                """
                DELETE FROM roles
                WHERE code = :code
                AND NOT EXISTS (
                    SELECT 1
                    FROM user_roles
                    WHERE user_roles.role_id = roles.id
                )
                """
            ),
            {"code": code},
        )
