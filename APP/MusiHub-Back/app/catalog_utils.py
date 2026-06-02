from typing import TypeVar

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import Base
from app.models import Instrument, MusicStyle, OpportunityType

CatalogModel = TypeVar("CatalogModel", bound=Base)


def validate_unique_positive_ids(field_name: str, ids: list[int]) -> None:
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


def _load_catalog_items(
    db: Session,
    *,
    model: type[CatalogModel],
    ids: list[int],
    field_name: str,
) -> list[CatalogModel]:
    if not ids:
        return []

    items = db.scalars(select(model).where(model.id.in_(ids))).all()
    found_ids = {item.id for item in items}
    missing_ids = sorted(set(ids) - found_ids)

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": f"Invalid {field_name}",
                "ids": missing_ids,
            },
        )

    return items


def load_instruments(db: Session, instrument_ids: list[int]) -> list[Instrument]:
    return _load_catalog_items(
        db,
        model=Instrument,
        ids=instrument_ids,
        field_name="instrument_ids",
    )


def load_music_styles(db: Session, style_ids: list[int]) -> list[MusicStyle]:
    return _load_catalog_items(
        db,
        model=MusicStyle,
        ids=style_ids,
        field_name="style_ids",
    )


def load_opportunity_types(
    db: Session,
    opportunity_type_ids: list[int],
) -> list[OpportunityType]:
    return _load_catalog_items(
        db,
        model=OpportunityType,
        ids=opportunity_type_ids,
        field_name="opportunity_type_ids",
    )
