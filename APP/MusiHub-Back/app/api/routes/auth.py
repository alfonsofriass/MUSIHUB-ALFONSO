from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Role, User, UserRole
from app.roles import RoleCode
from app.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/auth")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

#SCHEMAS
class RegisterRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=120)
    role: RoleCode


class RegisterResponse(BaseModel):
    email: EmailStr
    full_name: str
    role: RoleCode
    message: str


class LoginRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str


class MeResponse(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    role: RoleCode

#ENDPOINTS

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = decode_access_token(token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        ) from exc

    subject = payload.get("sub")
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    try:
        user_id = int(subject)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        ) from exc

    user = db.scalar(
        select(User).where(User.id == user_id)
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    return user


#REGISTER
@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db),
) -> RegisterResponse:
    existing_user = db.scalar(
        select(User).where(User.email == payload.email)
    )

    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    role = db.scalar(
        select(Role).where(Role.code == payload.role.value)
    )

    if role is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid role",
        )

    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
    )

    db.add(user)
    db.flush()

    db.add(
        UserRole(
            user_id=user.id,
            role_id=role.id,
            is_primary=True,
        )
    )

    db.commit()

    return RegisterResponse(
        email=user.email,
        full_name=user.full_name,
        role=payload.role,
        message="User registered",
    )

#LOGIN
@router.post("/login", response_model=LoginResponse)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
) -> LoginResponse:
    user = db.scalar(
        select(User).where(User.email == payload.email)
    )

    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    return LoginResponse(
        access_token=create_access_token(subject=str(user.id)),
        token_type="bearer",
    )


#ME
@router.get("/me", response_model=MeResponse)
def read_me(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    role = db.scalar(
        select(Role)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(
            UserRole.user_id == user.id,
            UserRole.is_primary.is_(True),
        )
    )

    if role is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User role not found",
        )

    return MeResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=RoleCode(role.code),
    )
