from pathlib import Path
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.locations import normalize_location
from app.models import (
    Band,
    BandMember,
    BandStyle,
    Instrument,
    MusicStyle,
    Profile,
    ProfileInstrument,
    ProfileStyle,
    Role,
    User,
    UserRole,
)
from app.uploads import save_uploaded_image

router = APIRouter(prefix="/profile")

PROFILE_PHOTO_UPLOAD_DIR = Path("uploads/profiles")


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
    website_url: str | None
    contact_email: EmailStr | None
    contact_phone: str | None
    instruments: list[ProfileInstrumentResponse]
    styles: list[ProfileStyleResponse]


class ProfileMeResponse(BaseModel):
    exists: bool
    profile: ProfileResponse | None


class ProfilePhotoResponse(BaseModel):
    photo_url: str


class PublicUserResponse(BaseModel):
    id: int
    full_name: str
    role: str


class PublicProfileResponse(BaseModel):
    id: int
    city: str | None
    province: str | None
    bio: str | None
    photo_url: str | None
    website_url: str | None
    instruments: list[ProfileInstrumentResponse]
    styles: list[ProfileStyleResponse]


class PublicProfileBandResponse(BaseModel):
    id: int
    name: str
    role_in_band: str
    city: str | None
    province: str | None
    photo_url: str | None
    styles: list[ProfileStyleResponse]


class PublicProfileDetailResponse(BaseModel):
    user: PublicUserResponse
    profile: PublicProfileResponse | None
    bands: list[PublicProfileBandResponse]


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    city: str | None = Field(default=None, max_length=120)
    province: str | None = Field(default=None, max_length=120)
    bio: str | None = None
    photo_url: str | None = Field(default=None, max_length=500)
    website_url: str | None = Field(default=None, max_length=500)
    contact_email: EmailStr | None = None
    contact_phone: str | None = Field(default=None, max_length=30)
    instrument_ids: list[int] = Field(default_factory=list)
    primary_instrument_id: int | None = None
    style_ids: list[int] = Field(default_factory=list)


def _empty_to_none(value: str | None) -> str | None:
    if value == "":
        return None
    return value


def _normalize_website_url(value: str | None) -> str | None:
    value = _empty_to_none(value)
    if value is None:
        return None

    if "://" not in value:
        value = f"https://{value}"

    parsed_url = urlparse(value)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="website_url must be a valid http or https URL",
        )

    if len(value) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="website_url must be at most 500 characters",
        )

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


def load_profile_instrument_responses(
    profile: Profile,
    db: Session,
) -> list[ProfileInstrumentResponse]:
    instrument_rows = db.execute(
        select(Instrument, ProfileInstrument.is_primary)
        .join(ProfileInstrument, ProfileInstrument.instrument_id == Instrument.id)
        .where(ProfileInstrument.profile_id == profile.id)
        .order_by(ProfileInstrument.is_primary.desc(), Instrument.name)
    ).all()

    return [
        ProfileInstrumentResponse(
            id=instrument.id,
            name=instrument.name,
            is_primary=is_primary,
        )
        for instrument, is_primary in instrument_rows
    ]


def load_profile_style_responses(
    profile: Profile,
    db: Session,
) -> list[ProfileStyleResponse]:
    styles = db.scalars(
        select(MusicStyle)
        .join(ProfileStyle, ProfileStyle.style_id == MusicStyle.id)
        .where(ProfileStyle.profile_id == profile.id)
        .order_by(MusicStyle.name)
    ).all()

    return [
        ProfileStyleResponse(
            id=style.id,
            name=style.name,
        )
        for style in styles
    ]


def _build_profile_me_response(
    profile: Profile,
    db: Session,
) -> ProfileMeResponse:
    return ProfileMeResponse(
        exists=True,
        profile=ProfileResponse(
            id=profile.id,
            city=profile.city,
            province=profile.province,
            bio=profile.bio,
            photo_url=profile.photo_url,
            website_url=profile.website_url,
            contact_email=profile.contact_email,
            contact_phone=profile.contact_phone,
            instruments=load_profile_instrument_responses(profile=profile, db=db),
            styles=load_profile_style_responses(profile=profile, db=db),
        ),
    )


def _build_public_profile_response(
    user: User,
    profile: Profile | None,
    db: Session,
) -> PublicProfileDetailResponse:
    public_profile = None

    if profile is not None:
        public_profile = PublicProfileResponse(
            id=profile.id,
            city=profile.city,
            province=profile.province,
            bio=profile.bio,
            photo_url=profile.photo_url,
            website_url=profile.website_url,
            instruments=load_profile_instrument_responses(profile=profile, db=db),
            styles=load_profile_style_responses(profile=profile, db=db),
        )

    band_rows = db.execute(
        select(Band, BandMember)
        .join(BandMember, BandMember.band_id == Band.id)
        .where(
            BandMember.user_id == user.id,
            BandMember.membership_status == "accepted",
            BandMember.is_visible_in_profile.is_(True),
        )
        .order_by(Band.name)
    ).all()

    bands = []
    for band, member in band_rows:
        band_styles = db.scalars(
            select(MusicStyle)
            .join(BandStyle, BandStyle.style_id == MusicStyle.id)
            .where(BandStyle.band_id == band.id)
            .order_by(MusicStyle.name)
        ).all()

        bands.append(
            PublicProfileBandResponse(
                id=band.id,
                name=band.name,
                role_in_band=member.role_in_band,
                city=band.city,
                province=band.province,
                photo_url=band.photo_url,
                styles=[
                    ProfileStyleResponse(id=style.id, name=style.name)
                    for style in band_styles
                ],
            )
        )

    role = db.scalar(
        select(Role)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(
            UserRole.user_id == user.id,
            UserRole.is_primary.is_(True),
        )
    )
    if role is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User role not found",
        )

    return PublicProfileDetailResponse(
        user=PublicUserResponse(
            id=user.id,
            full_name=user.full_name,
            role=role.code,
        ),
        profile=public_profile,
        bands=bands,
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


@router.post("/me/photo", response_model=ProfilePhotoResponse)
def upload_my_profile_photo(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfilePhotoResponse:
    photo_url = save_uploaded_image(
        file=file,
        upload_dir=PROFILE_PHOTO_UPLOAD_DIR,
        filename_prefix=f"user_{current_user.id}",
    )

    profile = db.scalar(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    if profile is None:
        profile = Profile(user_id=current_user.id)
        db.add(profile)
        db.flush()

    profile.photo_url = photo_url
    db.commit()

    return ProfilePhotoResponse(photo_url=photo_url)


@router.get("/{user_id}", response_model=PublicProfileDetailResponse)
def read_public_profile(
    user_id: int,
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PublicProfileDetailResponse:
    user = db.scalar(
        select(User).where(User.id == user_id)
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    profile = db.scalar(
        select(Profile).where(Profile.user_id == user.id)
    )

    return _build_public_profile_response(
        user=user,
        profile=profile,
        db=db,
    )


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

    city, province = normalize_location(
        db=db,
        city=payload.city,
        province=payload.province,
    )

    profile.city = city
    profile.province = province
    profile.bio = _empty_to_none(payload.bio)
    profile.photo_url = _empty_to_none(payload.photo_url)
    profile.website_url = _normalize_website_url(payload.website_url)
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
