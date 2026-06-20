from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    Alert,
    AlertPreference,
    AlertPreferenceInstrument,
    AlertPreferenceStyle,
    AlertPreferenceType,
    Notification,
    Opportunity,
    OpportunityType,
    User,
)

ALERT_TYPE_SCORE = 50
ALERT_CITY_SCORE = 20
ALERT_PROVINCE_SCORE = 10
ALERT_INSTRUMENT_SCORE = 20
ALERT_STYLE_SCORE = 20
ALERT_MIN_SCORE = 50


def _matches_optional_text(expected: str | None, actual: str) -> bool:
    if expected is None:
        return True
    return expected.casefold() == actual.casefold()


def generate_alerts_for_opportunity(
    db: Session,
    opportunity: Opportunity,
    opportunity_type: OpportunityType,
    current_user: User,
    instrument_ids: list[int],
    style_ids: list[int],
) -> list[Notification]:
    immediate_notifications: list[Notification] = []
    alert_preferences = db.scalars(
        select(AlertPreference)
        .join(
            AlertPreferenceType,
            AlertPreferenceType.alert_preference_id == AlertPreference.id,
        )
        .where(
            AlertPreference.notifications_enabled.is_(True),
            AlertPreference.user_id != current_user.id,
            AlertPreferenceType.opportunity_type_id == opportunity_type.id,
        )
    ).all()

    opportunity_instrument_ids = set(instrument_ids)
    opportunity_style_ids = set(style_ids)

    for alert_preference in alert_preferences:
        if not _matches_optional_text(alert_preference.preferred_city, opportunity.city):
            continue
        if not _matches_optional_text(
            alert_preference.preferred_province,
            opportunity.province,
        ):
            continue

        preferred_instrument_ids = set(
            db.scalars(
                select(AlertPreferenceInstrument.instrument_id).where(
                    AlertPreferenceInstrument.alert_preference_id
                    == alert_preference.id
                )
            ).all()
        )
        if (
            preferred_instrument_ids
            and not opportunity_instrument_ids & preferred_instrument_ids
        ):
            continue

        preferred_style_ids = set(
            db.scalars(
                select(AlertPreferenceStyle.style_id).where(
                    AlertPreferenceStyle.alert_preference_id == alert_preference.id
                )
            ).all()
        )
        if preferred_style_ids and not opportunity_style_ids & preferred_style_ids:
            continue

        score = ALERT_TYPE_SCORE
        reasons = [f"Tipo: {opportunity_type.name}"]

        if alert_preference.preferred_city is not None:
            score += ALERT_CITY_SCORE
            reasons.append(f"Ciudad: {opportunity.city}")

        if alert_preference.preferred_province is not None:
            score += ALERT_PROVINCE_SCORE
            reasons.append(f"Provincia: {opportunity.province}")

        if preferred_instrument_ids:
            score += ALERT_INSTRUMENT_SCORE
            reasons.append("Instrumento compatible")

        if preferred_style_ids:
            score += ALERT_STYLE_SCORE
            reasons.append("Estilo compatible")

        score = min(score, 100)
        if score < ALERT_MIN_SCORE:
            continue

        existing_alert = db.scalar(
            select(Alert).where(
                Alert.user_id == alert_preference.user_id,
                Alert.opportunity_id == opportunity.id,
            )
        )
        if existing_alert is not None:
            continue

        alert = Alert(
            user_id=alert_preference.user_id,
            opportunity_id=opportunity.id,
            score=score,
            reason=", ".join(reasons),
        )
        db.add(alert)
        notification = Notification(
            user_id=alert_preference.user_id,
            type="alert_match",
            title="Nueva oportunidad en MusiHub",
            body=opportunity.title,
            data={"opportunity_id": opportunity.id},
        )
        db.add(notification)
        if alert_preference.frequency == "immediate":
            immediate_notifications.append(notification)

    return immediate_notifications
