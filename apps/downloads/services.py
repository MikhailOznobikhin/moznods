"""Service layer for distributable artifacts (APK, etc.)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from django.conf import settings


APK_FILENAME = "moznods.apk"
APK_DOWNLOAD_NAME = "moznods.apk"
APK_VERSION = "1.0.0"


def _candidate_paths() -> list[Path]:
    media_root = Path(settings.MEDIA_ROOT)
    base_dir = Path(settings.BASE_DIR)
    return [
        media_root / "downloads" / APK_FILENAME,
        base_dir / "moznods_flutter" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk",
        base_dir / "moznods_flutter" / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk",
    ]


def find_apk_path() -> Path | None:
    """Return the first existing APK path, or None if no local build is published."""
    for candidate in _candidate_paths():
        if candidate.exists() and candidate.is_file():
            return candidate
    return None


def get_external_apk_url() -> str | None:
    """Return a public URL (e.g. GitHub Release) for the APK if configured."""
    return getattr(settings, "APK_RELEASE_URL", None) or None


@dataclass
class ApkInfo:
    available: bool
    size: int | None = None
    modified: str | None = None
    version: str | None = None
    filename: str | None = None
    external_url: str | None = None

    def to_dict(self) -> dict:
        return {
            "available": self.available,
            "size": self.size,
            "modified": self.modified,
            "version": self.version,
            "filename": self.filename,
            "external_url": self.external_url,
        }


def get_apk_info() -> ApkInfo:
    path = find_apk_path()
    if path is not None:
        stat = path.stat()
        modified_iso = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat()
        return ApkInfo(
            available=True,
            size=stat.st_size,
            modified=modified_iso,
            version=APK_VERSION,
            filename=APK_DOWNLOAD_NAME,
        )

    external = get_external_apk_url()
    if external:
        return ApkInfo(
            available=True,
            version=APK_VERSION,
            filename=APK_DOWNLOAD_NAME,
            external_url=external,
        )

    return ApkInfo(available=False)
