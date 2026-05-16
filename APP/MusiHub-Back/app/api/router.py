from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.catalogs import router as catalogs_router
from app.api.routes.favorites import router as favorites_router
from app.api.routes.opportunities import router as opportunities_router
from app.api.routes.profile import router as profile_router
from app.api.routes.system import router as system_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth_router, tags=["auth"])
api_router.include_router(catalogs_router, tags=["catalogs"])
api_router.include_router(favorites_router, tags=["favorites"])
api_router.include_router(opportunities_router, tags=["opportunities"])
api_router.include_router(profile_router, tags=["profile"])
api_router.include_router(system_router, tags=["system"])
