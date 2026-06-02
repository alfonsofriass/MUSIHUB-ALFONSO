import logging
from functools import lru_cache
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import DeviceToken, Notification

logger = logging.getLogger(__name__)


@lru_cache
def _get_firebase_app() -> Any | None:
    if not settings.push_notifications_enabled:
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.warning("firebase-admin is not installed; push notifications disabled")
        return None

    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    options = {}
    if settings.firebase_project_id is not None:
        options["projectId"] = settings.firebase_project_id

    try:
        if settings.firebase_credentials_path is not None:
            credential = credentials.Certificate(settings.firebase_credentials_path)
            return firebase_admin.initialize_app(
                credential=credential,
                options=options or None,
            )

        return firebase_admin.initialize_app(options=options or None)
    except Exception as exc:
        logger.warning("Firebase initialization failed; push disabled: %s", exc)
        return None


def _stringify_data(data: dict[str, Any] | None) -> dict[str, str]:
    if data is None:
        return {}

    return {
        key: str(value)
        for key, value in data.items()
        if value is not None
    }


def send_notification_push(
    db: Session,
    notification: Notification,
) -> None:
    try:
        firebase_app = _get_firebase_app()
        if firebase_app is None:
            return

        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase-admin is not installed; notification push skipped")
        return
    except Exception as exc:
        logger.warning(
            "Notification push setup failed for notification %s: %s",
            notification.id,
            exc,
        )
        return

    try:
        device_tokens = db.scalars(
            select(DeviceToken).where(DeviceToken.user_id == notification.user_id)
        ).all()
    except Exception as exc:
        logger.warning(
            "Could not load device tokens for notification %s: %s",
            notification.id,
            exc,
        )
        return

    logger.info(
        "Notification push: notification=%s user=%s tokens=%s",
        notification.id,
        notification.user_id,
        len(device_tokens),
    )

    message_data = {
        "type": notification.type,
        "notification_id": str(notification.id),
        **_stringify_data(notification.data),
    }

    for device_token in device_tokens:
        message = messaging.Message(
            notification=messaging.Notification(
                title=notification.title,
                body=notification.body,
            ),
            data=message_data,
            token=device_token.token,
        )

        try:
            messaging.send(message, app=firebase_app)
            logger.info(
                "Notification push sent: notification=%s device_token=%s",
                notification.id,
                device_token.id,
            )
        except Exception as exc:
            logger.warning(
                "Notification push failed for device token %s: %s",
                device_token.id,
                exc,
            )
