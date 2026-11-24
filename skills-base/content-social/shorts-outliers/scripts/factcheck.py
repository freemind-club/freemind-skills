#!/usr/bin/env python3
"""Шаг 5. Проверка фактов в разделах 3–4 разбора: каждая цифра рядом с %, ₽, ×, «тыс», «млн», сроками и т. п. должна быть в блоке ФАКТОВ задания.
python3 factcheck.py --task RUN/task.md --analysis RUN/analysis_raw.md
Печатает подозрительные строки. Их правит Claude руками до выдачи. Общие ориентиры (удержание >60%) — не ошибка, пометить «общий ориентир»."""
import argparse, re
ap = argparse.ArgumentParser(); ap.add_argument("--task", required=True); ap.add_argument("--analysis", required=True); a = ap.parse_args()
join = lambda s: re.sub(r"(\d)[  ](\d{3})", r"\1\2", s)
t = open(a.task, encoding="utf-8").read()
facts = t.split("ФАКТЫ КЛИЕНТА", 1)[1].split("Правила:", 1)[0] if "ФАКТЫ КЛИЕНТА" in t else t
fnums = {n.replace(",", ".") for n in re.findall(r"\d+(?:[.,]\d+)?", join(facts))}
s = open(a.analysis, encoding="utf-8").read()
part = s[s.find("\n## 3."):] if "\n## 3." in s else s
pat = re.compile(r"\d+(?:[.,]\d+)?(?=\s*(?:%|₽|×|x\b|к\b|тыс|млн|дн|недел|месяц|час|мин|звон|клиент|руб|заяв|сдел))")
bad = 0
for line in part.splitlines():
    if "общий ориентир" in line or "выдуманные детали" in line: continue
    miss = [n for n in pat.findall(join(line)) if n.replace(",", ".") not in fnums]
    if miss:
        bad += 1; print(f"⚠️ {miss}: {line.strip()[:220]}")
print(f"подозрительных строк: {bad}")
