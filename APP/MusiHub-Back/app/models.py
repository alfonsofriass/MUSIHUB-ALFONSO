from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func, text
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
