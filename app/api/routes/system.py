from fastapi import APIRouter

from app.roles import RoleCode

router = APIRouter()

@router.get("/health")
def read_health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/roles")
def list_roles() -> dict[str, list[str]]:
    return {"items": [role.value for role in RoleCode]}
