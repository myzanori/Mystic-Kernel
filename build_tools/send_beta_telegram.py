#!/usr/bin/env python3
"""Send this workflow's COS beta ZIP to its dedicated Telegram destination."""

import glob
import html
import json
import os
import sys
import urllib.error
import urllib.request
import uuid


MAX_DOCUMENT_BYTES = 50_000_000


def send_document(token: str, chat_id: str, path: str, caption: str) -> None:
    boundary = f"----MysticBeta{uuid.uuid4().hex}"
    filename = os.path.basename(path)
    with open(path, "rb") as source:
        document = source.read()

    fields = [
        ("chat_id", chat_id),
        ("caption", caption),
        ("parse_mode", "HTML"),
    ]
    body = bytearray()
    for name, value in fields:
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        )
        body.extend(value.encode("utf-8"))
        body.extend(b"\r\n")

    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="document"; filename="{filename}"\r\n'.encode()
    )
    body.extend(b"Content-Type: application/zip\r\n\r\n")
    body.extend(document)
    body.extend(f"\r\n--{boundary}--\r\n".encode())

    request = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendDocument",
        data=bytes(body),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Telegram returned HTTP {error.code}: {details}") from None
    except urllib.error.URLError:
        raise SystemExit("Telegram request failed; check runner network and bot settings.") from None

    if not result.get("ok"):
        raise SystemExit(f"Telegram rejected the upload: {result.get('description', 'unknown error')}")
    print(f"Sent {filename} to the beta Telegram chat.")


def main() -> None:
    token = os.environ.get("BETA_TG_TOKEN", "").strip()
    chat_id = os.environ.get("BETA_TG_CHAT", "").strip()
    if not token or not chat_id:
        raise SystemExit("Set repository secrets BETA_TG_TOKEN and BETA_TG_CHAT.")

    archives = glob.glob("release_out/Mystic_*_COS.zip")
    if len(archives) != 1:
        raise SystemExit(f"Expected exactly one COS ZIP, found {len(archives)}.")

    archive = archives[0]
    size = os.path.getsize(archive)
    if size > MAX_DOCUMENT_BYTES:
        raise SystemExit(
            f"COS ZIP is {size} bytes; Telegram Bot API currently accepts documents up to 50 MB."
        )

    version = html.escape(os.environ.get("BETA_VERSION", "beta"))
    commit = html.escape(os.environ.get("BETA_COMMIT", "unknown")[:12])
    branch = html.escape(os.environ.get("BETA_BRANCH", "unknown"))
    run_url = html.escape(os.environ.get("BETA_RUN_URL", ""), quote=True)
    caption = (
        f"<b>Mystic Kernel COS beta {version}</b>\n"
        f"Branch: <code>{branch}</code>\n"
        f"Commit: <code>{commit}</code>"
    )
    if run_url:
        caption += f'\n<a href="{run_url}">Build log</a>'

    send_document(token, chat_id, archive, caption)


if __name__ == "__main__":
    main()
