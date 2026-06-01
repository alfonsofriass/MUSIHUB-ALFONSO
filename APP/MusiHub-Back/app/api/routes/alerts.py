from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.api.routes.opportunities import (
    OpportunityResponse,
    _build_opportunity_response,
)
from app.db import get_db
from app.locations import normalize_location
from app.models import (
    Alert,
    AlertPreference,
    AlertPreferenceInstrument,
    AlertPreferenceStyle,
    AlertPreferenceType,
    Instrument,
    MusicStyle,
    Opportunity,
    OpportunityType,
    User,
)

router = APIRouter(prefix="/alerts")

ALERT_FREQUENCIES = {"immediate"}


class AlertPreferenceTypeResponse(BaseModel):
    id: int
    code: str
    name: str


class AlertPreferenceCatalogItemResponse(BaseModel):
    id: int
    name: str


class AlertPreferenceResponse(BaseModel):
    id: int
    frequency: str
    preferred_city: str | None
    preferred_province: str | None
    notifications_enabled: bool
    opportunity_types: list[AlertPreferenceTypeResponse]
    instruments: list[AlertPreferenceCatalogItemResponse]
    styles: list[AlertPreferenceCatalogItemResponse]


class AlertPreferencesMeResponse(BaseModel):
    exists: bool
    preferences: AlertPreferenceResponse | None


class AlertPreferenceUpdateRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    frequency: str = Field(min_length=1, max_length=20)
    preferred_city: str | None = Field(default=None, max_length=120)
    preferred_province: str | None = Field(default=None, max_length=120)
    notifications_enabled: bool = True
    opportunity_type_ids: list[int] = Field(default_factory=list)
    instrument_ids: list[int] = Field(default_factory=list)
    style_ids: list[int] = Field(default_factory=list)


class AlertResponse(BaseModel):
    id: int
    score: int
    reason: str
    created_at: datetime
    opportunity: OpportunityResponse


class AlertListResponse(BaseModel):
    items: list[AlertResponse]


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


def _load_opportunity_types(
    db: Session,
    opportunity_type_ids: list[int],
) -> list[OpportunityType]:
    if not opportunity_type_ids:
        return []

    opportunity_types = db.scalars(
        select(OpportunityType).where(OpportunityType.id.in_(opportunity_type_ids))
    ).all()
    found_ids = {opportunity_type.id for opportunity_type in opportunity_types}
    missing_ids = sorted(set(opportunity_type_ids) - found_ids)

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Invalid opportunity_type_ids",
                "ids": missing_ids,
            },
        )

    return opportunity_types


def _load_instruments(
    db: Session,
    instrument_ids: list[int],
) -> list[Instrument]:
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


def _load_music_styles(
    db: Session,
    style_ids: list[int],
) -> list[MusicStyle]:
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


def _build_alert_preferences_response(
    alert_preference: AlertPreference,
    db: Session,
) -> AlertPreferencesMeResponse:
    opportunity_types = db.scalars(
        select(OpportunityType)
        .join(
            AlertPreferenceType,
            AlertPreferenceType.opportunity_type_id == OpportunityType.id,
        )
        .where(AlertPreferenceType.alert_preference_id == alert_preference.id)
        .order_by(OpportunityType.id)
    ).all()
    instruments = db.scalars(
        select(Instrument)
        .join(
            AlertPreferenceInstrument,
            AlertPreferenceInstrument.instrument_id == Instrument.id,
        )
        .where(AlertPreferenceInstrument.alert_preference_id == alert_preference.id)
        .order_by(Instrument.id)
    ).all()
    styles = db.scalars(
        select(MusicStyle)
        .join(
            AlertPreferenceStyle,
            AlertPreferenceStyle.style_id == MusicStyle.id,
        )
        .where(AlertPreferenceStyle.alert_preference_id == alert_preference.id)
        .order_by(MusicStyle.id)
    ).all()

    return AlertPreferencesMeResponse(
        exists=True,
        preferences=AlertPreferenceResponse(
            id=alert_preference.id,
            frequency=alert_preference.frequency,
            preferred_city=alert_preference.preferred_city,
            preferred_province=alert_preference.preferred_province,
            notifications_enabled=alert_preference.notifications_enabled,
            opportunity_types=[
                AlertPreferenceTypeResponse(
                    id=opportunity_type.id,
                    code=opportunity_type.code,
                    name=opportunity_type.name,
                )
                for opportunity_type in opportunity_types
            ],
            instruments=[
                AlertPreferenceCatalogItemResponse(
                    id=instrument.id,
                    name=instrument.name,
                )
                for instrument in instruments
            ],
            styles=[
                AlertPreferenceCatalogItemResponse(
                    id=style.id,
                    name=style.name,
                )
                for style in styles
            ],
        ),
    )


def _build_alert_response(
    alert: Alert,
    opportunity: Opportunity,
    db: Session,
    current_user: User,
) -> AlertResponse:
    return AlertResponse(
        id=alert.id,
        score=alert.score,
        reason=alert.reason,
        created_at=alert.created_at,
        opportunity=_build_opportunity_response(
            opportunity=opportunity,
            db=db,
            current_user=current_user,
        ),
    )


@router.get("/preferences", response_model=AlertPreferencesMeResponse)
def read_my_alert_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AlertPreferencesMeResponse:
    alert_preference = db.scalar(
        select(AlertPreference).where(AlertPreference.user_id == current_user.id)
    )

    if alert_preference is None:
        return AlertPreferencesMeResponse(exists=False, preferences=None)

    return _build_alert_preferences_response(
        alert_preference=alert_preference,
        db=db,
    )


@router.get("/me", response_model=AlertListResponse)
def list_my_alerts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AlertListResponse:
    alert_rows = db.execute(
        select(Alert, Opportunity)
        .join(Opportunity, Opportunity.id == Alert.opportunity_id)
        .where(Alert.user_id == current_user.id)
        .order_by(Alert.created_at.desc())
    ).all()

    return AlertListResponse(
        items=[
            _build_alert_response(
                alert=alert,
                opportunity=opportunity,
                db=db,
                current_user=current_user,
            )
            for alert, opportunity in alert_rows
        ]
    )


@router.put("/preferences", response_model=AlertPreferencesMeResponse)
def update_my_alert_preferences(
    payload: AlertPreferenceUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AlertPreferencesMeResponse:
    frequency = payload.frequency.lower()
    if frequency not in ALERT_FREQUENCIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid frequency",
        )

    _validate_unique_positive_ids(
        "opportunity_type_ids",
        payload.opportunity_type_ids,
    )
    _validate_unique_positive_ids(
        "instrument_ids",
        payload.instrument_ids,
    )
    _validate_unique_positive_ids(
        "style_ids",
        payload.style_ids,
    )
    opportunity_types = _load_opportunity_types(
        db=db,
        opportunity_type_ids=payload.opportunity_type_ids,
    )
    instruments = _load_instruments(
        db=db,
        instrument_ids=payload.instrument_ids,
    )
    styles = _load_music_styles(
        db=db,
        style_ids=payload.style_ids,
    )
    preferred_city, preferred_province = normalize_location(
        db=db,
        city=payload.preferred_city,
        province=payload.preferred_province,
    )

    alert_preference = db.scalar(
        select(AlertPreference).where(AlertPreference.user_id == current_user.id)
    )
    if alert_preference is None:
        alert_preference = AlertPreference(
            user_id=current_user.id,
            frequency=frequency,
            preferred_city=preferred_city,
            preferred_province=preferred_province,
            notifications_enabled=payload.notifications_enabled,
        )
        db.add(alert_preference)
        db.flush()
    else:
        alert_preference.frequency = frequency
        alert_preference.preferred_city = preferred_city
        alert_preference.preferred_province = preferred_province
        alert_preference.notifications_enabled = payload.notifications_enabled

    db.execute(
        delete(AlertPreferenceType).where(
            AlertPreferenceType.alert_preference_id == alert_preference.id
        )
    )
    db.execute(
        delete(AlertPreferenceInstrument).where(
            AlertPreferenceInstrument.alert_preference_id == alert_preference.id
        )
    )
    db.execute(
        delete(AlertPreferenceStyle).where(
            AlertPreferenceStyle.alert_preference_id == alert_preference.id
        )
    )

    valid_opportunity_type_ids = {
        opportunity_type.id for opportunity_type in opportunity_types
    }
    for opportunity_type_id in payload.opportunity_type_ids:
        if opportunity_type_id not in valid_opportunity_type_ids:
            continue
        db.add(
            AlertPreferenceType(
                alert_preference_id=alert_preference.id,
                opportunity_type_id=opportunity_type_id,
            )
        )
    valid_instrument_ids = {instrument.id for instrument in instruments}
    for instrument_id in payload.instrument_ids:
        if instrument_id not in valid_instrument_ids:
            continue
        db.add(
            AlertPreferenceInstrument(
                alert_preference_id=alert_preference.id,
                instrument_id=instrument_id,
            )
        )

    valid_style_ids = {style.id for style in styles}
    for style_id in payload.style_ids:
        if style_id not in valid_style_ids:
            continue
        db.add(
            AlertPreferenceStyle(
                alert_preference_id=alert_preference.id,
                style_id=style_id,
            )
        )

    db.commit()

    return _build_alert_preferences_response(
        alert_preference=alert_preference,
        db=db,
    )
