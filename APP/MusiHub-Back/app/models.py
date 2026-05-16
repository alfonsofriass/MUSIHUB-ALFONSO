from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    user_roles: Mapped[list["UserRole"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )
    profile: Mapped["Profile | None"] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        uselist=False,
    )
    opportunities: Mapped[list["Opportunity"]] = relationship(
        back_populates="author",
    )
    favorites: Mapped[list["Favorite"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)

    user_roles: Mapped[list["UserRole"]] = relationship(
        back_populates="role",
    )


class UserRole(Base):
    __tablename__ = "user_roles"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        primary_key=True,
    )
    role_id: Mapped[int] = mapped_column(
        ForeignKey("roles.id"),
        primary_key=True,
    )
    is_primary: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )

    user: Mapped["User"] = relationship(back_populates="user_roles")
    role: Mapped["Role"] = relationship(back_populates="user_roles")


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        unique=True,
        nullable=False,
    )
    city: Mapped[str | None] = mapped_column(String(120))
    province: Mapped[str | None] = mapped_column(String(120))
    bio: Mapped[str | None] = mapped_column(Text)
    photo_url: Mapped[str | None] = mapped_column(String(500))
    contact_email: Mapped[str | None] = mapped_column(String(255))
    contact_phone: Mapped[str | None] = mapped_column(String(30))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    user: Mapped["User"] = relationship(back_populates="profile")
    profile_instruments: Mapped[list["ProfileInstrument"]] = relationship(
        back_populates="profile",
        cascade="all, delete-orphan",
    )
    profile_styles: Mapped[list["ProfileStyle"]] = relationship(
        back_populates="profile",
        cascade="all, delete-orphan",
    )


class Instrument(Base):
    __tablename__ = "instruments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(
        String(120),
        unique=True,
        index=True,
        nullable=False,
    )

    profile_instruments: Mapped[list["ProfileInstrument"]] = relationship(
        back_populates="instrument",
    )
    opportunity_instruments: Mapped[list["OpportunityInstrument"]] = relationship(
        back_populates="instrument",
    )


class MusicStyle(Base):
    __tablename__ = "music_styles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(
        String(120),
        unique=True,
        index=True,
        nullable=False,
    )

    profile_styles: Mapped[list["ProfileStyle"]] = relationship(
        back_populates="style",
    )
    opportunity_styles: Mapped[list["OpportunityStyle"]] = relationship(
        back_populates="style",
    )


class ProfileInstrument(Base):
    __tablename__ = "profile_instruments"

    profile_id: Mapped[int] = mapped_column(
        ForeignKey("profiles.id"),
        primary_key=True,
    )
    instrument_id: Mapped[int] = mapped_column(
        ForeignKey("instruments.id"),
        primary_key=True,
    )
    is_primary: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )

    profile: Mapped["Profile"] = relationship(back_populates="profile_instruments")
    instrument: Mapped["Instrument"] = relationship(back_populates="profile_instruments")


class ProfileStyle(Base):
    __tablename__ = "profile_styles"

    profile_id: Mapped[int] = mapped_column(
        ForeignKey("profiles.id"),
        primary_key=True,
    )
    style_id: Mapped[int] = mapped_column(
        ForeignKey("music_styles.id"),
        primary_key=True,
    )

    profile: Mapped["Profile"] = relationship(back_populates="profile_styles")
    style: Mapped["MusicStyle"] = relationship(back_populates="profile_styles")


class OpportunityType(Base):
    __tablename__ = "opportunity_types"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)

    opportunities: Mapped[list["Opportunity"]] = relationship(
        back_populates="type",
    )


class Opportunity(Base):
    __tablename__ = "opportunities"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    type_id: Mapped[int] = mapped_column(
        ForeignKey("opportunity_types.id"),
        nullable=False,
    )
    author_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    city: Mapped[str] = mapped_column(String(120), nullable=False)
    province: Mapped[str] = mapped_column(String(120), nullable=False)
    event_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    price_amount: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    contact_method: Mapped[str] = mapped_column(String(30), nullable=False)
    contact_value: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="active",
        server_default=text("'active'"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    type: Mapped["OpportunityType"] = relationship(back_populates="opportunities")
    author: Mapped["User"] = relationship(back_populates="opportunities")
    opportunity_instruments: Mapped[list["OpportunityInstrument"]] = relationship(
        back_populates="opportunity",
        cascade="all, delete-orphan",
    )
    opportunity_styles: Mapped[list["OpportunityStyle"]] = relationship(
        back_populates="opportunity",
        cascade="all, delete-orphan",
    )
    favorites: Mapped[list["Favorite"]] = relationship(
        back_populates="opportunity",
        cascade="all, delete-orphan",
    )


class OpportunityStyle(Base):
    __tablename__ = "opportunity_styles"

    opportunity_id: Mapped[int] = mapped_column(
        ForeignKey("opportunities.id"),
        primary_key=True,
    )
    style_id: Mapped[int] = mapped_column(
        ForeignKey("music_styles.id"),
        primary_key=True,
    )

    opportunity: Mapped["Opportunity"] = relationship(back_populates="opportunity_styles")
    style: Mapped["MusicStyle"] = relationship(back_populates="opportunity_styles")


class OpportunityInstrument(Base):
    __tablename__ = "opportunity_instruments"

    opportunity_id: Mapped[int] = mapped_column(
        ForeignKey("opportunities.id"),
        primary_key=True,
    )
    instrument_id: Mapped[int] = mapped_column(
        ForeignKey("instruments.id"),
        primary_key=True,
    )

    opportunity: Mapped["Opportunity"] = relationship(
        back_populates="opportunity_instruments"
    )
    instrument: Mapped["Instrument"] = relationship(
        back_populates="opportunity_instruments"
    )


class Favorite(Base):
    __tablename__ = "favorites"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        primary_key=True,
    )
    opportunity_id: Mapped[int] = mapped_column(
        ForeignKey("opportunities.id"),
        primary_key=True,
    )

    user: Mapped["User"] = relationship(back_populates="favorites")
    opportunity: Mapped["Opportunity"] = relationship(back_populates="favorites")
