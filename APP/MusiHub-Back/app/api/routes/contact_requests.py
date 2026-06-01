from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.api.routes.opportunities import (
    OpportunityResponse,
    _build_opportunity_response,
)
from app.db import get_db
from app.models import ContactRequest, Notification, Opportunity, User
from app.push import send_notification_push

router = APIRouter(prefix="/contact-requests")


class ContactRequestUserResponse(BaseModel):
    id: int
    full_name: str


class ContactRequestReceivedResponse(BaseModel):
    id: int
    status: str
    created_at: datetime
    responded_at: datetime | None
    requester: ContactRequestUserResponse
    opportunity: OpportunityResponse


class ContactRequestReceivedListResponse(BaseModel):
    items: list[ContactRequestReceivedResponse]


class ContactRequestSentResponse(BaseModel):
    id: int
    status: str
    created_at: datetime
    responded_at: datetime | None
    owner: ContactRequestUserResponse
    opportunity: OpportunityResponse


class ContactRequestSentListResponse(BaseModel):
    items: list[ContactRequestSentResponse]


class ContactRequestStatusResponse(BaseModel):
    id: int
    opportunity_id: int
    requester_user_id: int
    owner_user_id: int
    status: str
    created_at: datetime
    responded_at: datetime | None


def _build_contact_request_status_response(
    contact_request: ContactRequest,
) -> ContactRequestStatusResponse:
    return ContactRequestStatusResponse(
        id=contact_request.id,
        opportunity_id=contact_request.opportunity_id,
        requester_user_id=contact_request.requester_user_id,
        owner_user_id=contact_request.owner_user_id,
        status=contact_request.status,
        created_at=contact_request.created_at,
        responded_at=contact_request.responded_at,
    )


def _answer_contact_request(
    contact_request_id: int,
    new_status: str,
    current_user: User,
    db: Session,
) -> ContactRequestStatusResponse:
    contact_request = db.scalar(
        select(ContactRequest).where(ContactRequest.id == contact_request_id)
    )
    if contact_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact request not found",
        )

    if contact_request.owner_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the opportunity owner can answer this contact request",
        )

    if contact_request.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only pending contact requests can be answered",
        )

    contact_request.status = new_status
    contact_request.responded_at = datetime.now(timezone.utc)
    if new_status == "accepted":
        notification_type = "contact_request_accepted"
        title = "Solicitud aceptada"
        body = "Ya puedes ver el contacto del anuncio"
    else:
        notification_type = "contact_request_rejected"
        title = "Solicitud rechazada"
        body = "El anunciante no ha aceptado compartir el contacto"

    notification = Notification(
        user_id=contact_request.requester_user_id,
        type=notification_type,
        title=title,
        body=body,
        data={
            "contact_request_id": contact_request.id,
            "opportunity_id": contact_request.opportunity_id,
        },
    )
    db.add(notification)
    db.commit()
    db.refresh(contact_request)
    send_notification_push(db=db, notification=notification)

    return _build_contact_request_status_response(contact_request)


@router.get("/received", response_model=ContactRequestReceivedListResponse)
def list_received_contact_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContactRequestReceivedListResponse:
    contact_request_rows = db.execute(
        select(ContactRequest, Opportunity, User)
        .join(Opportunity, Opportunity.id == ContactRequest.opportunity_id)
        .join(User, User.id == ContactRequest.requester_user_id)
        .where(ContactRequest.owner_user_id == current_user.id)
        .order_by(ContactRequest.created_at.desc())
    ).all()

    return ContactRequestReceivedListResponse(
        items=[
            ContactRequestReceivedResponse(
                id=contact_request.id,
                status=contact_request.status,
                created_at=contact_request.created_at,
                responded_at=contact_request.responded_at,
                requester=ContactRequestUserResponse(
                    id=requester.id,
                    full_name=requester.full_name,
                ),
                opportunity=_build_opportunity_response(
                    opportunity=opportunity,
                    db=db,
                    current_user=current_user,
                ),
            )
            for contact_request, opportunity, requester in contact_request_rows
        ]
    )


@router.get("/sent", response_model=ContactRequestSentListResponse)
def list_sent_contact_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContactRequestSentListResponse:
    contact_request_rows = db.execute(
        select(ContactRequest, Opportunity, User)
        .join(Opportunity, Opportunity.id == ContactRequest.opportunity_id)
        .join(User, User.id == ContactRequest.owner_user_id)
        .where(ContactRequest.requester_user_id == current_user.id)
        .order_by(ContactRequest.created_at.desc())
    ).all()

    return ContactRequestSentListResponse(
        items=[
            ContactRequestSentResponse(
                id=contact_request.id,
                status=contact_request.status,
                created_at=contact_request.created_at,
                responded_at=contact_request.responded_at,
                owner=ContactRequestUserResponse(
                    id=owner.id,
                    full_name=owner.full_name,
                ),
                opportunity=_build_opportunity_response(
                    opportunity=opportunity,
                    db=db,
                    current_user=current_user,
                ),
            )
            for contact_request, opportunity, owner in contact_request_rows
        ]
    )


@router.patch("/{contact_request_id}/accept", response_model=ContactRequestStatusResponse)
def accept_contact_request(
    contact_request_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContactRequestStatusResponse:
    return _answer_contact_request(
        contact_request_id=contact_request_id,
        new_status="accepted",
        current_user=current_user,
        db=db,
    )


@router.patch("/{contact_request_id}/reject", response_model=ContactRequestStatusResponse)
def reject_contact_request(
    contact_request_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContactRequestStatusResponse:
    return _answer_contact_request(
        contact_request_id=contact_request_id,
        new_status="rejected",
        current_user=current_user,
        db=db,
    )
