# Eval: золотые прогоны

Эталон, с которым сверяют реальный `/director`. Реальный прогон должен дать ту же структуру и логику подстановки.

---

## Прогон 1 — tier full, среда Claude Code, `MEMORY_BACKEND=files`

**Вход (ответы интервью):**
- Промокод: `FreeMind` → tier `full`
- Среда: `~/.claude` есть, запуск из Claude Code → `claude-code`
- Шаг 0.7: чисто (новая машина), MCP-конфига нет
- Имя: Олег · ниша: клуб по нейросетям, автоматизация · язык: русский
- Папка: `/root/YandexSync/ClaudeCode`, git с remote
- Память: `MEMORY_BACKEND=files` (визард граф-память не ставит). Пользователь сказал, что позже вручную поднимет `mozg` — записать в profile как «не подключена»
- Оркестратор: Claude (подписка). Исполнители: `1) субагенты 2) OmniRoute kiro/claude-sonnet-4.5 3) Groq llama-3.3-70b`
- Инструменты: n8n (MCP), Telegram-бот алертов
- Тест-среда: `@test_chanel_freemind` (-1002712137302), бот `@fremind_n8n_test_bot`
- Прод: боевые рассылки, публикация в @free_mind_rus, продовая БД
- Связь: Telegram chat_id 154329871, `tg-notify`
- FreeMind-модуль: да
- Точечные: автономия `balanced`, часы тишины «после 19:00 и выходные», коммиты «свободно по-русски», verbosity `blockers-only`, «ты», доп.правило «дамп БД перед агентом с записью»

**Ожидаемый выход:**
```text
~/.claude/skills/my-director/
├── SKILL.md          # frontmatter name=my-director; параметры Олега подставлены; секция ПРОТОКОЛ есть; апселла нет
├── profile.md        # все поля заполнены, среда=claude-code, тир=full, промокод=FreeMind
├── journal.md        # пустой
├── VERSION           # = VERSION мастера
├── references/
│   ├── 00-director.md … 05-protocol.md   # дословные копии core/*
│   ├── models.md     # только anthropic + openai-compatible(OmniRoute,Groq) — НЕ gemini/grok/ru/codex
│   ├── skills.md     # скан ~/.claude/skills + строка про freemind-club/freemind-skills
│   └── 06-freemind-stack.md   # с координатами OmniRoute/n8n
└── memory/          # MEMORY.md (бэкенд files)
```
- MCP-серверы визард не добавляет (память `files`); `~/.claude/mcp.json` не трогается
- SessionStart-хук предложен
- `grep '{{'` = пусто
- Проверка памяти: тест-заметка в `MEMORY.md` пишется и читается обратно
- `profile.md` → «Граф-память (LightRAG): не подключена»

---

## Прогон 2 — tier lite, среда generic, файловая память

**Вход:**
- Промокод: `Promo` → tier `lite`
- Среда: ни `~/.claude`, ни hermes/qwen/codex → `generic`
- Имя: Марина · ниша: фотограф · язык: русский
- Папка: `~/work`, git без remote
- Память: `MEMORY_BACKEND=files` (lite — вопросов 5-6 нет)
- Делегирование: только субагенты (lite)
- Тест-среда: нет
- Прод: публикация постов в Instagram
- Связь: «в чат»
- Точечный слой: пропущен (lite)

**Ожидаемый выход:**
- Один блок system-prompt (сжатая склейка `core/00–05` + профиль Марины), плейсхолдеры подставлены
- Блок апселла: «Lite-версия… полный — в клубе FreeMind. Олег: t.me/Lavrentev_Oleg · lavrentevoleg.ru/social/club»
- Инструкция: вставить блок в system-prompt агента; MCP визард не подключает (память файловая = `memory/`)
- `memory/MEMORY.md` создан
- Правило тест-среды в тексте: «тест-среда не настроена — проверки, которые могут задеть реальное, останавливать и спрашивать»
- `grep '{{'` = пусто
- Нет секции точечных настроек, нет протокола сессии (или минимальный)

---

## Что сравнивать

1. Список созданных файлов совпадает
2. Подставленные значения стоят в тех же местах (имя, прод, тест-среда, модели)
3. `models.md` / блок содержит только выбранное
4. Ноль `{{...}}`
5. Данные пользователя из Шага 0.7 не тронуты
6. tier-специфика (lite без протокола/точечных/FreeMind; full — всё)
