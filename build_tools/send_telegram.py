import os
import glob
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

def main():
    token = os.environ.get('TG_TOKEN', '') or '8076560051:AAEDNzRjLDg-i8zCBnC74voDuG8I2eK3flY'
    chat_id = os.environ.get('TG_CHAT', '') or '-1004359090071'
    tag = os.environ.get('RELEASE_TAG', 'v1.0.30')

    if not token or not chat_id:
        print("Telegram token or chat_id not provided. Skipping Telegram upload.")
        return

    # Look specifically for the single AnyKernel3 zip
    zip_files = glob.glob('release_out/*AnyKernel3.zip')
    if not zip_files:
        zip_files = glob.glob('*AnyKernel3.zip')
    if not zip_files:
        zip_files = glob.glob('ak3/*AnyKernel3.zip')
    if not zip_files:
        print("No release AnyKernel3 zip file found!")
        return

    target_zip = zip_files[0]
    filename = os.path.basename(target_zip)
    file_size_mb = os.path.getsize(target_zip) / (1024 * 1024)
    sha256 = get_sha256(target_zip)

    caption = f"""<b>Mystic Kernel {tag} — OnePlus 9R</b>

• <b>Device</b>: OnePlus 9R (lemonades / LE2101)
• <b>ROM</b>: OxygenOS 14 (Android 14)
• <b>Kernel</b>: 4.19.325-perf-Mystic-9R-myzanori-OOS14-{tag}
• <b>Root &amp; Stealth</b>: ReSukiSU v4.2.0-rc3 + SUSFS v2.3.0
• <b>Camera</b>: 8/8 Sensors Online (PM8008 16-bit fix)
• <b>Torch &amp; WLAN</b>: Triple LED + QCA CLD 3.0 driver
• <b>Tuning</b>: LZ4 ZRAM + Deadline I/O + BBR TCP
• <b>SELinux</b>: Enforcing | <b>Dev</b>: @myzanori

<b>Changelog:</b>
<blockquote>
• Upstreamed to Linux 4.19.325 for OnePlus 9R OOS14
• ReSukiSU + SUSFS v2.3.0 stealth &amp; manager fix
• Fixed PM8008 16-bit regulator parsing for camera rails
• Restored upstream module magic check + force load
• Enforced boot-time LZ4 ZRAM swap for zero jitter
• Deadline I/O scheduler &amp; BBR TCP congestion control
• Embedded high-performance WLAN &amp; schedutil tuning
</blockquote>
<b>SHA-256:</b> <code>{sha256}</code>"""

    print(f"Uploading single file {filename} to Telegram chat {chat_id}...")
    boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
    body = []
    body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="chat_id"\r\n\r\n{chat_id}\r\n')
    body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="parse_mode"\r\n\r\nHTML\r\n')
    body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n')
    body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="document"; filename="{filename}"\r\nContent-Type: application/zip\r\n\r\n')
    
    with open(target_zip, 'rb') as f:
        file_bytes = f.read()
        
    full_body = "".join(body).encode('utf-8') + file_bytes + f'\r\n--{boundary}--\r\n'.encode('utf-8')
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendDocument",
        data=full_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            res_data = resp.read().decode('utf-8')
            print(f"Telegram upload success: {res_data}")
    except Exception as e:
        print(f"Telegram upload error: {e}")
        raise

if __name__ == '__main__':
    main()
