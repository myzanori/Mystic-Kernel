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
    token = os.environ.get('TG_TOKEN', '')
    chat_id = os.environ.get('TG_CHAT', '')
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

• <b>Device</b>: OnePlus 9R (lemonades / LE2101) [Kona SM8250]
• <b>ROM</b>: OxygenOS 14 (Android 14)
• <b>Kernel</b>: Linux 4.19.325-perf-Mystic-9R-myzanori-OOS14-{tag}
• <b>Format</b>: Flashable AnyKernel3 Zip ({file_size_mb:.1f} MB)
• <b>Root</b>: ReSukiSU v4.2.0-rc3 (Inline hooks)
• <b>Stealth</b>: SUSFS v2.3.0 (Kernel-side stealth)
• <b>Camera</b>: 8/8 Sensors Operational (PM8008 16-bit fix)
• <b>Torch</b>: Triple LED operational
• <b>Memory</b>: Active LZ4 ZRAM compression
• <b>I/O Scheduler</b>: Deadline (Zero UI stutter)
• <b>TCP Congestion</b>: BBR + FQ-CoDel
• <b>SELinux</b>: Enforcing
• <b>Developer</b>: @myzanori

<b>Changelog:</b>
<blockquote>
• Upstreamed to Linux 4.19.325
• Built specifically for OnePlus 9R on OxygenOS 14
• ReSukiSU v4.2.0-rc3 with inline syscall hooks &amp; dynamic manager permission fix
• SUSFS v2.3.0 with complete stealth hiding support
• PM8008 16-bit regulator DT parsing refinement: all 7 camera LDO rails online
• Flashlight / torch all 3 channels functional
• Upstream module.c version magic verification preserved + MODULE_FORCE_LOAD enabled
• Enforced LZ4 compression on ZRAM swap at boot
• Deadline I/O scheduler &amp; BBR TCP congestion control by default
• High-performance WLAN driver (qcacld-3.0) &amp; schedutil rate-limit tuning
</blockquote>

<b>SHA-256:</b>
<code>{sha256}</code>"""

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
