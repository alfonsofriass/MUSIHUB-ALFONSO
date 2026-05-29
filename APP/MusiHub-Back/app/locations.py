import unicodedata

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import City, Province


def _empty_to_none(value: str | None) -> str | None:
    if value is None:
        return None

    value = value.strip()
    if value == "":
        return None

    return value


def _search_key(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.casefold())
    return "".join(
        character
        for character in normalized
        if not unicodedata.combining(character)
    )


def _find_province(db: Session, province_name: str) -> Province | None:
    expected_key = _search_key(province_name)
    provinces = db.scalars(select(Province)).all()

    for province in provinces:
        if _search_key(province.name) == expected_key:
            return province

    return None


def _find_city(db: Session, province: Province, city_name: str) -> City | None:
    expected_key = _search_key(city_name)
    cities = db.scalars(
        select(City).where(City.province_id == province.id)
    ).all()

    for city in cities:
        if _search_key(city.name) == expected_key:
            return city

    return None


def normalize_location(
    db: Session,
    *,
    city: str | None,
    province: str | None,
) -> tuple[str | None, str | None]:
    city = _empty_to_none(city)
    province = _empty_to_none(province)

    if city is not None and province is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="province is required when city is provided",
        )

    if province is None:
        return None, None

    province_row = _find_province(db=db, province_name=province)
    if province_row is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid province",
        )

    if city is None:
        return None, province_row.name

    city_row = _find_city(db=db, province=province_row, city_name=city)
    if city_row is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid city for province",
        )

    return city_row.name, province_row.name
