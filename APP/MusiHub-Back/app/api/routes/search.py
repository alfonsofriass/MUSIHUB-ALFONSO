from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.api.routes.profile import (
    ProfileInstrumentResponse,
    ProfileStyleResponse,
    load_profile_instrument_responses,
    load_profile_style_responses,
)
from app.db import get_db
from app.models import (
    Band,
    BandStyle,
    MusicStyle,
    Profile,
    ProfileInstrument,
    ProfileStyle,
    User,
)

router = APIRouter(prefix="/search")


class ProfileSearchUserResponse(BaseModel):
    id: int
    full_name: str


class ProfileSearchResponse(BaseModel):
    user: ProfileSearchUserResponse
    profile_id: int
    city: str | None
    province: str | None
    bio: str | None
    photo_url: str | None
    instruments: list[ProfileInstrumentResponse]
    styles: list[ProfileStyleResponse]


class ProfileSearchListResponse(BaseModel):
    items: list[ProfileSearchResponse]


class BandSearchStyleResponse(BaseModel):
    id: int
    name: str


class BandSearchResponse(BaseModel):
    id: int
    name: str
    bio: str | None
    city: str | None
    province: str | None
    photo_url: str | None
    styles: list[BandSearchStyleResponse]


class BandSearchListResponse(BaseModel):
    items: list[BandSearchResponse]


def _build_profile_search_response(
    profile: Profile,
    user: User,
    db: Session,
) -> ProfileSearchResponse:
    return ProfileSearchResponse(
        user=ProfileSearchUserResponse(
            id=user.id,
            full_name=user.full_name,
        ),
        profile_id=profile.id,
        city=profile.city,
        province=profile.province,
        bio=profile.bio,
        photo_url=profile.photo_url,
        instruments=load_profile_instrument_responses(profile=profile, db=db),
        styles=load_profile_style_responses(profile=profile, db=db),
    )


def _build_band_search_response(band: Band, db: Session) -> BandSearchResponse:
    styles = db.scalars(
        select(MusicStyle)
        .join(BandStyle, BandStyle.style_id == MusicStyle.id)
        .where(BandStyle.band_id == band.id)
        .order_by(MusicStyle.name)
    ).all()

    return BandSearchResponse(
        id=band.id,
        name=band.name,
        bio=band.bio,
        city=band.city,
        province=band.province,
        photo_url=band.photo_url,
        styles=[
            BandSearchStyleResponse(
                id=style.id,
                name=style.name,
            )
            for style in styles
        ],
    )


@router.get("/profiles", response_model=ProfileSearchListResponse)
def search_profiles(
    q: str | None = Query(default=None, min_length=1, max_length=120),
    city: str | None = Query(default=None, min_length=1, max_length=120),
    province: str | None = Query(default=None, min_length=1, max_length=120),
    instrument_id: int | None = Query(default=None, gt=0),
    style_id: int | None = Query(default=None, gt=0),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileSearchListResponse:
    query = select(Profile, User).join(User, User.id == Profile.user_id)

    if q is not None:
        search_text = f"%{q.lower()}%"
        query = query.where(
            func.lower(User.full_name).like(search_text)
            | func.lower(Profile.bio).like(search_text)
            | func.lower(Profile.city).like(search_text)
            | func.lower(Profile.province).like(search_text)
        )

    if city is not None:
        query = query.where(func.lower(Profile.city) == city.lower())

    if province is not None:
        query = query.where(func.lower(Profile.province) == province.lower())

    if instrument_id is not None:
        query = query.join(
            ProfileInstrument,
            ProfileInstrument.profile_id == Profile.id,
        ).where(ProfileInstrument.instrument_id == instrument_id)

    if style_id is not None:
        query = query.join(
            ProfileStyle,
            ProfileStyle.profile_id == Profile.id,
        ).where(ProfileStyle.style_id == style_id)

    profile_rows = db.execute(
        query.order_by(User.full_name)
    ).all()

    return ProfileSearchListResponse(
        items=[
            _build_profile_search_response(profile=profile, user=user, db=db)
            for profile, user in profile_rows
        ]
    )


@router.get("/bands", response_model=BandSearchListResponse)
def search_bands(
    q: str | None = Query(default=None, min_length=1, max_length=120),
    city: str | None = Query(default=None, min_length=1, max_length=120),
    province: str | None = Query(default=None, min_length=1, max_length=120),
    style_id: int | None = Query(default=None, gt=0),
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandSearchListResponse:
    query = select(Band)

    if q is not None:
        search_text = f"%{q.lower()}%"
        query = query.where(
            func.lower(Band.name).like(search_text)
            | func.lower(Band.bio).like(search_text)
            | func.lower(Band.city).like(search_text)
            | func.lower(Band.province).like(search_text)
        )

    if city is not None:
        query = query.where(func.lower(Band.city) == city.lower())

    if province is not None:
        query = query.where(func.lower(Band.province) == province.lower())

    if style_id is not None:
        query = query.join(
            BandStyle,
            BandStyle.band_id == Band.id,
        ).where(BandStyle.style_id == style_id)

    bands = db.scalars(
        query.order_by(Band.name)
    ).all()

    return BandSearchListResponse(
        items=[
            _build_band_search_response(band=band, db=db)
            for band in bands
        ]
    )
