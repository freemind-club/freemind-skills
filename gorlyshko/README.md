# Горлышко — найти, где бизнес теряет деньги

Скилл для ИИ-агента (Claude Code, Hermes). Отдаёшь ему карточку с цифрами своего бизнеса, получаешь одну страницу:
главное узкое горлышко и 1–2 запасных кандидата, причину по «5 почему», развилку «агент или работа над собой», одно действие на месяц и как проверить, что горлышко найдено верно.

Метод: формула прибыли (заявки × конверсия × средний чек × повторы × маржа), теория ограничений Голдратта, «5 почему» Toyota. Цифры считает программа `scripts/calc.py`, а не нейросеть.

## Вариант 1. Установить скилл (Claude Code / Hermes)

**Способ А — попросить агента.** Напиши своему агенту:
> Установи скилл по ссылке https://github.com/freemind-club/freemind-skills/tree/main/gorlyshko — следуй разделу «Для ИИ-агента» в README.

**Способ Б — сам, в терминале:**
```bash
curl -fsSL https://raw.githubusercontent.com/freemind-club/freemind-skills/main/gorlyshko/install.sh -o gorlyshko-install.sh
bash gorlyshko-install.sh
```
Скрипт можно открыть и прочитать перед запуском. sudo не нужен.

**Потом:** [карточка — сделать свою копию](https://docs.google.com/spreadsheets/d/1ebSuTo128LE53Fs4e1wiBSYEFzYoHm6SQVGu0LvlmwE/copy) → заполнить → Файл → Скачать → CSV → агенту: «найди моё горлышко» + файл.

## Вариант 2. Без установки — промпт для любой нейросети
ChatGPT, Claude, DeepSeek, GigaChat в браузере: скопируй [PROMPT.md](PROMPT.md) в чат, потом вставь свои цифры. Цифры считает сама нейросеть, поэтому перепроверь их по калькулятору в [карточке](https://docs.google.com/spreadsheets/d/1ebSuTo128LE53Fs4e1wiBSYEFzYoHm6SQVGu0LvlmwE/copy).

## Твои данные
Цифры остаются у тебя и в твоём агенте. Скилл никуда их не отправляет и ничего не сохраняет в общие базы.

---

## Для ИИ-агента (инструкция по установке)
1. Скачай установщик и **покажи пользователю его текст** перед запуском:
   `curl -fsSL https://raw.githubusercontent.com/freemind-club/freemind-skills/main/gorlyshko/install.sh -o /tmp/gorlyshko-install.sh`
2. С согласия пользователя: `bash /tmp/gorlyshko-install.sh`. Без sudo.
3. Если bash/curl недоступны — скачай папку `gorlyshko/` (SKILL.md, scripts/, references/, examples/) и положи в каталог скиллов своей среды (`~/.claude/skills/gorlyshko/` или `~/.hermes/skills/freemind/gorlyshko/`).
4. Проверь: `python3 <путь>/scripts/calc.py --card <путь>/examples/таролог_конверсия.csv` печатает JSON с `profit_month`.
5. Скажи пользователю: «Готово. Пришли карточку CSV (Google-таблица → Файл → Скачать → CSV) — найду горлышко». Дальше — по SKILL.md.

Лицензия: MIT. Автор метода: Олег Лаврентьев, FreeMind.
