from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user
from app.db import get_db
from app.models import Notification, User

router = APIRouter(prefix="/notifications")


class NotificationResponse(BaseModel):
    id: int
    type: str
    title: str
    body: str
    created_at: datetime
    read_at: datetime | None
    data: dict[str, Any] | None


class NotificationListResponse(BaseModel):
    unread_count: int
    items: list[NotificationResponse]


class NotificationReadResponse(BaseModel):
    id: int
    read_at: datetime


class NotificationReadAllResponse(BaseModel):
    updated: int


def _build_notification_response(notification: Notification) -> NotificationResponse:
    return NotificationResponse(
        id=notification.id,
        type=notification.type,
        title=notification.title,
        body=notification.body,
        created_at=notification.created_at,
        read_at=notification.read_at,
        data=notification.data,
    )


@router.get("", response_model=NotificationListResponse)
def list_my_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationListResponse:
    unread_count = db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.read_at.is_(None),
        )
    )
    notifications = db.scalars(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    ).all()

    return NotificationListResponse(
        unread_count=unread_count or 0,
        items=[
            _build_notification_response(notification)
            for notification in notifications
        ],
    )


@router.patch("/read-all", response_model=NotificationReadAllResponse)
def mark_all_notifications_as_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationReadAllResponse:
    now = datetime.now(timezone.utc)
    result = db.execute(
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.read_at.is_(None),
        )
        .values(read_at=now)
    )
    db.commit()

    return NotificationReadAllResponse(updated=result.rowcount or 0)


@router.patch("/{notification_id}/read", response_model=NotificationReadResponse)
def mark_notification_as_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationReadResponse:
    notification = db.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )

    if notification.read_at is None:
        notification.read_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notification)

    return NotificationReadResponse(
        id=notification.id,
        read_at=notification.read_at,
    )
