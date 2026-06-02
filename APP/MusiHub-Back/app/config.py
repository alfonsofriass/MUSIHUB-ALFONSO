from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "MusiHub API"
    secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    database_url: str
    push_notifications_enabled: bool = False
    firebase_credentials_path: str | None = None
    firebase_project_id: str | None = None


settings = Settings()
