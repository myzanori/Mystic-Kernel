import os
import glob
import subprocess
import urllib.request
import urllib.parse
import json
import hashlib

def get_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def send_single_post_release(token, chat_id, files_with_types, caption):
    boundary = "----WebKitFormBoundaryMediaGroup9R8T"
    media_json = []

    for i, (fp, ctype) in enumerate(files_with_types):
        item = {
            "type": "document",
            "media": f"attach://file{i}"
        }
        if i == 0:
            item["caption"] = caption
            item["parse_mode"] = "HTML"
        media_json.append(item)

    parts = []
    parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{chat_id}\r\n".encode("utf-8"))
    parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"media\"\r\n\r\n{json.dumps(media_json)}\r\n".encode("utf-8"))

    for i, (fp, ctype) in enumerate(files_with_types):
        fname = os.path.basename(fp)
        header = f"--{boundary}\r\nContent-Disposition: form-data; name=\"file{i}\"; filename=\"{fname}\"\r\nContent-Type: {ctype}\r\n\r\n".encode("utf-8")
        with open(fp, "rb") as f:
            content = f.read()
        parts.append(header + content + b"\r\n")

    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    full_body = b"".join(parts)

    print(f"Sending all release files in a single post media group ({len(full_body)/(1024*1024):.2f} MB)...")
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMediaGroup",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )

    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram upload success (Single Post):", res[:120])
        return json.loads(res)

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
        tag = 'v1.0.38'

    if not token or not chat_id:
        print("Telegram token or chat_id not provided. Skipping Telegram upload.")
        return

    # 1. Kernel AnyKernel3 Zip
    zip_files = glob.glob(f'release_out/*{tag}*AnyKernel3.zip')
    if not zip_files:
        zip_files = glob.glob('release_out/*AnyKernel3.zip')
    if not zip_files:
        print("No release AnyKernel3 zip file found!")
        return
    kernel_zip = zip_files[0]

    # 2. ReSukiSU Root Manager APK
    apk_files = glob.glob('release_out/ReSukiSU_v4.2.0-rc3_35184*.apk')
    if not apk_files:
        apk_files = glob.glob('release_out/*.apk')
    if not apk_files:
        print("No ReSukiSU APK found!")
        return
    resukisu_apk = apk_files[0]

    # 3. Logger Module Zip
    logger_files = glob.glob('release_out/Logger_v*.zip')
    if not logger_files:
        logger_files = glob.glob('/home/myzanori/Desktop/projects/Oneplus_9R/Mystic_Releases/Logger_v*.zip')
    if not logger_files:
        print("No Logger module zip found!")
        return
    logger_zip = logger_files[0]

    rom = os.environ.get('MYSTIC_ROM', '')
    if not rom:
        try:
            rom = subprocess.check_output(
                ["bash", "-c", ". ./mystic_version.sh >/dev/null 2>&1 && echo $MYSTIC_ROM"]
            ).decode().strip()
        except Exception:
            pass
    if not rom:
        rom = "ColorOS 15"

    files_with_types = [
        (kernel_zip, "application/zip"),
        (resukisu_apk, "application/vnd.android.package-archive"),
        (logger_zip, "application/zip")
    ]

    caption = f"""🔥 <b>MYSTIC KERNEL {tag} — {rom.upper()}</b> 🔥
• <b>Devices</b>: OnePlus 9R &amp; OnePlus 8T
• <b>ROM Target</b>: {rom}
• <b>Kernel</b>: 4.19.325-perf-Mystic-Kona-myzanori-{tag}
• <b>Root &amp; Stealth</b>: ReSukiSU (35184) + SUSFS v2.3.0 Stable
• <b>Tuning</b>: LZ4 ZRAM + Balanced Writeback + BBR TCP

<b>Changelog:</b>
<blockquote>
• <b>AnyKernel3 Fix:</b> Multi-source recovery slot detection (fixes Error 1 on TWRP/OrangeFox/ColorOS 15)
• <b>NoMount Soft Reboot Fix:</b> Completely disabled VFS dentry hijacking to guarantee rock-solid framework stability
• <b>7 Stock OEM Subsystems:</b> Horae shell thermal zones (front/frame/back), death healer hung-task recovery, ALS/pressure calibration, UFS 3.1 health tracking
• <b>Memory &amp; Swap Safety:</b> Removed intrusive boot-time swapoff to prevent memory allocation panics
• <b>Performance &amp; Battery:</b> Restored balanced writeback, relaxed dirty expiry, and smooth schedutil latency
</blockquote>
📦 <b>Attached in this Single Post:</b>
1. Kernel AnyKernel3 Zip
2. ReSukiSU Manager App (APK)
3. Logger Module v1.2 Zip
👨‍💻 <b>Dev</b>: @myzanori | 💬 <b>Channel</b>: @mystickernel9r"""

    send_single_post_release(token, chat_id, files_with_types, caption)
    print("\n✅ Single post media group release successfully broadcast to Telegram!")

if __name__ == '__main__':
    main()
