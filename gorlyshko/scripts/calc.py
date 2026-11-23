#!/usr/bin/env python3
"""Горлышко: счёт формулы прибыли по карточке. Только стандартная библиотека, без сети.

Использование:
  python3 calc.py --card карточка.csv                 # карточка урока (CSV из Google-таблицы)
  python3 calc.py --json '{"leads":40,"conv":20,"check":4000,"repeats":3,"margin":80}'
  python3 calc.py --card now.csv --prev before.csv    # pro: динамика к прошлому периоду
  доп.: --target-month 150000  (цель прибыли в месяц; иначе = «хотел за год» / 12)
        --ready-min 5         (порог часов в неделю на изменения, по умолчанию 5)

Выход — JSON. Модель НЕ пересчитывает цифры сама, а берёт их отсюда.
"""
import argparse, csv, json, re, sys

FIELDS = {  # ключ -> слова в колонке «Вопрос» карточки
    "earning": ["зарабатываю на этом"],
    "study_spent": ["на обучение и курсы"],
    "study_back": ["обучение вернуло"],
    "directions": ["услуг и направлений"],
    "hours_client": ["на клиента (сессии"],
    "hours_around": ["вокруг клиента"],
    "hours_self": ["на себя (курсы"],
    "earned_year": ["заработал в этом году"],
    "wanted_year": ["хотел заработать"],
    "promo_spent": ["вложил в продвижение"],
    "promo_back": ["это вернуло"],
    "payments": ["заплатили за прошлый"],
    "revenue": ["выручка за прошлый"],
    "costs": ["расходы за прошлый"],
    "leads": ["заявки"],
    "conv": ["конверсия"],
    "check": ["средний чек"],
    "repeats": ["повторные"],
    "margin": ["маржа"],
    "hours_not_client": ["часов в неделю не на клиента"],
    "ready_hours": ["готов уделять"],
}
READY_MIN = 5  # часов в неделю на изменения — меньше: первое горлышко «нет времени»
MULT = ["leads", "conv", "check", "repeats", "margin"]
NAMES = {"leads": "заявки", "conv": "конверсия", "check": "средний чек",
         "repeats": "повторы", "margin": "маржа"}


def num(v):
    """'4 000 ₽' -> 4000.0, '20%' -> 20.0, 'не знаю'/'' -> None."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip().lower().replace(" ", " ")
    if s.startswith("=") or s.startswith("#"):  # формула/ошибка таблицы, не значение
        return None
    if not s or "не зна" in s or s in {"?", "-", "—", "нет данных"}:
        return None
    s = s.replace(" ", "")
    m = re.search(r"-?\d+(?:[.,]\d+)?", s)
    if not m:
        return None
    x = float(m.group().replace(",", "."))
    if re.search(r"\d(?:[.,]\d+)?(тыс|к\b|k\b)", s):
        x *= 1000
    elif re.search(r"\d(?:[.,]\d+)?(млн|m\b)", s):
        x *= 1_000_000
    return x


def read_card(path):
    out = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            if len(row) < 3:
                continue
            q = row[1].strip().lower()
            for key, words in FIELDS.items():
                if key not in out and any(w in q for w in words):
                    out[key] = row[2]
                    break
    return out


def load(args_card, args_json):
    raw = read_card(args_card) if args_card else json.loads(args_json)
    d = {k: num(raw.get(k)) for k in FIELDS}
    d["earning"] = str(raw.get("earning") or "").strip().lower() or None
    if d["hours_not_client"] is None and (d.get("hours_around") is not None or d.get("hours_self") is not None):
        d["hours_not_client"] = (d.get("hours_around") or 0) + (d.get("hours_self") or 0)
    # Сырые цифры подготовки → проценты, если их не вписали вручную.
    if d["conv"] is None and d.get("payments") is not None and d.get("leads"):
        d["conv"] = d["payments"] / d["leads"] * 100
    if d["check"] is None and d.get("revenue") is not None and d.get("payments"):
        d["check"] = d["revenue"] / d["payments"]
    if d["margin"] is None and d.get("revenue") and d.get("costs") is not None:
        d["margin"] = (d["revenue"] - d["costs"]) / d["revenue"] * 100
    return d, raw


def profit(d):
    if any(d.get(k) is None for k in MULT):
        return None
    return d["leads"] * d["conv"] / 100 * d["check"] * d["repeats"] * d["margin"] / 100


def analyse(d, prev, target_month, ready_min=READY_MIN):
    res = {"input": d, "unknown": [NAMES.get(k, k) for k in MULT if d.get(k) is None]}
    p = profit(d)
    if p is None and res["unknown"] == ["повторы"]:
        d = dict(d, repeats=1.0)
        p = profit(d)
        res["assumption"] = "повторы неизвестны — посчитано как 1 (нижняя оценка)"
    res["profit_month"] = round(p) if p is not None else None
    if p is not None:
        res["plus10_each"] = round(p * 1.1 ** 5)
    target = target_month or (d["wanted_year"] / 12 if d.get("wanted_year") else None)
    res["target_month"] = round(target) if target else None

    # Запас роста у ограниченных множителей: чем ниже текущее — тем больше запас.
    head = {}
    if d.get("conv"):
        head["conv"] = {"now_%": d["conv"], "до 50% (практический потолок) — раз": round(50 / d["conv"], 1)}
    if d.get("margin"):
        head["margin"] = {"now_%": d["margin"], "до 100% — раз": round(100 / d["margin"], 2)}
    if res["input"].get("repeats") is not None and res["input"]["repeats"] <= 1:
        head["repeats"] = {"now": d["repeats"], "заметка": "1 = клиент приходит один раз: повторов нет вовсе"}
    res["headroom"] = head

    if p and target and target > p:
        k = target / p
        need = {}
        for m in MULT:
            v = d[m] * k
            flag = "ок"
            if m == "conv":
                flag = "невозможно (>100%)" if v > 100 else ("очень трудно (>50%)" if v > 50 else "реально")
            elif m == "margin":
                flag = "невозможно (>100%)" if v > 100 else ("трудно (>90%)" if v > 90 else "реально")
            elif m == "leads":
                flag = "дорого: трафик ×%.1f" % k if k > 2 else "реально"
            elif m == "check":
                flag = "рискованно: цена ×%.1f" % k if k > 1.5 else "реально"
            elif m == "repeats":
                flag = "нужен новый продукт/сопровождение" if v - d[m] >= 1 else "реально"
            if res["input"].get(m) is None:
                flag = "неизвестно — сначала посчитать (в расчёте подставлено %g)" % d[m]
            need[NAMES[m]] = {"сейчас": d[m], "нужно": round(v, 2), "оценка": flag}
        res["to_target"] = {"во_сколько_раз": round(k, 2),
                            "если_тянуть_только_один_множитель": need}
    elif p and target:
        res["to_target"] = {"во_сколько_раз": round(target / p, 2), "заметка": "цель уже достигнута по формуле"}

    if d.get("promo_spent") and d.get("promo_back") is not None:
        res["promo_roi"] = round(d["promo_back"] / d["promo_spent"], 2)
    if d.get("hours_not_client") is not None:
        res["hours_not_client_week"] = d["hours_not_client"]
        res["hours_flag"] = "Херби-кандидат: эксперт сам" if d["hours_not_client"] >= 10 else "норма"

    # Цена часа: прибыль месяца / все рабочие часы месяца (неделя × 4,3).
    hrs = [d.get(k) for k in ("hours_client", "hours_around", "hours_self")]
    if any(h is not None for h in hrs):
        total = sum(h or 0 for h in hrs)
        res["hours_week"] = {"на клиента": d.get("hours_client"), "вокруг клиента": d.get("hours_around"),
                             "на себя": d.get("hours_self"), "всего": total}
        if total and d.get("revenue") and d.get("costs") is not None:
            res["hour_rate"] = round((d["revenue"] - d["costs"]) / (total * 4.3))
        if total and d.get("hours_client") is not None:
            res["paid_share_%"] = round(d["hours_client"] / total * 100)
    if d.get("study_spent") and d.get("study_back") is not None:
        res["study_roi"] = round(d["study_back"] / d["study_spent"], 2)
    if d.get("directions") is not None:
        res["directions"] = d["directions"]
    e = d.get("earning") or ""
    res["zero_income"] = e.startswith("нет") or d.get("payments") == 0 or d.get("revenue") == 0

    # Время на изменения — проверяется ПЕРВЫМ.
    rh = d.get("ready_hours")
    if rh is None:
        res["time_for_change"] = {"статус": "не указано", "что_делать": "спросить первым: сколько часов в неделю готов уделять изменениям (не клиентам)"}
    elif rh < ready_min:
        res["time_for_change"] = {"статус": "ПЕРВОЕ ГОРЛЫШКО", "часов": rh, "порог": ready_min,
                                  "смысл": "меньше %g ч в неделю на изменения — ни один агент не взлетит; сказать первым" % ready_min}
    else:
        res["time_for_change"] = {"статус": "ок", "часов": rh, "порог": ready_min}

    if prev:
        dyn = {}
        for m in MULT:
            a, b = prev.get(m), d.get(m)
            if a and b is not None:
                dyn[NAMES[m]] = {"было": a, "стало": b, "изменение_%": round((b / a - 1) * 100)}
        res["dynamics"] = dict(sorted(dyn.items(), key=lambda x: x[1]["изменение_%"]))
    # Кандидаты: горлышко — гипотеза, их может быть несколько.
    cand = []
    if res["time_for_change"]["статус"] == "ПЕРВОЕ ГОРЛЫШКО":
        cand.append("время на изменения: %g ч/нед < %g" % (rh, ready_min))
    if res["zero_income"]:
        cand.append("пока ноль: сначала продукт и первый клиент — подробный разбор, агенты потом")
    if res["unknown"] and not res["zero_income"]:
        cand.append("нет учёта: " + ", ".join(res["unknown"]))
    for m, v in (res.get("to_target", {}).get("если_тянуть_только_один_множитель") or {}).items():
        if v["оценка"] == "реально":
            cand.append("%s: до цели рост реален (%s → %s)" % (m, v["сейчас"], v["нужно"]))
    if d.get("conv") and d["conv"] < 15 and not any(c.startswith("конверсия") for c in cand):
        cand.append("конверсия низкая: %g%% (большой запас)" % d["conv"])
    if res["input"].get("repeats") is not None and res["input"]["repeats"] <= 1:
        cand.append("повторов нет: клиент приходит один раз")
    if res.get("hours_flag", "").startswith("Херби"):
        cand.append("эксперт сам: %g ч/нед не на клиента" % d["hours_not_client"])
    if res.get("promo_roi") is not None and res["promo_roi"] < 1:
        cand.append("продвижение не окупилось (возврат %.2f на 1 ₽) — горлышко не в заявках" % res["promo_roi"])
    if res.get("dynamics"):
        worst = next(iter(res["dynamics"].items()))
        if worst[1]["изменение_%"] < -10:
            cand.append("просело сильнее всего: %s (%+d%%)" % (worst[0], worst[1]["изменение_%"]))
    if res.get("paid_share_%") is not None and res["paid_share_%"] < 50:
        cand.append("за деньги только %d%% рабочих часов — остальное вокруг клиента и на себя" % res["paid_share_%"])
    if res.get("study_roi") is not None and res["study_roi"] < 1:
        cand.append("обучение не окупилось (%.2f на 1 ₽) — вечный ученик?" % res["study_roi"])
    if res.get("directions") and res["directions"] > 1:
        cand.append("распыление: %g направлений (5 единиц — одно)" % res["directions"])
    res["candidates"] = list(dict.fromkeys(cand))
    res["note"] = ("Горлышко — гипотеза. Их может быть несколько: берём главного кандидата, "
                   "месяц меряем его цифру. Сдвинулась — горлышко переехало, ищем следующее. "
                   "Не сдвинулась — проверяем следующего кандидата.")
    return res


def main():
    ap = argparse.ArgumentParser(description="Горлышко: формула прибыли по карточке")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--card")
    g.add_argument("--json")
    ap.add_argument("--prev", help="карточка (CSV) прошлого периода")
    ap.add_argument("--target-month", type=float)
    ap.add_argument("--ready-min", type=float, default=READY_MIN)
    a = ap.parse_args()
    try:
        d, _ = load(a.card, a.json)
        prev = load(a.prev, None)[0] if a.prev else None
    except (OSError, ValueError) as e:
        sys.exit("Не прочитать данные: %s" % e)
    print(json.dumps(analyse(d, prev, a.target_month, a.ready_min), ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
