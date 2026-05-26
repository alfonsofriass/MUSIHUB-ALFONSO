import logging
from functools import lru_cache
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import Alert, DeviceToken, Opportunity

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


def send_alert_push(
    db: Session,
    alert: Alert,
    opportunity: Opportunity,
) -> None:
    try:
        firebase_app = _get_firebase_app()
        if firebase_app is None:
            return

        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase-admin is not installed; alert push skipped")
        return
    except Exception as exc:
        logger.warning("Alert push setup failed for alert %s: %s", alert.id, exc)
        return

    try:
        device_tokens = db.scalars(
            select(DeviceToken).where(DeviceToken.user_id == alert.user_id)
        ).all()
    except Exception as exc:
        logger.warning("Could not load device tokens for alert %s: %s", alert.id, exc)
        return

    for device_token in device_tokens:
        message = messaging.Message(
            notification=messaging.Notification(
                title="Nueva oportunidad en MusiHub",
                body=opportunity.title,
            ),
            data={
                "type": "alert",
                "alert_id": str(alert.id),
                "opportunity_id": str(opportunity.id),
            },
            token=device_token.token,
        )

        try:
            messaging.send(message, app=firebase_app)
        except Exception as exc:
            logger.warning(
                "Alert push failed for device token %s: %s",
                device_token.id,
                exc,
            )
