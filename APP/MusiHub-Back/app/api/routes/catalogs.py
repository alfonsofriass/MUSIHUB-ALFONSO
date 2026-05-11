from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Instrument, MusicStyle

router = APIRouter(prefix="/catalogs")


class CatalogItemResponse(BaseModel):
    id: int
    name: str


class CatalogListResponse(BaseModel):
    items: list[CatalogItemResponse]


@router.get("/instruments", response_model=CatalogListResponse)
def list_instruments(db: Session = Depends(get_db)) -> CatalogListResponse:
    instruments = db.scalars(
        select(Instrument).order_by(Instrument.name)
    ).all()

    return CatalogListResponse(
        items=[
            CatalogItemResponse(id=instrument.id, name=instrument.name)
            for instrument in instruments
        ]
    )


@router.get("/music-styles", response_model=CatalogListResponse)
def list_music_styles(db: Session = Depends(get_db)) -> CatalogListResponse:
    music_styles = db.scalars(
        select(MusicStyle).order_by(MusicStyle.name)
    ).all()

    return CatalogListResponse(
        items=[
            CatalogItemResponse(id=music_style.id, name=music_style.name)
            for music_style in music_styles
        ]
    )
