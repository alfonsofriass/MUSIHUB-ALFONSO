from datetime import date, datetime, time, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.models import (
    Alert,
    AlertPreference,
    AlertPreferenceType,
    Band,
    BandMember,
    ContactRequest,
    Instrument,
    MusicStyle,
    Opportunity,
    OpportunityInstrument,
    OpportunityStyle,
    OpportunityType,
    Profile,
    ProfileInstrument,
    ProfileStyle,
    User,
)

router = APIRouter(prefix="/opportunities")

CONTACT_METHODS = {"whatsapp", "email", "phone", "other"}
EVENT_DATE_REQUIRED_TYPES = {"bolos_sustituciones", "eventos"}
INSTRUMENT_REQUIRED_TYPES = {"bolos_sustituciones", "busqueda_miembros"}
PRICE_REQUIRED_TYPES = {"compraventa"}
ALERT_TYPE_SCORE = 50
ALERT_CITY_SCORE = 20
ALERT_PROVINCE_SCORE = 10
ALERT_INSTRUMENT_SCORE = 20
ALERT_STYLE_SCORE = 20
ALERT_MIN_SCORE = 50


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
    author_band_id: int | None = Field(default=None, gt=0)
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

    author_band_id: int | None = Field(default=None, gt=0)
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
    author_band: CatalogItemResponse | None
    title: str
    description: str
    city: str
    province: str
    event_date: datetime | None
    price_amount: Decimal | None
    contact_method: str
    contact_value: str | None
    status: str
    created_at: datetime
    updated_at: datetime
    expires_at: datetime | None
    instruments: list[CatalogItemResponse]
    styles: list[CatalogItemResponse]


class OpportunityListResponse(BaseModel):
    items: list[OpportunityResponse]


class ContactRequestResponse(BaseModel):
    id: int
    opportunity_id: int
    requester_user_id: int
    owner_user_id: int
    status: str
    created_at: datetime
    responded_at: datetime | None


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


def _load_author_band_for_user(
    db: Session,
    author_band_id: int,
    current_user: User,
) -> Band:
    band = db.scalar(select(Band).where(Band.id == author_band_id))
    if band is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid author_band_id",
        )

    membership = db.scalar(
        select(BandMember).where(
            BandMember.band_id == author_band_id,
            BandMember.user_id == current_user.id,
            BandMember.membership_status == "accepted",
        )
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not an accepted member of this band",
        )

    return band


def _matches_optional_text(expected: str | None, actual: str) -> bool:
    if expected is None:
        return True
    return expected.casefold() == actual.casefold()


def _generate_alerts_for_opportunity(
    db: Session,
    opportunity: Opportunity,
    opportunity_type: OpportunityType,
    current_user: User,
    instrument_ids: list[int],
    style_ids: list[int],
) -> None:
    alert_preferences = db.scalars(
        select(AlertPreference)
        .join(
            AlertPreferenceType,
            AlertPreferenceType.alert_preference_id == AlertPreference.id,
        )
        .where(
            AlertPreference.notifications_enabled.is_(True),
            AlertPreference.user_id != current_user.id,
            AlertPreferenceType.opportunity_type_id == opportunity_type.id,
        )
    ).all()

    opportunity_instrument_ids = set(instrument_ids)
    opportunity_style_ids = set(style_ids)

    for alert_preference in alert_preferences:
        if not _matches_optional_text(alert_preference.preferred_city, opportunity.city):
            continue
        if not _matches_optional_text(
            alert_preference.preferred_province,
            opportunity.province,
        ):
            continue

        profile = db.scalar(
            select(Profile).where(Profile.user_id == alert_preference.user_id)
        )
        profile_instrument_ids: set[int] = set()
        profile_style_ids: set[int] = set()
        if profile is not None:
            profile_instrument_ids = set(
                db.scalars(
                    select(ProfileInstrument.instrument_id).where(
                        ProfileInstrument.profile_id == profile.id
                    )
                ).all()
            )
            profile_style_ids = set(
                db.scalars(
                    select(ProfileStyle.style_id).where(
                        ProfileStyle.profile_id == profile.id
                    )
                ).all()
            )

        score = ALERT_TYPE_SCORE
        reasons = [f"Tipo: {opportunity_type.name}"]

        if alert_preference.preferred_city is not None:
            score += ALERT_CITY_SCORE
            reasons.append(f"Ciudad: {opportunity.city}")

        if alert_preference.preferred_province is not None:
            score += ALERT_PROVINCE_SCORE
            reasons.append(f"Provincia: {opportunity.province}")

        if opportunity_instrument_ids & profile_instrument_ids:
            score += ALERT_INSTRUMENT_SCORE
            reasons.append("Instrumento compatible")

        if opportunity_style_ids & profile_style_ids:
            score += ALERT_STYLE_SCORE
            reasons.append("Estilo compatible")

        score = min(score, 100)
        if score < ALERT_MIN_SCORE:
            continue

        existing_alert = db.scalar(
            select(Alert).where(
                Alert.user_id == alert_preference.user_id,
                Alert.opportunity_id == opportunity.id,
            )
        )
        if existing_alert is not None:
            continue

        db.add(
            Alert(
                user_id=alert_preference.user_id,
                opportunity_id=opportunity.id,
                score=score,
                reason=", ".join(reasons),
            )
        )


def _can_view_opportunity_contact(
    opportunity: Opportunity,
    db: Session,
    current_user: User | None,
) -> bool:
    if current_user is None:
        return False

    if opportunity.author_user_id == current_user.id:
        return True

    accepted_contact_request = db.scalar(
        select(ContactRequest).where(
            ContactRequest.opportunity_id == opportunity.id,
            ContactRequest.requester_user_id == current_user.id,
            ContactRequest.status == "accepted",
        )
    )

    return accepted_contact_request is not None


def _build_opportunity_response(
    opportunity: Opportunity,
    db: Session,
    current_user: User | None = None,
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
        author_band=(
            CatalogItemResponse(
                id=opportunity.author_band.id,
                name=opportunity.author_band.name,
            )
            if opportunity.author_band is not None
            else None
        ),
        title=opportunity.title,
        description=opportunity.description,
        city=opportunity.city,
        province=opportunity.province,
        event_date=opportunity.event_date,
        price_amount=opportunity.price_amount,
        contact_method=opportunity.contact_method,
        contact_value=(
            opportunity.contact_value
            if _can_view_opportunity_contact(
                opportunity=opportunity,
                db=db,
                current_user=current_user,
            )
            else None
        ),
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
    if payload.author_band_id is not None:
        _load_author_band_for_user(
            db=db,
            author_band_id=payload.author_band_id,
            current_user=current_user,
        )

    opportunity = Opportunity(
        type_id=opportunity_type.id,
        author_user_id=current_user.id,
        author_band_id=payload.author_band_id,
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

    _generate_alerts_for_opportunity(
        db=db,
        opportunity=opportunity,
        opportunity_type=opportunity_type,
        current_user=current_user,
        instrument_ids=payload.instrument_ids,
        style_ids=payload.style_ids,
    )

    db.commit()

    return _build_opportunity_response(
        opportunity=opportunity,
        db=db,
        current_user=current_user,
    )


@router.post(
    "/{opportunity_id}/contact-requests",
    response_model=ContactRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_contact_request(
    opportunity_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContactRequestResponse:
    opportunity = db.scalar(
        select(Opportunity).where(Opportunity.id == opportunity_id)
    )
    if opportunity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found",
        )

    if opportunity.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only active opportunities can receive contact requests",
        )

    if opportunity.author_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot request contact for your own opportunity",
        )

    existing_contact_request = db.scalar(
        select(ContactRequest).where(
            ContactRequest.opportunity_id == opportunity.id,
            ContactRequest.requester_user_id == current_user.id,
        )
    )
    if existing_contact_request is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Contact request already exists",
        )

    contact_request = ContactRequest(
        opportunity_id=opportunity.id,
        requester_user_id=current_user.id,
        owner_user_id=opportunity.author_user_id,
    )
    db.add(contact_request)
    db.commit()
    db.refresh(contact_request)

    return ContactRequestResponse(
        id=contact_request.id,
        opportunity_id=contact_request.opportunity_id,
        requester_user_id=contact_request.requester_user_id,
        owner_user_id=contact_request.owner_user_id,
        status=contact_request.status,
        created_at=contact_request.created_at,
        responded_at=contact_request.responded_at,
    )


@router.get("", response_model=OpportunityListResponse)
def list_opportunities(
    type_id: int | None = Query(default=None, gt=0),
    city: str | None = Query(default=None, min_length=1, max_length=120),
    province: str | None = Query(default=None, min_length=1, max_length=120),
    instrument_id: int | None = Query(default=None, gt=0),
    style_id: int | None = Query(default=None, gt=0),
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
    min_price: Decimal | None = Query(default=None, ge=0),
    max_price: Decimal | None = Query(default=None, ge=0),
    db: Session = Depends(get_db),
) -> OpportunityListResponse:
    if date_from is not None and date_to is not None and date_from > date_to:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_from must be before or equal to date_to",
        )

    if min_price is not None and max_price is not None and min_price > max_price:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="min_price must be less than or equal to max_price",
        )

    query = select(Opportunity).where(Opportunity.status == "active")

    if type_id is not None:
        query = query.where(Opportunity.type_id == type_id)

    if city is not None:
        query = query.where(func.lower(Opportunity.city) == city.lower())

    if province is not None:
        query = query.where(func.lower(Opportunity.province) == province.lower())

    if date_from is not None:
        query = query.where(
            Opportunity.event_date >= datetime.combine(
                date_from,
                time.min,
                tzinfo=timezone.utc,
            )
        )

    if date_to is not None:
        query = query.where(
            Opportunity.event_date <= datetime.combine(
                date_to,
                time.max,
                tzinfo=timezone.utc,
            )
        )

    if min_price is not None:
        query = query.where(Opportunity.price_amount >= min_price)

    if max_price is not None:
        query = query.where(Opportunity.price_amount <= max_price)

    if instrument_id is not None:
        query = query.join(
            OpportunityInstrument,
            OpportunityInstrument.opportunity_id == Opportunity.id,
        ).where(OpportunityInstrument.instrument_id == instrument_id)

    if style_id is not None:
        query = query.join(
            OpportunityStyle,
            OpportunityStyle.opportunity_id == Opportunity.id,
        ).where(OpportunityStyle.style_id == style_id)

    opportunities = db.scalars(
        query.order_by(Opportunity.created_at.desc())
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
            _build_opportunity_response(
                opportunity=opportunity,
                db=db,
                current_user=current_user,
            )
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

    if "author_band_id" in updates and updates["author_band_id"] is not None:
        _load_author_band_for_user(
            db=db,
            author_band_id=updates["author_band_id"],
            current_user=current_user,
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
        "author_band_id",
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

    return _build_opportunity_response(
        opportunity=opportunity,
        db=db,
        current_user=current_user,
    )


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

    return _build_opportunity_response(
        opportunity=opportunity,
        db=db,
        current_user=current_user,
    )


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
