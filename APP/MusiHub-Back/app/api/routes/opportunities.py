from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.models import (
    Instrument,
    MusicStyle,
    Opportunity,
    OpportunityInstrument,
    OpportunityStyle,
    OpportunityType,
    User,
)

router = APIRouter(prefix="/opportunities")

CONTACT_METHODS = {"whatsapp", "email", "phone", "other"}
EVENT_DATE_REQUIRED_TYPES = {"bolos_sustituciones", "eventos"}
INSTRUMENT_REQUIRED_TYPES = {"bolos_sustituciones", "busqueda_miembros"}
PRICE_REQUIRED_TYPES = {"compraventa"}


class CatalogItemResponse(BaseModel):
    id: int
    name: str


class OpportunityTypeResponse(BaseModel):
    id: int
    code: str
    name: str


class OpportunityCreateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    type_id: int
    title: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1)
    city: str = Field(min_length=1, max_length=120)
    province: str = Field(min_length=1, max_length=120)
    event_date: datetime | None = None
    price_amount: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    contact_method: str = Field(min_length=1, max_length=30)
    contact_value: str = Field(min_length=1, max_length=255)
    instrument_ids: list[int] = Field(default_factory=list)
    style_ids: list[int] = Field(default_factory=list)


class OpportunityUpdateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    title: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, min_length=1)
    city: str | None = Field(default=None, min_length=1, max_length=120)
    province: str | None = Field(default=None, min_length=1, max_length=120)
    event_date: datetime | None = None
    price_amount: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    contact_method: str | None = Field(default=None, min_length=1, max_length=30)
    contact_value: str | None = Field(default=None, min_length=1, max_length=255)
    instrument_ids: list[int] | None = None
    style_ids: list[int] | None = None


class OpportunityResponse(BaseModel):
    id: int
    type: OpportunityTypeResponse
    author_user_id: int
    title: str
    description: str
    city: str
    province: str
    event_date: datetime | None
    price_amount: Decimal | None
    contact_method: str
    contact_value: str
    status: str
    created_at: datetime
    updated_at: datetime
    expires_at: datetime | None
    instruments: list[CatalogItemResponse]
    styles: list[CatalogItemResponse]


class OpportunityListResponse(BaseModel):
    items: list[OpportunityResponse]


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


def _load_instruments(db: Session, instrument_ids: list[int]) -> list[Instrument]:
    if not instrument_ids:
        return []

    instruments = db.scalars(
        select(Instrument).where(Instrument.id.in_(instrument_ids))
    ).all()
    found_ids = {instrument.id for instrument in instruments}
    missing_ids = sorted(set(instrument_ids) - found_ids)

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Invalid instrument_ids",
                "ids": missing_ids,
            },
        )

    return instruments


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


def _build_opportunity_response(
    opportunity: Opportunity,
    db: Session,
) -> OpportunityResponse:
    instruments = db.scalars(
        select(Instrument)
        .join(OpportunityInstrument, OpportunityInstrument.instrument_id == Instrument.id)
        .where(OpportunityInstrument.opportunity_id == opportunity.id)
        .order_by(Instrument.name)
    ).all()

    styles = db.scalars(
        select(MusicStyle)
        .join(OpportunityStyle, OpportunityStyle.style_id == MusicStyle.id)
        .where(OpportunityStyle.opportunity_id == opportunity.id)
        .order_by(MusicStyle.name)
    ).all()

    return OpportunityResponse(
        id=opportunity.id,
        type=OpportunityTypeResponse(
            id=opportunity.type.id,
            code=opportunity.type.code,
            name=opportunity.type.name,
        ),
        author_user_id=opportunity.author_user_id,
        title=opportunity.title,
        description=opportunity.description,
        city=opportunity.city,
        province=opportunity.province,
        event_date=opportunity.event_date,
        price_amount=opportunity.price_amount,
        contact_method=opportunity.contact_method,
        contact_value=opportunity.contact_value,
        status=opportunity.status,
        created_at=opportunity.created_at,
        updated_at=opportunity.updated_at,
        expires_at=opportunity.expires_at,
        instruments=[
            CatalogItemResponse(id=instrument.id, name=instrument.name)
            for instrument in instruments
        ],
        styles=[
            CatalogItemResponse(id=style.id, name=style.name)
            for style in styles
        ],
    )


@router.post("", response_model=OpportunityResponse, status_code=status.HTTP_201_CREATED)
def create_opportunity(
    payload: OpportunityCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OpportunityResponse:
    _validate_unique_positive_ids("instrument_ids", payload.instrument_ids)
    _validate_unique_positive_ids("style_ids", payload.style_ids)

    opportunity_type = db.scalar(
        select(OpportunityType).where(OpportunityType.id == payload.type_id)
    )
    if opportunity_type is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid type_id",
        )

    contact_method = payload.contact_method.lower()
    if contact_method not in CONTACT_METHODS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid contact_method",
        )

    if opportunity_type.code in EVENT_DATE_REQUIRED_TYPES and payload.event_date is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="event_date is required for this opportunity type",
        )

    if opportunity_type.code in INSTRUMENT_REQUIRED_TYPES and not payload.instrument_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one instrument is required for this opportunity type",
        )

    if opportunity_type.code in PRICE_REQUIRED_TYPES and payload.price_amount is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="price_amount is required for this opportunity type",
        )

    instruments = _load_instruments(db=db, instrument_ids=payload.instrument_ids)
    styles = _load_styles(db=db, style_ids=payload.style_ids)

    opportunity = Opportunity(
        type_id=opportunity_type.id,
        author_user_id=current_user.id,
        title=payload.title,
        description=payload.description,
        city=payload.city,
        province=payload.province,
        event_date=payload.event_date,
        price_amount=payload.price_amount,
        contact_method=contact_method,
        contact_value=payload.contact_value,
    )
    db.add(opportunity)
    db.flush()

    valid_instrument_ids = {instrument.id for instrument in instruments}
    for instrument_id in payload.instrument_ids:
        if instrument_id not in valid_instrument_ids:
            continue
        db.add(
            OpportunityInstrument(
                opportunity_id=opportunity.id,
                instrument_id=instrument_id,
            )
        )

    valid_style_ids = {style.id for style in styles}
    for style_id in payload.style_ids:
        if style_id not in valid_style_ids:
            continue
        db.add(
            OpportunityStyle(
                opportunity_id=opportunity.id,
                style_id=style_id,
            )
        )

    db.commit()

    return _build_opportunity_response(opportunity=opportunity, db=db)


@router.get("", response_model=OpportunityListResponse)
def list_opportunities(db: Session = Depends(get_db)) -> OpportunityListResponse:
    opportunities = db.scalars(
        select(Opportunity)
        .where(Opportunity.status == "active")
        .order_by(Opportunity.created_at.desc())
    ).all()

    return OpportunityListResponse(
        items=[
            _build_opportunity_response(opportunity=opportunity, db=db)
            for opportunity in opportunities
        ]
    )


@router.get("/me", response_model=OpportunityListResponse)
def list_my_opportunities(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OpportunityListResponse:
    opportunities = db.scalars(
        select(Opportunity)
        .where(Opportunity.author_user_id == current_user.id)
        .order_by(Opportunity.created_at.desc())
    ).all()

    return OpportunityListResponse(
        items=[
            _build_opportunity_response(opportunity=opportunity, db=db)
            for opportunity in opportunities
        ]
    )


@router.patch("/{opportunity_id}", response_model=OpportunityResponse)
def update_opportunity(
    opportunity_id: int,
    payload: OpportunityUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OpportunityResponse:
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one field must be provided",
        )

    not_nullable_fields = {
        "title",
        "description",
        "city",
        "province",
        "contact_method",
        "contact_value",
        "instrument_ids",
        "style_ids",
    }
    null_fields = [
        field_name
        for field_name in not_nullable_fields
        if field_name in updates and updates[field_name] is None
    ]
    if null_fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "These fields cannot be null",
                "fields": sorted(null_fields),
            },
        )

    opportunity = db.scalar(
        select(Opportunity).where(Opportunity.id == opportunity_id)
    )

    if opportunity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found",
        )

    if opportunity.author_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the author can update this opportunity",
        )

    if opportunity.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only active opportunities can be updated",
        )

    if "contact_method" in updates:
        updates["contact_method"] = updates["contact_method"].lower()
        if updates["contact_method"] not in CONTACT_METHODS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid contact_method",
            )

    if payload.instrument_ids is not None:
        _validate_unique_positive_ids("instrument_ids", payload.instrument_ids)
        _load_instruments(db=db, instrument_ids=payload.instrument_ids)

    if payload.style_ids is not None:
        _validate_unique_positive_ids("style_ids", payload.style_ids)
        _load_styles(db=db, style_ids=payload.style_ids)

    final_event_date = updates.get("event_date", opportunity.event_date)
    final_price_amount = updates.get("price_amount", opportunity.price_amount)
    if payload.instrument_ids is None:
        has_instruments = db.scalar(
            select(OpportunityInstrument).where(
                OpportunityInstrument.opportunity_id == opportunity.id
            )
        ) is not None
    else:
        has_instruments = bool(payload.instrument_ids)

    if opportunity.type.code in EVENT_DATE_REQUIRED_TYPES and final_event_date is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="event_date is required for this opportunity type",
        )

    if opportunity.type.code in INSTRUMENT_REQUIRED_TYPES and not has_instruments:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one instrument is required for this opportunity type",
        )

    if opportunity.type.code in PRICE_REQUIRED_TYPES and final_price_amount is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="price_amount is required for this opportunity type",
        )

    for field_name in (
        "title",
        "description",
        "city",
        "province",
        "event_date",
        "price_amount",
        "contact_method",
        "contact_value",
    ):
        if field_name in updates:
            setattr(opportunity, field_name, updates[field_name])

    if payload.instrument_ids is not None:
        db.execute(
            delete(OpportunityInstrument).where(
                OpportunityInstrument.opportunity_id == opportunity.id
            )
        )
        for instrument_id in payload.instrument_ids:
            db.add(
                OpportunityInstrument(
                    opportunity_id=opportunity.id,
                    instrument_id=instrument_id,
                )
            )

    if payload.style_ids is not None:
        db.execute(
            delete(OpportunityStyle).where(
                OpportunityStyle.opportunity_id == opportunity.id
            )
        )
        for style_id in payload.style_ids:
            db.add(
                OpportunityStyle(
                    opportunity_id=opportunity.id,
                    style_id=style_id,
                )
            )

    opportunity.updated_at = datetime.now(timezone.utc)
    db.commit()

    return _build_opportunity_response(opportunity=opportunity, db=db)


@router.patch("/{opportunity_id}/close", response_model=OpportunityResponse)
def close_opportunity(
    opportunity_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OpportunityResponse:
    opportunity = db.scalar(
        select(Opportunity).where(Opportunity.id == opportunity_id)
    )

    if opportunity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found",
        )

    if opportunity.author_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the author can close this opportunity",
        )

    opportunity.status = "closed"
    opportunity.updated_at = datetime.now(timezone.utc)
    db.commit()

    return _build_opportunity_response(opportunity=opportunity, db=db)


@router.get("/{opportunity_id}", response_model=OpportunityResponse)
def read_opportunity(
    opportunity_id: int,
    db: Session = Depends(get_db),
) -> OpportunityResponse:
    opportunity = db.scalar(
        select(Opportunity).where(Opportunity.id == opportunity_id)
    )

    if opportunity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found",
        )

    return _build_opportunity_response(opportunity=opportunity, db=db)
