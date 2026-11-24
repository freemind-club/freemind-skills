#!/usr/bin/env python3
"""Шаг 3. Тексты выбросов: автосубтитры (ru → uk → en) + название/описание/длительность. Видео не скачивается.
python3 texts.py --dir RUN [--min-x 5] [--top 30]
Выход: RUN/outliers_texts.md (вход для разбора моделью). Временные .vtt удаляются."""
import argparse, json, subprocess, re, glob, os
from concurrent.futures import ThreadPoolExecutor
ap = argparse.ArgumentParser(); ap.add_argument("--dir", required=True); ap.add_argument("--min-x", type=float, default=5); ap.add_argument("--top", type=int, default=30)
a = ap.parse_args(); sd = f"{a.dir}/subs"; os.makedirs(sd, exist_ok=True)
res = json.load(open(f"{a.dir}/outliers.json"))
picks = sorted([(r["name"], r["median"], x) for r in res for x in r["items"] if x.get("x", 0) >= a.min_x], key=lambda p: -p[2]["x"])[:a.top]
def get(p):
    vid = p[2]["id"]
    try:
        subprocess.run(["yt-dlp", "--no-update", "--skip-download", "--write-auto-subs", "--write-subs", "--sub-langs", "ru.*,ru,uk,en", "--sub-format", "vtt",
                        "-o", f"{sd}/{vid}.%(ext)s", "--print-to-file", "%(title)s|%(description).300s|%(duration)s", f"{sd}/{vid}.meta", f"https://youtu.be/{vid}"],
                       capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired: pass
with ThreadPoolExecutor(8) as ex: list(ex.map(get, picks))
out = []
for i, (name, med, x) in enumerate(picks, 1):
    vid = x["id"]; fs = sorted(glob.glob(f"{sd}/{vid}*.vtt"), key=lambda f: (0 if ".ru" in f else 1 if ".uk" in f else 2)); txt = ""
    if fs:
        seen = []
        for l in open(fs[0], encoding="utf-8", errors="ignore"):
            l = re.sub(r"<[^>]+>", "", l.strip())
            if l and "-->" not in l and not l.startswith(("WEBVTT", "Kind:", "Language:")) and l not in seen: seen.append(l)
        txt = " ".join(seen)
    meta = open(f"{sd}/{vid}.meta", encoding="utf-8").read().strip() if os.path.exists(f"{sd}/{vid}.meta") else ""
    out.append(f"### {i}. {name} | {x['x']}× к медиане ({x['views']} просм., медиана {int(med)}) | https://youtu.be/{vid}\nМета (название|описание|длительность сек): {meta}\nТекст: {txt[:2500] or 'нет субтитров'}\n")
for f in glob.glob(f"{sd}/*.vtt"): os.remove(f)
open(f"{a.dir}/outliers_texts.md", "w", encoding="utf-8").write("\n".join(out))
print(f"выбросов: {len(picks)}, с текстом: {sum('нет субтитров' not in o for o in out)} → {a.dir}/outliers_texts.md")
