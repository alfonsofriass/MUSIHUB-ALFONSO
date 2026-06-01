from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

IMAGE_MAX_BYTES = 5 * 1024 * 1024


def _detect_image_extension(content: bytes) -> str | None:
    if content.startswith(b"\xff\xd8\xff"):
        return ".jpg"

    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"

    if content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return ".webp"

    return None


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

    extension = _detect_image_extension(content)
    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format",
        )

    upload_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{filename_prefix}_{uuid4().hex}{extension}"
    image_path = upload_dir / filename
    image_path.write_bytes(content)

    return f"/{image_path.as_posix()}"
