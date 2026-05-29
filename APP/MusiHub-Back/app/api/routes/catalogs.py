from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import City, Instrument, MusicStyle, OpportunityType, Province

router = APIRouter(prefix="/catalogs")


class CatalogItemResponse(BaseModel):
    id: int
    name: str


class CatalogListResponse(BaseModel):
    items: list[CatalogItemResponse]


class ProvinceResponse(BaseModel):
    id: int
    name: str
    cities: list[CatalogItemResponse]


class LocationCatalogResponse(BaseModel):
    items: list[ProvinceResponse]


class OpportunityTypeResponse(BaseModel):
    id: int
    code: str
    name: str


class OpportunityTypeListResponse(BaseModel):
    items: list[OpportunityTypeResponse]


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


@router.get("/opportunity-types", response_model=OpportunityTypeListResponse)
def list_opportunity_types(db: Session = Depends(get_db)) -> OpportunityTypeListResponse:
    opportunity_types = db.scalars(
        select(OpportunityType).order_by(OpportunityType.id)
    ).all()

    return OpportunityTypeListResponse(
        items=[
            OpportunityTypeResponse(
                id=opportunity_type.id,
                code=opportunity_type.code,
                name=opportunity_type.name,
            )
            for opportunity_type in opportunity_types
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


@router.get("/locations", response_model=LocationCatalogResponse)
def list_locations(db: Session = Depends(get_db)) -> LocationCatalogResponse:
    provinces = db.scalars(
        select(Province).order_by(Province.name)
    ).all()
    cities = db.scalars(
        select(City).order_by(City.name)
    ).all()
    cities_by_province_id: dict[int, list[CatalogItemResponse]] = {
        province.id: [] for province in provinces
    }

    for city in cities:
        cities_by_province_id.setdefault(city.province_id, []).append(
            CatalogItemResponse(id=city.id, name=city.name)
        )

    return LocationCatalogResponse(
        items=[
            ProvinceResponse(
                id=province.id,
                name=province.name,
                cities=cities_by_province_id.get(province.id, []),
            )
            for province in provinces
        ]
    )
