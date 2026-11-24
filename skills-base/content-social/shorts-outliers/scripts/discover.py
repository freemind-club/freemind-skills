#!/usr/bin/env python3
"""Шаг 1. Поиск каналов по нише: запросы → YouTube-поиск (yt-dlp) → каналы, отсортированные по частоте.
python3 discover.py --dir RUN --queries queries.txt [--per 25]
Выход: RUN/channels_found.json, RUN/channels_candidates.txt (имя|url, по убыванию частоты)."""
import argparse, json, subprocess, collections, os
ap = argparse.ArgumentParser(); ap.add_argument("--dir", required=True); ap.add_argument("--queries", required=True); ap.add_argument("--per", type=int, default=25)
a = ap.parse_args(); os.makedirs(a.dir, exist_ok=True)
Q = [l.strip() for l in open(a.queries, encoding="utf-8") if l.strip() and not l.startswith("#")]
ch = collections.defaultdict(lambda: {"n": 0, "views": [], "name": ""})
for q in Q:
    try:
        r = subprocess.run(["yt-dlp", "--no-update", "--flat-playlist", "-j", f"ytsearch{a.per}:{q}"], capture_output=True, text=True, timeout=150)
    except subprocess.TimeoutExpired:
        print("timeout:", q); continue
    for l in r.stdout.splitlines():
        try: d = json.loads(l)
        except ValueError: continue
        u = d.get("channel_url") or d.get("uploader_url")
        if not u: continue
        c = ch[u]; c["n"] += 1; c["name"] = d.get("channel") or d.get("uploader") or ""; c["views"].append(d.get("view_count") or 0)
    print("ok:", q)
out = sorted(ch.items(), key=lambda x: (-x[1]["n"], -max(x[1]["views"] or [0])))
json.dump([{"url": u, **v} for u, v in out], open(f"{a.dir}/channels_found.json", "w"), ensure_ascii=False, indent=1)
with open(f"{a.dir}/channels_candidates.txt", "w", encoding="utf-8") as f:
    for u, v in out: f.write(f"{v['name'].replace('|', '/')}|{u}|встреч={v['n']} макс={max(v['views'] or [0])}\n")
print(f"каналов: {len(out)} → {a.dir}/channels_candidates.txt (оставь подходящие в channels.txt)")
