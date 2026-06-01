from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.locations import normalize_location
from app.models import Band, BandMember, BandStyle, MusicStyle, Opportunity, User
from app.uploads import save_uploaded_image

router = APIRouter(prefix="/bands")

BAND_PHOTO_UPLOAD_DIR = Path("uploads/bands")


class BandStyleResponse(BaseModel):
    id: int
    name: str


class BandMemberResponse(BaseModel):
    user_id: int
    full_name: str
    role_in_band: str
    membership_status: str
    is_visible_in_profile: bool
    joined_at: datetime | None


class BandResponse(BaseModel):
    id: int
    name: str
    bio: str | None
    city: str | None
    province: str | None
    photo_url: str | None
    created_by_user_id: int
    created_at: datetime
    styles: list[BandStyleResponse]
    members: list[BandMemberResponse]


class BandListResponse(BaseModel):
    items: list[BandResponse]


class BandCreateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    name: str = Field(min_length=1, max_length=160)
    bio: str | None = None
    city: str | None = Field(default=None, min_length=1, max_length=120)
    province: str | None = Field(default=None, min_length=1, max_length=120)
    photo_url: str | None = Field(default=None, min_length=1, max_length=500)
    role_in_band: str = Field(min_length=1, max_length=120)
    is_visible_in_profile: bool = True
    style_ids: list[int] = Field(default_factory=list)


class BandUpdateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    name: str = Field(min_length=1, max_length=160)
    bio: str | None = None
    city: str | None = Field(default=None, min_length=1, max_length=120)
    province: str | None = Field(default=None, min_length=1, max_length=120)
    photo_url: str | None = Field(default=None, min_length=1, max_length=500)
    style_ids: list[int] = Field(default_factory=list)


class BandMemberCreateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    user_id: int = Field(gt=0)
    role_in_band: str = Field(min_length=1, max_length=120)
    is_visible_in_profile: bool = True


class BandVisibilityUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    is_visible_in_profile: bool


class BandVisibilityResponse(BaseModel):
    band_id: int
    user_id: int
    is_visible_in_profile: bool


class BandPhotoResponse(BaseModel):
    photo_url: str


class BandDeleteResponse(BaseModel):
    message: str


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


def _load_styles(db: Session, style_ids: list[int]) -> list[MusicStyle]:
    if not style_ids:
        return []

    styles = db.scalars(
        select(MusicStyle).where(MusicStyle.id.in_(style_ids))
    ).all()
    found_ids = {style.id for style in styles}
    missing_ids = sorted(set(style_ids) - found_ids)

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Invalid style_ids",
                "ids": missing_ids,
            },
        )

    return styles


def _get_band_or_404(db: Session, band_id: int) -> Band:
    band = db.scalar(
        select(Band).where(Band.id == band_id)
    )

    if band is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Band not found",
        )

    return band


def _require_band_creator(band: Band, current_user: User) -> None:
    if band.created_by_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the band creator can update this band",
        )


def _build_band_response(band: Band, db: Session) -> BandResponse:
    styles = db.scalars(
        select(MusicStyle)
        .join(BandStyle, BandStyle.style_id == MusicStyle.id)
        .where(BandStyle.band_id == band.id)
        .order_by(MusicStyle.name)
    ).all()

    members = db.execute(
        select(BandMember, User)
        .join(User, User.id == BandMember.user_id)
        .where(BandMember.band_id == band.id)
        .order_by(User.full_name)
    ).all()

    return BandResponse(
        id=band.id,
        name=band.name,
        bio=band.bio,
        city=band.city,
        province=band.province,
        photo_url=band.photo_url,
        created_by_user_id=band.created_by_user_id,
        created_at=band.created_at,
        styles=[
            BandStyleResponse(id=style.id, name=style.name)
            for style in styles
        ],
        members=[
            BandMemberResponse(
                user_id=member.user_id,
                full_name=user.full_name,
                role_in_band=member.role_in_band,
                membership_status=member.membership_status,
                is_visible_in_profile=member.is_visible_in_profile,
                joined_at=member.joined_at,
            )
            for member, user in members
        ],
    )


@router.post("", response_model=BandResponse, status_code=status.HTTP_201_CREATED)
def create_band(
    payload: BandCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandResponse:
    _validate_unique_positive_ids("style_ids", payload.style_ids)
    _load_styles(db=db, style_ids=payload.style_ids)
    city, province = normalize_location(
        db=db,
        city=payload.city,
        province=payload.province,
    )

    band = Band(
        name=payload.name,
        bio=payload.bio,
        city=city,
        province=province,
        photo_url=payload.photo_url,
        created_by_user_id=current_user.id,
    )
    db.add(band)
    db.flush()

    db.add(
        BandMember(
            band_id=band.id,
            user_id=current_user.id,
            role_in_band=payload.role_in_band,
            membership_status="accepted",
            is_visible_in_profile=payload.is_visible_in_profile,
            joined_at=datetime.now(timezone.utc),
        )
    )

    for style_id in payload.style_ids:
        db.add(
            BandStyle(
                band_id=band.id,
                style_id=style_id,
            )
        )

    db.commit()

    return _build_band_response(band=band, db=db)


@router.get("/me", response_model=BandListResponse)
def list_my_bands(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandListResponse:
    bands = db.scalars(
        select(Band)
        .join(BandMember, BandMember.band_id == Band.id)
        .where(
            BandMember.user_id == current_user.id,
            BandMember.membership_status == "accepted",
        )
        .order_by(Band.created_at.desc())
    ).all()

    return BandListResponse(
        items=[
            _build_band_response(band=band, db=db)
            for band in bands
        ]
    )


@router.get("/{band_id}", response_model=BandResponse)
def read_band(
    band_id: int,
    _current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandResponse:
    band = _get_band_or_404(db=db, band_id=band_id)

    return _build_band_response(band=band, db=db)


@router.post("/{band_id}/photo", response_model=BandPhotoResponse)
def upload_band_photo(
    band_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandPhotoResponse:
    band = _get_band_or_404(db=db, band_id=band_id)
    _require_band_creator(band=band, current_user=current_user)

    photo_url = save_uploaded_image(
        file=file,
        upload_dir=BAND_PHOTO_UPLOAD_DIR,
        filename_prefix=f"band_{band.id}",
    )
    band.photo_url = photo_url
    db.commit()

    return BandPhotoResponse(photo_url=photo_url)


@router.patch("/{band_id}/me/visibility", response_model=BandVisibilityResponse)
def update_my_band_visibility(
    band_id: int,
    payload: BandVisibilityUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandVisibilityResponse:
    band = _get_band_or_404(db=db, band_id=band_id)

    member = db.scalar(
        select(BandMember).where(
            BandMember.band_id == band.id,
            BandMember.user_id == current_user.id,
            BandMember.membership_status == "accepted",
        )
    )
    if member is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not an accepted member of this band",
        )

    member.is_visible_in_profile = payload.is_visible_in_profile
    db.commit()

    return BandVisibilityResponse(
        band_id=band.id,
        user_id=current_user.id,
        is_visible_in_profile=member.is_visible_in_profile,
    )


@router.put("/{band_id}", response_model=BandResponse)
def update_band(
    band_id: int,
    payload: BandUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandResponse:
    band = _get_band_or_404(db=db, band_id=band_id)
    _require_band_creator(band=band, current_user=current_user)

    _validate_unique_positive_ids("style_ids", payload.style_ids)
    _load_styles(db=db, style_ids=payload.style_ids)
    city, province = normalize_location(
        db=db,
        city=payload.city,
        province=payload.province,
    )

    band.name = payload.name
    band.bio = payload.bio
    band.city = city
    band.province = province
    band.photo_url = payload.photo_url

    db.execute(
        delete(BandStyle).where(BandStyle.band_id == band.id)
    )
    for style_id in payload.style_ids:
        db.add(
            BandStyle(
                band_id=band.id,
                style_id=style_id,
            )
        )

    db.commit()

    return _build_band_response(band=band, db=db)


@router.post(
    "/{band_id}/members",
    response_model=BandResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_band_member(
    band_id: int,
    payload: BandMemberCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandResponse:
    band = _get_band_or_404(db=db, band_id=band_id)
    _require_band_creator(band=band, current_user=current_user)

    user = db.scalar(
        select(User).where(User.id == payload.user_id)
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    existing_member = db.scalar(
        select(BandMember).where(
            BandMember.band_id == band.id,
            BandMember.user_id == payload.user_id,
        )
    )
    if existing_member is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is already a member of this band",
        )

    db.add(
        BandMember(
            band_id=band.id,
            user_id=payload.user_id,
            role_in_band=payload.role_in_band,
            membership_status="accepted",
            is_visible_in_profile=payload.is_visible_in_profile,
            joined_at=datetime.now(timezone.utc),
        )
    )
    db.commit()

    return _build_band_response(band=band, db=db)


@router.delete("/{band_id}", response_model=BandDeleteResponse)
def delete_band(
    band_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandDeleteResponse:
    band = _get_band_or_404(db=db, band_id=band_id)
    _require_band_creator(band=band, current_user=current_user)

    other_member = db.scalar(
        select(BandMember).where(
            BandMember.band_id == band.id,
            BandMember.user_id != current_user.id,
        )
    )
    if other_member is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Band must not have other members before deletion",
        )

    db.execute(
        update(Opportunity)
        .where(Opportunity.author_band_id == band.id)
        .values(author_band_id=None)
    )
    db.delete(band)
    db.commit()

    return BandDeleteResponse(message="Band deleted")


@router.delete("/{band_id}/members/{user_id}", response_model=BandResponse)
def remove_band_member(
    band_id: int,
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BandResponse:
    band = _get_band_or_404(db=db, band_id=band_id)
    _require_band_creator(band=band, current_user=current_user)

    if user_id == band.created_by_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Band creator cannot be removed from the band",
        )

    member = db.scalar(
        select(BandMember).where(
            BandMember.band_id == band.id,
            BandMember.user_id == user_id,
        )
    )
    if member is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Band member not found",
        )

    db.delete(member)
    db.commit()

    return _build_band_response(band=band, db=db)
