from pathlib import Path
import logging
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from app.config import settings

IMAGE_MAX_BYTES = 5 * 1024 * 1024
logger = logging.getLogger(__name__)


def _detect_image_metadata(content: bytes) -> tuple[str, str] | None:
    if content.startswith(b"\xff\xd8\xff"):
        return ".jpg", "image/jpeg"

    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png", "image/png"

    if content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return ".webp", "image/webp"

    return None


def _clean_setting(value: str | None) -> str | None:
    if value is None:
        return None

    cleaned_value = value.strip()
    return cleaned_value or None


def _get_supabase_storage_settings() -> tuple[str, str, str] | None:
    supabase_url = _clean_setting(settings.supabase_url)
    service_role_key = _clean_setting(settings.supabase_service_role_key)
    bucket = _clean_setting(settings.supabase_storage_bucket)

    if not supabase_url or not service_role_key or not bucket:
        return None

    return supabase_url.rstrip("/"), service_role_key, bucket


def _storage_folder_for_upload_dir(upload_dir: Path) -> str:
    parts = upload_dir.as_posix().split("/")
    if parts and parts[0] == "uploads":
        parts = parts[1:]

    return "/".join(part for part in parts if part)


def _upload_to_supabase_storage(
    *,
    content: bytes,
    content_type: str,
    object_path: str,
) -> str:
    supabase_settings = _get_supabase_storage_settings()
    if supabase_settings is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Supabase Storage is not configured",
        )

    supabase_url, service_role_key, bucket = supabase_settings
    encoded_object_path = quote(object_path, safe="/")
    encoded_bucket = quote(bucket, safe="")

    upload_url = (
        f"{supabase_url}/storage/v1/object/{encoded_bucket}/{encoded_object_path}"
    )
    public_url = (
        f"{supabase_url}/storage/v1/object/public/"
        f"{encoded_bucket}/{encoded_object_path}"
    )
    request = Request(
        upload_url,
        data=content,
        method="POST",
        headers={
            "Authorization": f"Bearer {service_role_key}",
            "apikey": service_role_key,
            "Content-Type": content_type,
            "Cache-Control": "3600",
        },
    )

    try:
        with urlopen(request, timeout=15) as response:
            if response.status >= 400:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Could not upload image",
                )
    except HTTPError as exc:
        error_body = exc.read(500).decode("utf-8", errors="replace")
        logger.warning(
            "Supabase Storage upload failed: status=%s reason=%s body=%s",
            exc.code,
            exc.reason,
            error_body,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not upload image",
        ) from exc
    except (URLError, TimeoutError, ValueError) as exc:
        logger.warning("Supabase Storage upload failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not upload image",
        ) from exc

    return public_url


def save_uploaded_image(
    *,
    file: UploadFile,
    upload_dir: Path,
    filename_prefix: str,
) -> str:
    content = file.file.read(IMAGE_MAX_BYTES + 1)
    if len(content) > IMAGE_MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image is too large",
        )

    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image is empty",
        )

    image_metadata = _detect_image_metadata(content)
    if image_metadata is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format",
        )

    extension, content_type = image_metadata
    filename = f"{filename_prefix}_{uuid4().hex}{extension}"

    if _get_supabase_storage_settings() is not None:
        storage_folder = _storage_folder_for_upload_dir(upload_dir)
        object_path = f"{storage_folder}/{filename}" if storage_folder else filename
        return _upload_to_supabase_storage(
            content=content,
            content_type=content_type,
            object_path=object_path,
        )

    upload_dir.mkdir(parents=True, exist_ok=True)
    image_path = upload_dir / filename
    image_path.write_bytes(content)

    return f"/{image_path.as_posix()}"
