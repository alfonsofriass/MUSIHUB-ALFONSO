from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.api.routes.opportunities import (
    OpportunityListResponse,
    _build_opportunity_response,
)
from app.db import get_db
from app.models import Favorite, Opportunity, User

router = APIRouter()


class FavoriteStatusResponse(BaseModel):
    opportunity_id: int
    is_favorite: bool
    message: str


@router.post(
    "/opportunities/{opportunity_id}/favorite",
    response_model=FavoriteStatusResponse,
)
def add_favorite(
    opportunity_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FavoriteStatusResponse:
    opportunity = db.scalar(
        select(Opportunity).where(Opportunity.id == opportunity_id)
    )

    if opportunity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Opportunity not found",
        )

    favorite = db.scalar(
        select(Favorite).where(
            Favorite.user_id == current_user.id,
            Favorite.opportunity_id == opportunity_id,
        )
    )

    if favorite is not None:
        return FavoriteStatusResponse(
            opportunity_id=opportunity_id,
            is_favorite=True,
            message="Opportunity already saved as favorite",
        )

    if opportunity.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only active opportunities can be saved as favorite",
        )

    db.add(
        Favorite(
            user_id=current_user.id,
            opportunity_id=opportunity_id,
        )
    )
    db.commit()

    return FavoriteStatusResponse(
        opportunity_id=opportunity_id,
        is_favorite=True,
        message="Opportunity saved as favorite",
    )


@router.delete(
    "/opportunities/{opportunity_id}/favorite",
    response_model=FavoriteStatusResponse,
)
def remove_favorite(
    opportunity_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FavoriteStatusResponse:
    favorite = db.scalar(
        select(Favorite).where(
            Favorite.user_id == current_user.id,
            Favorite.opportunity_id == opportunity_id,
        )
    )

    if favorite is None:
        return FavoriteStatusResponse(
            opportunity_id=opportunity_id,
            is_favorite=False,
            message="Opportunity is not saved as favorite",
        )

    db.delete(favorite)
    db.commit()

    return FavoriteStatusResponse(
        opportunity_id=opportunity_id,
        is_favorite=False,
        message="Opportunity removed from favorites",
    )


@router.get("/favorites/me", response_model=OpportunityListResponse)
def list_my_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OpportunityListResponse:
    opportunities = db.scalars(
        select(Opportunity)
        .join(Favorite, Favorite.opportunity_id == Opportunity.id)
        .where(Favorite.user_id == current_user.id)
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
