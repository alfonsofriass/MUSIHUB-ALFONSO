from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.models import (
    Instrument,
    MusicStyle,
    Profile,
    ProfileInstrument,
    ProfileStyle,
    User,
)

router = APIRouter(prefix="/profile")


class ProfileInstrumentResponse(BaseModel):
    id: int
    name: str
    is_primary: bool


class ProfileStyleResponse(BaseModel):
    id: int
    name: str


class ProfileResponse(BaseModel):
    id: int
    city: str | None
    province: str | None
    bio: str | None
    photo_url: str | None
    contact_email: EmailStr | None
    contact_phone: str | None
    instruments: list[ProfileInstrumentResponse]
    styles: list[ProfileStyleResponse]


class ProfileMeResponse(BaseModel):
    exists: bool
    profile: ProfileResponse | None


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    city: str | None = Field(default=None, max_length=120)
    province: str | None = Field(default=None, max_length=120)
    bio: str | None = None
    photo_url: str | None = Field(default=None, max_length=500)
    contact_email: EmailStr | None = None
    contact_phone: str | None = Field(default=None, max_length=30)
    instrument_ids: list[int] = Field(default_factory=list)
    primary_instrument_id: int | None = None
    style_ids: list[int] = Field(default_factory=list)


def _empty_to_none(value: str | None) -> str | None:
    if value == "":
        return None
    return value


def _validate_unique_positive_ids(field_name: str, ids: list[int]) -> None:
    if any(item_id <= 0 for item_id in ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} must contain positive ids",
        )

    if len(ids) != len(set(ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} must not contain duplicate ids",
        )


def _build_profile_me_response(
    profile: Profile,
    db: Session,
) -> ProfileMeResponse:
    instrument_rows = db.execute(
        select(Instrument, ProfileInstrument.is_primary)
        .join(ProfileInstrument, ProfileInstrument.instrument_id == Instrument.id)
        .where(ProfileInstrument.profile_id == profile.id)
        .order_by(ProfileInstrument.is_primary.desc(), Instrument.name)
    ).all()

    styles = db.scalars(
        select(MusicStyle)
        .join(ProfileStyle, ProfileStyle.style_id == MusicStyle.id)
        .where(ProfileStyle.profile_id == profile.id)
        .order_by(MusicStyle.name)
    ).all()

    return ProfileMeResponse(
        exists=True,
        profile=ProfileResponse(
            id=profile.id,
            city=profile.city,
            province=profile.province,
            bio=profile.bio,
            photo_url=profile.photo_url,
            contact_email=profile.contact_email,
            contact_phone=profile.contact_phone,
            instruments=[
                ProfileInstrumentResponse(
                    id=instrument.id,
                    name=instrument.name,
                    is_primary=is_primary,
                )
                for instrument, is_primary in instrument_rows
            ],
            styles=[
                ProfileStyleResponse(
                    id=style.id,
                    name=style.name,
                )
                for style in styles
            ],
        ),
    )


@router.get("/me", response_model=ProfileMeResponse)
def read_my_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileMeResponse:
    profile = db.scalar(
        select(Profile).where(Profile.user_id == current_user.id)
    )

    if profile is None:
        return ProfileMeResponse(exists=False, profile=None)

    return _build_profile_me_response(profile=profile, db=db)


@router.put("/me", response_model=ProfileMeResponse)
def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileMeResponse:
    _validate_unique_positive_ids("instrument_ids", payload.instrument_ids)
    _validate_unique_positive_ids("style_ids", payload.style_ids)

    if (
        payload.primary_instrument_id is not None
        and payload.primary_instrument_id not in payload.instrument_ids
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="primary_instrument_id must be included in instrument_ids",
        )

    instruments = []
    if payload.instrument_ids:
        instruments = db.scalars(
            select(Instrument).where(Instrument.id.in_(payload.instrument_ids))
        ).all()
        found_instrument_ids = {instrument.id for instrument in instruments}
        missing_instrument_ids = sorted(
            set(payload.instrument_ids) - found_instrument_ids
        )
        if missing_instrument_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "message": "Invalid instrument_ids",
                    "ids": missing_instrument_ids,
                },
            )

    styles = []
    if payload.style_ids:
        styles = db.scalars(
            select(MusicStyle).where(MusicStyle.id.in_(payload.style_ids))
        ).all()
        found_style_ids = {style.id for style in styles}
        missing_style_ids = sorted(set(payload.style_ids) - found_style_ids)
        if missing_style_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "message": "Invalid style_ids",
                    "ids": missing_style_ids,
                },
            )

    profile = db.scalar(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    if profile is None:
        profile = Profile(user_id=current_user.id)
        db.add(profile)
        db.flush()

    profile.city = _empty_to_none(payload.city)
    profile.province = _empty_to_none(payload.province)
    profile.bio = _empty_to_none(payload.bio)
    profile.photo_url = _empty_to_none(payload.photo_url)
    profile.contact_email = (
        str(payload.contact_email) if payload.contact_email is not None else None
    )
    profile.contact_phone = _empty_to_none(payload.contact_phone)

    db.execute(
        delete(ProfileInstrument).where(ProfileInstrument.profile_id == profile.id)
    )
    db.execute(
        delete(ProfileStyle).where(ProfileStyle.profile_id == profile.id)
    )

    instrument_ids = {instrument.id for instrument in instruments}
    for instrument_id in payload.instrument_ids:
        if instrument_id not in instrument_ids:
            continue
        db.add(
            ProfileInstrument(
                profile_id=profile.id,
                instrument_id=instrument_id,
                is_primary=instrument_id == payload.primary_instrument_id,
            )
        )

    style_ids = {style.id for style in styles}
    for style_id in payload.style_ids:
        if style_id not in style_ids:
            continue
        db.add(
            ProfileStyle(
                profile_id=profile.id,
                style_id=style_id,
            )
        )

    db.commit()

    return _build_profile_me_response(profile=profile, db=db)
