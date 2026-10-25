import os
import glob
import subprocess
import urllib.request
import urllib.parse
import json

def send_document(token, chat_id, filepath, caption):
    boundary = "----WebKitFormBoundaryTelegramUpload"
    fname = os.path.basename(filepath)
    with open(filepath, "rb") as f:
        file_bytes = f.read()

    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{chat_id}\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n{caption}\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"parse_mode\"\r\n\r\nHTML\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"document\"; filename=\"{fname}\"\r\nContent-Type: application/zip\r\n\r\n".encode("utf-8"),
        file_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode("utf-8"),
    ]
    full_body = b"".join(parts)

    print(f"Uploading {fname} ({len(file_bytes) / (1024 * 1024):.2f} MB) to Telegram...")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendDocument",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )

    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram upload success:", res[:120])
        return json.loads(res)

def send_media_group(token, chat_id, zip_files, caption):
    boundary = "----WebKitFormBoundaryMediaGroupZip"
    media_json = []

    for i, fp in enumerate(zip_files):
        item = {
            "type": "document",
            "media": f"attach://file{i}"
        }
        if i == 0:
            item["caption"] = caption
            item["parse_mode"] = "HTML"
        media_json.append(item)

    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{chat_id}\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"media\"\r\n\r\n{json.dumps(media_json)}\r\n".encode("utf-8"),
    ]

    for i, fp in enumerate(zip_files):
        fname = os.path.basename(fp)
        header = f"--{boundary}\r\nContent-Disposition: form-data; name=\"file{i}\"; filename=\"{fname}\"\r\nContent-Type: application/zip\r\n\r\n".encode("utf-8")
        with open(fp, "rb") as f:
            content = f.read()
        parts.append(header + content + b"\r\n")

    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    full_body = b"".join(parts)

    print(f"Sending {len(zip_files)} zip files as single media group ({len(full_body) / (1024 * 1024):.2f} MB)...")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMediaGroup",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )

    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram media group upload success:", res[:120])
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

def resolve_target_name(fname):
    fname_upper = fname.upper()
    if 'COS' in fname_upper:
        return 'ColorOS'
    if 'AOSP' in fname_upper:
        return 'AOSP'
    if 'OOS' in fname_upper:
        return 'OxygenOS'
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
        tag = 'v1.0.56'

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

    commit_url = get_commit_url()

    # Format caption with explicit ROM target and exact zip filename(s)
    if len(zip_files) == 1:
        fname = os.path.basename(zip_files[0])
        tgt = resolve_target_name(fname)
        caption = f"""<b>Mystic Kernel {tag}</b>

Developer: myzanori (@myzanori)
Target: {tgt}
Devices: OnePlus 9R / 8T / 8 / 8 Pro
File: <code>{fname}</code>

Changelog: {commit_url}"""
    else:
        file_lines = []
        for z in zip_files:
            fn = os.path.basename(z)
            t = resolve_target_name(fn)
            file_lines.append(f"• <b>{t}</b>: <code>{fn}</code>")
        files_block = "\n".join(file_lines)
        caption = f"""<b>Mystic Kernel {tag}</b>

Developer: myzanori (@myzanori)
Devices: OnePlus 9R / 8T / 8 / 8 Pro

Files:
{files_block}

Changelog: {commit_url}"""

    if len(zip_files) == 1:
        send_document(token, chat_id, zip_files[0], caption)
    else:
        send_media_group(token, chat_id, zip_files, caption)

    print("Telegram post completed successfully.")

if __name__ == '__main__':
    main()
