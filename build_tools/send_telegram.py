#!/usr/bin/env python3
import os
import glob
import re
import subprocess
import urllib.request
import urllib.parse
import json
import html

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

    print("Posting release announcement to Telegram...")
    with urllib.request.urlopen(req) as resp:
        res = resp.read().decode("utf-8")
        print("Telegram announcement posted successfully:", res[:120])
        return json.loads(res)

def get_repo_url():
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
    return repo_url

def clean_commit_title(title):
    # Filter out CI, action builds, release bumps, and merge noise
    if re.match(r"^(release|ci|build|chore|merge|bump)(\(.*\))?[:\s]", title, re.I):
        return None
    # Strip conventional commit prefixes (e.g., "fix(tune/display): " or "feat: ")
    cleaned = re.sub(r"^[a-z]+(\([^\)]+\))?:\s*", "", title, flags=re.I).strip()
    if cleaned:
        return cleaned[0].upper() + cleaned[1:]
    return None

def get_user_friendly_changelog():
    # 1. Prefer dedicated RELEASE_CHANGELOG.md if present
    for path in ["RELEASE_CHANGELOG.md", "build_tools/RELEASE_CHANGELOG.md"]:
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read().strip()
                if content:
                    lines = [line.strip() for line in content.splitlines() if line.strip()]
                    # Filter out top-level markdown headers if any
                    body_lines = [l for l in lines if not l.startswith("#")]
                    if body_lines:
                        formatted = []
                        for l in body_lines:
                            if not l.startswith("•") and not l.startswith("-") and not l.startswith("*"):
                                l = f"• {l}"
                            elif l.startswith("- ") or l.startswith("* "):
                                l = f"• {l[2:]}"
                            formatted.append(l)
                        return "\n".join(formatted[:8])
            except Exception:
                pass

    # 2. Extract recent user-facing commits
    try:
        raw_log = subprocess.check_output(
            ["git", "log", "-n", "10", "--pretty=%s"]
        ).decode("utf-8").strip()
        raw_titles = [line.strip() for line in raw_log.splitlines() if line.strip()]
    except Exception:
        raw_titles = []

    cleaned_items = []
    for title in raw_titles:
        cleaned = clean_commit_title(title)
        if cleaned and cleaned not in cleaned_items:
            cleaned_items.append(f"• {html.escape(cleaned)}")
        if len(cleaned_items) >= 6:
            break

    if cleaned_items:
        return "\n".join(cleaned_items)

    # 3. Fallback baseline if no clean commits found
    return (
        "• Performance, memory, and responsiveness optimizations\n"
        "• Battery efficiency and runtime stability improvements\n"
        "• Upstream KernelSU and SUSFS security updates"
    )

def resolve_target_label(filename):
    fn_upper = filename.upper()
    if "COS" in fn_upper:
        return "ColorOS 15"
    if "OOS" in fn_upper:
        return "OxygenOS 11-14"
    return "Universal"

def main():
    token = os.environ.get("TG_TOKEN", "").strip() or "8076560051:AAGg3kH_yCRG9dIHrOwMdO4-m4K9qzD1D6c"
    chat_id = os.environ.get("TG_CHAT", "").strip() or "-1004359090071"

    if not token or not chat_id:
        print("TG_TOKEN or TG_CHAT not configured. Skipping Telegram release upload.")
        return

    # Determine version tag from mystic_version.sh
    tag = os.environ.get("RELEASE_TAG", "")
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
        tag = "v1.0.67.1"

    release_tag_name = f"mystic-{tag}" if not tag.startswith("mystic-") else tag

    # Find Kernel Zip files and sort: ColorOS first, then OxygenOS
    def sort_key(p):
        name = os.path.basename(p).upper()
        if "COS" in name:
            return 1
        if "OOS" in name:
            return 2
        return 3

    zip_files = sorted(glob.glob("release_out/Mystic_*.zip"), key=sort_key)
    if not zip_files:
        zip_files = sorted(glob.glob("release_out/*.zip"), key=sort_key)
    if not zip_files:
        print("No release zip files found in release_out/!")
        return

    repo_url = get_repo_url()
    release_url = f"{repo_url}/releases/tag/{release_tag_name}"

    # Build direct download hyperlinks where the target name itself IS the link
    download_lines = []
    for fp in zip_files:
        fn = os.path.basename(fp)
        target_label = resolve_target_label(fn)
        size_mb = os.path.getsize(fp) / (1024 * 1024)
        download_url = f"{repo_url}/releases/download/{release_tag_name}/{fn}"
        line = f'• <a href="{download_url}"><b>{target_label}</b></a> — <code>{fn}</code> <i>({size_mb:.1f} MB)</i>'
        download_lines.append(line)

    downloads_formatted = "\n".join(download_lines)
    changelog_formatted = get_user_friendly_changelog()
    dev_url = os.environ.get("DEV_URL", "https://github.com/myzanori")

    # Format the single comprehensive release announcement with blockquotes, bold, italics, and monospace
    message_text = f"""<b>Mystic Kernel {tag}</b>

<blockquote><i>High-performance, battery-efficient custom kernel for OnePlus 8T / 9R (Kona SM8250).</i></blockquote>

<b>Developer:</b> <a href="{dev_url}">myzanori</a>
<b>Supported Devices:</b> <code>OnePlus 8T / 9R (kebab/lemonades)</code>
<b>Root Manager:</b> <a href="https://t.me/mystickernel9r/95">BakaSU</a> | <code>KernelSU + SUSFS v2.4.0</code>

<b>Changelog:</b>
<blockquote>
{changelog_formatted}
</blockquote>

<b>Downloads:</b>
{downloads_formatted}

<a href="{release_url}"><i>View Release & All Assets on GitHub</i></a>

<b>Credits:</b>
• <i>Jack</i>
• <i>Troops</i>
• <i>Testers:</i> @Vickymaxwin"""

    send_message(token, chat_id, message_text)
    print("Telegram release post process completed successfully.")

if __name__ == "__main__":
    main()
