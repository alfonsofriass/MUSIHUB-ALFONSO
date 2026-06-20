import unittest

from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.alert_matching import generate_alerts_for_opportunity
from app.db import Base
from app.models import (
    Alert,
    AlertPreference,
    AlertPreferenceInstrument,
    AlertPreferenceStyle,
    AlertPreferenceType,
    Instrument,
    MusicStyle,
    Opportunity,
    OpportunityType,
    User,
)


class AlertDuplicateTest(unittest.TestCase):
    def setUp(self) -> None:
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(engine)
        self.SessionLocal = sessionmaker(bind=engine)

    def test_alert_generation_does_not_duplicate_user_opportunity_pair(self) -> None:
        with self.SessionLocal() as db:
            publisher, receiver, opportunity_type, instrument, style = (
                self._create_base_data(db)
            )
            opportunity = Opportunity(
                type_id=opportunity_type.id,
                author_user_id=publisher.id,
                title="Clases de saxofon blues",
                description="Clases de saxofon en Granada",
                city="Granada",
                province="Granada",
                contact_method="whatsapp",
                contact_value="600000000",
            )
            db.add(opportunity)
            db.flush()

            self._create_alert_preferences(
                db=db,
                user=receiver,
                opportunity_type=opportunity_type,
                instrument=instrument,
                style=style,
            )

            generate_alerts_for_opportunity(
                db=db,
                opportunity=opportunity,
                opportunity_type=opportunity_type,
                current_user=publisher,
                instrument_ids=[instrument.id],
                style_ids=[style.id],
            )
            db.flush()

            generate_alerts_for_opportunity(
                db=db,
                opportunity=opportunity,
                opportunity_type=opportunity_type,
                current_user=publisher,
                instrument_ids=[instrument.id],
                style_ids=[style.id],
            )
            db.flush()

            alert_count = db.scalar(
                select(func.count())
                .select_from(Alert)
                .where(
                    Alert.user_id == receiver.id,
                    Alert.opportunity_id == opportunity.id,
                )
            )

            self.assertEqual(alert_count, 1)

    def _create_base_data(
        self,
        db: Session,
    ) -> tuple[User, User, OpportunityType, Instrument, MusicStyle]:
        publisher = User(
            email="publisher@example.org",
            password_hash="hash",
            full_name="Usuario Publicador",
        )
        receiver = User(
            email="receiver@example.org",
            password_hash="hash",
            full_name="Usuario Receptor",
        )
        opportunity_type = OpportunityType(code="clases", name="Clases")
        instrument = Instrument(name="Saxofon")
        style = MusicStyle(name="Blues")
        db.add_all([publisher, receiver, opportunity_type, instrument, style])
        db.flush()

        return publisher, receiver, opportunity_type, instrument, style

    def _create_alert_preferences(
        self,
        *,
        db: Session,
        user: User,
        opportunity_type: OpportunityType,
        instrument: Instrument,
        style: MusicStyle,
    ) -> None:
        alert_preference = AlertPreference(
            user_id=user.id,
            frequency="immediate",
            preferred_city="Granada",
            preferred_province="Granada",
            notifications_enabled=True,
        )
        db.add(alert_preference)
        db.flush()

        db.add_all(
            [
                AlertPreferenceType(
                    alert_preference_id=alert_preference.id,
                    opportunity_type_id=opportunity_type.id,
                ),
                AlertPreferenceInstrument(
                    alert_preference_id=alert_preference.id,
                    instrument_id=instrument.id,
                ),
                AlertPreferenceStyle(
                    alert_preference_id=alert_preference.id,
                    style_id=style.id,
                ),
            ]
        )


if __name__ == "__main__":
    unittest.main()
