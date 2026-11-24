#!/usr/bin/env python3
"""Шаг 2. Медиана и выбросы по шортсам. × = просмотры ÷ медиана 15 шортсов автора (2 самых свежих пропускаются).
python3 outliers.py --dir RUN [--channels RUN/channels.txt] [--limit 40] [--min-x 5] [--tab shorts|videos]
Выход: RUN/outliers.json, RUN/outliers_table.md."""
import argparse, json, subprocess, statistics
from concurrent.futures import ThreadPoolExecutor
ap = argparse.ArgumentParser(); ap.add_argument("--dir", required=True); ap.add_argument("--channels"); ap.add_argument("--limit", type=int, default=40)
ap.add_argument("--min-x", type=float, default=5); ap.add_argument("--tab", default="shorts")
a = ap.parse_args(); chf = a.channels or f"{a.dir}/channels.txt"
CH = [l.strip().split("|")[:2] for l in open(chf, encoding="utf-8") if "|" in l and not l.startswith("#")]
def run(c):
    name, url = c[0].strip(), c[1].strip().rstrip("/")
    try:
        r = subprocess.run(["yt-dlp", "--no-update", "--flat-playlist", "--playlist-end", str(a.limit), "-j", f"{url}/{a.tab}"], capture_output=True, text=True, timeout=200)
        lines = r.stdout.splitlines()
    except subprocess.TimeoutExpired:
        lines = []
    v = []
    for l in lines:
        try: d = json.loads(l)
        except ValueError: continue
        v.append({"id": d["id"], "title": d.get("title", ""), "views": d.get("view_count") or 0})
    if len(v) < 8: return {"name": name, "url": url, "n": len(v), "median": None, "items": v}
    med = statistics.median([x["views"] for x in v[2:17]]) or 1
    for x in v: x["x"] = round(x["views"] / med, 1)
    return {"name": name, "url": url, "n": len(v), "median": med, "items": v}
with ThreadPoolExecutor(6) as ex: res = list(ex.map(run, CH))
json.dump(res, open(f"{a.dir}/outliers.json", "w"), ensure_ascii=False, indent=1)
rows = ["| Канал | Шортсов | Медиана | Выбросов ≥%g× | Топ-3 |" % a.min_x, "|---|---|---|---|---|"]
for r in sorted(res, key=lambda r: -max([x.get("x", 0) for x in r["items"]] or [0])):
    top = sorted([x for x in r["items"] if x.get("x", 0) >= a.min_x], key=lambda x: -x["x"])
    med = int(r["median"]) if r["median"] else "мало шортсов"
    rows.append(f"| {r['name']} | {r['n']} | {med} | {len(top)} | " + ", ".join(f"[{x['x']}×](https://youtu.be/{x['id']})" for x in top[:3]) + " |")
open(f"{a.dir}/outliers_table.md", "w", encoding="utf-8").write("\n".join(rows) + "\n")
tot = sum(1 for r in res for x in r["items"] if x.get("x", 0) >= a.min_x)
print(f"каналов: {len(res)}, выбросов ≥{a.min_x}×: {tot} → {a.dir}/outliers_table.md")
