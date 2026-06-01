from fastapi import APIRouter

from app.api.routes.alerts import router as alerts_router
from app.api.routes.auth import router as auth_router
from app.api.routes.bands import router as bands_router
from app.api.routes.catalogs import router as catalogs_router
from app.api.routes.contact_requests import router as contact_requests_router
from app.api.routes.device_tokens import router as device_tokens_router
from app.api.routes.favorites import router as favorites_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.opportunities import router as opportunities_router
from app.api.routes.profile import router as profile_router
from app.api.routes.search import router as search_router
from app.api.routes.system import router as system_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(alerts_router, tags=["alerts"])
api_router.include_router(auth_router, tags=["auth"])
api_router.include_router(bands_router, tags=["bands"])
api_router.include_router(catalogs_router, tags=["catalogs"])
api_router.include_router(contact_requests_router, tags=["contact-requests"])
api_router.include_router(device_tokens_router, tags=["device-tokens"])
api_router.include_router(favorites_router, tags=["favorites"])
api_router.include_router(notifications_router, tags=["notifications"])
api_router.include_router(opportunities_router, tags=["opportunities"])
api_router.include_router(profile_router, tags=["profile"])
api_router.include_router(search_router, tags=["search"])
api_router.include_router(system_router, tags=["system"])
