import os
import glob
import subprocess
import urllib.request
import urllib.parse
import json
import html

def send_document(token, chat_id, filepath, caption=None):
    boundary = "----WebKitFormBoundaryTelegramUpload"
    fname = os.path.basename(filepath)
    with open(filepath, "rb") as f:
        file_bytes = f.read()

    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{chat_id}\r\n".encode("utf-8"),
    ]
    if caption:
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n{caption}\r\n".encode("utf-8"))
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"parse_mode\"\r\n\r\nHTML\r\n".encode("utf-8"))

    parts.extend([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"document\"; filename=\"{fname}\"\r\nContent-Type: application/zip\r\n\r\n".encode("utf-8"),
        file_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode("utf-8"),
    ])
    full_body = b"".join(parts)

    print(f"Uploading {fname} ({len(file_bytes) / (1024 * 1024):.2f} MB) to Telegram...")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendDocument",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )

    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print(f"Telegram document upload success ({fname}):", res[:120])
        return json.loads(res)

def send_message(token, chat_id, text):
    data = json.dumps({
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }).encode("utf-8")

    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=data,
        headers={"Content-Type": "application/json"}
    )

    print("Sending release text message to Telegram...")
    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram text message success:", res[:120])
        return json.loads(res)

def get_commit_url():
    commit_hash = os.environ.get("GITHUB_SHA", "")
    if not commit_hash:
        try:
            commit_hash = subprocess.check_output(
                ["git", "rev-parse", "HEAD"]
            ).decode().strip()
        except Exception:
            commit_hash = ""

    repo_url = "https://github.com/myzanori/Mystic-Kernel"
    try:
        remote_url = subprocess.check_output(
            ["git", "config", "--get", "remote.origin.url"]
        ).decode().strip()
        if "github.com" in remote_url:
            clean = remote_url.replace("git@github.com:", "https://github.com/")
            if clean.endswith(".git"):
                clean = clean[:-4]
            if clean.startswith("https://github.com/"):
                repo_url = clean
    except Exception:
        pass

    if commit_hash:
        return f"{repo_url}/commit/{commit_hash}"
    return f"{repo_url}/commits"

def get_changelog_3_lines():
    try:
        body = subprocess.check_output(["git", "log", "-1", "--pretty=%b"]).decode("utf-8").strip()
        subject = subprocess.check_output(["git", "log", "-1", "--pretty=%s"]).decode("utf-8").strip()
    except Exception:
        body = ""
        subject = ""

    lines = []
    if body:
        for line in body.splitlines():
            line = line.strip()
            if not line:
                continue
            if line.startswith("Signed-off-by:") or line.startswith("Co-authored-by:"):
                continue
            if line.startswith("- ") or line.startswith("* "):
                line = line[2:].strip()
            lines.append(line)

    if not lines and subject:
        lines.append(subject)

    return lines[:3]

def resolve_target_name(fname):
    fname_upper = fname.upper()
    if 'COS' in fname_upper:
        return 'ColorOS 15-17'
    if 'AOSP' in fname_upper:
        return 'AOSP'
    if 'OOS' in fname_upper:
        return 'OxygenOS 11-14'
    return 'Universal'

def main():
    token = os.environ.get('TG_TOKEN', '').strip()
    chat_id = os.environ.get('TG_CHAT', '').strip()

    if not token or not chat_id:
        print("TG_TOKEN or TG_CHAT not configured in environment/secrets. Skipping Telegram release upload.")
        return

    # Determine version tag from mystic_version.sh
    tag = os.environ.get('RELEASE_TAG', '')
    if not tag:
        try:
            val = subprocess.check_output(
                ["bash", "-c", ". ./mystic_version.sh >/dev/null 2>&1 && echo $MYSTIC_VERSION"]
            ).decode().strip()
            if val:
                tag = f"v{val}"
        except Exception:
            pass
    if not tag:
        tag = 'v1.0.62'

    # Find Kernel Zip files and sort by: ColorOS, AOSP, OxygenOS
    def sort_key(p):
        name = os.path.basename(p).upper()
        if "COS" in name:
            return 1
        if "AOSP" in name:
            return 2
        if "OOS" in name:
            return 3
        return 4

    zip_files = sorted(glob.glob('release_out/Mystic_*.zip'), key=sort_key)
    if not zip_files:
        zip_files = sorted(glob.glob('release_out/*.zip'), key=sort_key)
    if not zip_files:
        print("No release zip files found in release_out/!")
        return

    # 1. Send all files separately first
    print(f"Sending {len(zip_files)} files separately to Telegram...")
    for fp in zip_files:
        fn = os.path.basename(fp)
        tgt = resolve_target_name(fn)
        file_caption = f"<b>Target:</b> {tgt}"
        send_document(token, chat_id, fp, caption=file_caption)

    # 2. Extract commit info and 3-line changelog
    commit_url = get_commit_url()
    changelog_items = get_changelog_3_lines()
    changelog_formatted = "\n".join(f"• {html.escape(item)}" for item in changelog_items)

    dev_url = os.environ.get("DEV_URL", "https://github.com/myzanori")

    # 3. Format text message without file names
    message_text = f"""<b>Mystic Kernel {tag}</b>

<b>Developer:</b> <a href="{dev_url}">myzanori</a>
<b>Supported Devices:</b> OnePlus 9R / 8T
<b>Root manager:</b> <a href="https://t.me/mystickernel9r/95">BakaSU</a>

<b>Changelog:</b>
{changelog_formatted}

<a href="{commit_url}">More changelog...</a>"""

    # 4. Send text message
    send_message(token, chat_id, message_text)
    print("Telegram release post process completed successfully.")

if __name__ == '__main__':
    main()
