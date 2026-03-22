from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from ..state import AppContext

LogFunc = Callable[[str], None]


@dataclass(slots=True)
class ReleaseAsset:
    name: str
    size: int
    download_url: str


class ReleaseService:
    def __init__(self, context: AppContext) -> None:
        self.context = context

    def repo_slug_from_remote(self, remote_url: str) -> str:
        if remote_url.startswith("git@github.com:") and remote_url.endswith(".git"):
            return remote_url.removeprefix("git@github.com:").removesuffix(".git")
        if remote_url.startswith("https://github.com/"):
            return remote_url.removeprefix("https://github.com/").removesuffix(".git")
        raise RuntimeError(f"Unsupported origin URL: {remote_url or '<missing>'}")

    def _headers(self, *, require_auth: bool = False, content_type: str | None = None) -> dict[str, str]:
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        elif require_auth:
            raise RuntimeError("GITHUB_TOKEN is required for this action.")
        if content_type:
            headers["Content-Type"] = content_type
        return headers

    def _request_json(self, url: str, *, method: str = "GET", data: bytes | None = None, require_auth: bool = False, content_type: str | None = None) -> dict:
        request = urllib.request.Request(url, data=data, method=method, headers=self._headers(require_auth=require_auth, content_type=content_type))
        try:
            with urllib.request.urlopen(request) as response:
                if response.status == 204:
                    return {}
                return json.load(response)
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="ignore")
            raise RuntimeError(f"GitHub API error {exc.code}: {details or exc.reason}") from exc

    def release_status(self, remote_url: str) -> dict[str, object]:
        repo_slug = self.repo_slug_from_remote(remote_url)
        url = f"https://api.github.com/repos/{repo_slug}/releases/tags/{self.context.release_tag}"
        try:
            data = self._request_json(url)
        except RuntimeError as exc:
            return {"status": str(exc), "assets": []}
        assets = [ReleaseAsset(name=asset["name"], size=asset.get("size", 0), download_url=asset.get("browser_download_url", "")) for asset in data.get("assets", [])]
        return {"status": "ok", "assets": assets}

    def _create_archive(self, log: LogFunc | None = None) -> tuple[Path, Path, Path]:
        self.context.cache_dir.mkdir(parents=True, exist_ok=True)
        archive_dir = Path(subprocess.check_output(["mktemp", "-d", str(self.context.cache_dir / "work.XXXXXX")], text=True).strip())
        archive_path = archive_dir / self.context.archive_name
        checksum_path = archive_dir / self.context.checksum_name
        if log:
            log(f"Creating archive at {archive_path}")
        subprocess.run(["tar", "--zstd", "-cf", str(archive_path), "-C", str(self.context.home_dir), "pentest"], check=True)
        checksum_path.write_text(f"{hashlib.sha256(archive_path.read_bytes()).hexdigest()}  {self.context.archive_name}\n", encoding="utf-8")
        return archive_dir, archive_path, checksum_path

    def _ensure_release(self, repo_slug: str) -> dict:
        release_url = f"https://api.github.com/repos/{repo_slug}/releases/tags/{self.context.release_tag}"
        try:
            return self._request_json(release_url, require_auth=True)
        except RuntimeError:
            payload = json.dumps({
                "tag_name": self.context.release_tag,
                "name": "Pentest latest",
                "body": "Latest full pentest snapshot uploaded by the desktop GUI.",
                "draft": False,
                "prerelease": False,
            }).encode("utf-8")
            return self._request_json(f"https://api.github.com/repos/{repo_slug}/releases", method="POST", data=payload, require_auth=True, content_type="application/json")

    def _delete_asset_if_present(self, repo_slug: str, release: dict, asset_name: str) -> None:
        for asset in release.get("assets", []):
            if asset.get("name") == asset_name:
                self._request_json(f"https://api.github.com/repos/{repo_slug}/releases/assets/{asset['id']}", method="DELETE", require_auth=True)
                return

    def _upload_asset(self, upload_url: str, path: Path, content_type: str) -> None:
        request = urllib.request.Request(
            f"{upload_url}?{urllib.parse.urlencode({'name': path.name})}",
            data=path.read_bytes(),
            method="POST",
            headers=self._headers(require_auth=True, content_type=content_type),
        )
        try:
            with urllib.request.urlopen(request):
                return
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="ignore")
            raise RuntimeError(f"GitHub upload failed {exc.code}: {details or exc.reason}") from exc

    def upload_latest_snapshot(self, remote_url: str, log: LogFunc | None = None) -> None:
        repo_slug = self.repo_slug_from_remote(remote_url)
        release = self._ensure_release(repo_slug)
        upload_url = str(release["upload_url"]).split("{", 1)[0]
        archive_dir, archive_path, checksum_path = self._create_archive(log=log)
        try:
            self._delete_asset_if_present(repo_slug, release, self.context.archive_name)
            self._delete_asset_if_present(repo_slug, release, self.context.checksum_name)
            if log:
                log("Uploading pentest archive to GitHub Releases...")
            self._upload_asset(upload_url, archive_path, "application/zstd")
            self._upload_asset(upload_url, checksum_path, "text/plain")
            if log:
                log("Release asset upload complete.")
        finally:
            shutil.rmtree(archive_dir, ignore_errors=True)

    def download_latest_snapshot(self, remote_url: str, log: LogFunc | None = None) -> None:
        repo_slug = self.repo_slug_from_remote(remote_url)
        release = self._request_json(f"https://api.github.com/repos/{repo_slug}/releases/tags/{self.context.release_tag}")
        assets = {asset["name"]: asset["browser_download_url"] for asset in release.get("assets", [])}
        archive_url = assets.get(self.context.archive_name)
        checksum_url = assets.get(self.context.checksum_name)
        if not archive_url or not checksum_url:
            raise RuntimeError("Required pentest release assets were not found.")
        work_dir = self.context.cache_dir / "restore"
        shutil.rmtree(work_dir, ignore_errors=True)
        work_dir.mkdir(parents=True, exist_ok=True)
        archive_path = work_dir / self.context.archive_name
        checksum_path = work_dir / self.context.checksum_name
        if log:
            log("Downloading pentest release assets...")
        urllib.request.urlretrieve(archive_url, archive_path)
        urllib.request.urlretrieve(checksum_url, checksum_path)
        expected_digest = checksum_path.read_text(encoding="utf-8").split()[0]
        actual_digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        if expected_digest != actual_digest:
            raise RuntimeError("Checksum mismatch while restoring pentest archive.")
        extract_dir = work_dir / "extracted"
        extract_dir.mkdir(parents=True, exist_ok=True)
        subprocess.run(["tar", "--zstd", "-xf", str(archive_path), "-C", str(extract_dir)], check=True)
        target_dir = self.context.pentest_dir
        target_dir.mkdir(parents=True, exist_ok=True)
        subprocess.run(["rsync", "-a", "--delete", f"{extract_dir / 'pentest'}/", f"{target_dir}/"], check=True)
        if log:
            log("Pentest workspace restored from GitHub Releases.")