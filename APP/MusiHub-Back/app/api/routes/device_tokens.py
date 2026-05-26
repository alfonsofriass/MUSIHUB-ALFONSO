from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.models import DeviceToken, User

router = APIRouter()

DEVICE_TOKEN_PLATFORMS = {"android", "ios", "web"}


class DeviceTokenRegisterRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    token: str = Field(min_length=1, max_length=500)
    platform: str = Field(min_length=1, max_length=20)


class DeviceTokenRegisterResponse(BaseModel):
    id: int
    platform: str
    message: str


@router.post("/device-tokens", response_model=DeviceTokenRegisterResponse)
def register_device_token(
    payload: DeviceTokenRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeviceTokenRegisterResponse:
    platform = payload.platform.lower()
    if platform not in DEVICE_TOKEN_PLATFORMS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid platform",
        )

    now = datetime.now(timezone.utc)
    device_token = db.scalar(
        select(DeviceToken).where(DeviceToken.token == payload.token)
    )

    if device_token is None:
        device_token = DeviceToken(
            user_id=current_user.id,
            token=payload.token,
            platform=platform,
            last_seen_at=now,
        )
        db.add(device_token)
    else:
        device_token.user_id = current_user.id
        device_token.platform = platform
        device_token.last_seen_at = now

    db.commit()
    db.refresh(device_token)

    return DeviceTokenRegisterResponse(
        id=device_token.id,
        platform=device_token.platform,
        message="Device token registered",
    )
