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

    print(f"Sending zip files as media group ({len(full_body) / (1024 * 1024):.2f} MB)...")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMediaGroup",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )

    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram upload success:", res[:120])
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

    repo_url = "https://github.com/myzanori/android_kernel_oneplus_sm8250_los_noksu"
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

def main():
    token = os.environ.get('TG_TOKEN', '') or '8076560051:AAGg3kH_yCRG9dIHrOwMdO4-m4K9qzD1D6c'
    chat_id = os.environ.get('TG_CHAT', '') or '-1004359090071'

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
        tag = 'v1.0.55'

    if not token or not chat_id:
        print("Telegram token or chat_id not provided. Skipping Telegram upload.")
        return

    # Find Kernel AnyKernel3 Zip files only
    zip_files = sorted(glob.glob('release_out/*AnyKernel3.zip'))
    if not zip_files:
        print("No release AnyKernel3 zip file found!")
        return

    commit_url = get_commit_url()

    # Determine target list based on found zips
    targets = []
    for z in zip_files:
        base = os.path.basename(z)
        if "COS" in base:
            targets.append("ColorOS 15-17")
        elif "OOS" in base:
            targets.append("OxygenOS 11-14")
    target_str = " & ".join(targets) if targets else "SM8250 Kona"

    # Clean caption: name and version number, developer info, targets, changelog link, strictly no emojis
    caption = f"""<b>Mystic Kernel {tag}</b>

Developer: myzanori (@myzanori)
Targets: {target_str}

Changelog: {commit_url}"""

    if len(zip_files) == 1:
        send_document(token, chat_id, zip_files[0], caption)
    else:
        send_media_group(token, chat_id, zip_files, caption)

    print("Telegram post completed successfully.")

if __name__ == '__main__':
    main()
