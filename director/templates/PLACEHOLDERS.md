# Плейсхолдеры — что подставляет мастер

> Каждый `{{KEY}}` в файлах адаптеров и ядра заменяется значением из интервью. Опциональные блоки, если не выбраны, — **удалять целиком вместе с заголовком**, не оставлять `{{...}}`.

## Среда и тир

| KEY | Откуда | Пример |
|-----|--------|--------|
| `ENVIRONMENT` | Шаг 0.5 | `claude-code` / `hermes` / `openclaw` / `cursor-cline` / `codex-cli` / `qwen-code` / `n8n-ai-agent` / `generic` |
| `VERSION` | файл `VERSION` мастера | `1.0.0` |
| `TIER` | Шаг 0 | `full` / `lite` / `trial` |
| `PROMO_CODE` | Шаг 0 | `FreeMind` (записывается в profile для сверки постфактум) |
| `INVENTORY_SUMMARY` | Шаг 0.7 | «Нашёл: LightRAG с данными (подключён), 2 MCP-сервера, AGENTS.md (блок добавлен). Не тронуто.» |
| `MEMORY_BACKEND` | Блок 2 | `native` / `files` / `lightrag` / `lightrag_postgres`. Дефолт: `native` где у среды есть штатная память (Hermes, Cursor), иначе `files`. `lightrag*` — только если пользователь сформулировал потребность |
| `MEMORY_KIND` | Блок 2 | человекочитаемо: `штатная память среды` / `файловая` / `смысловая (LightRAG)` / `LightRAG + PostgreSQL` |
| `BACKUP_TS` | Шаг 0.6 | `20260902-143000` — метка снимка |
| `BACKUP_PATH` | Шаг 0.6 | `~/.director-backup/20260902-143000/` (пишется в profile) |
| `RESTORE_FILE_LINES` / `REMOVE_DIRECTOR_LINES` / `DB_RESTORE_HINT` | Шаг 0.6, производное | строки для `restore.sh` под конкретные файлы этой установки |
| `TIER_UPSELL_LINE` | производное от `TIER` | `lite`/`trial` — блок апселла (текст → activation.md); `full` — пусто |
| `CLUB_LINK` | конфиг / дефолт | `https://lavrentevoleg.ru/social/club` (хаб соцсетей + клуб); личка Олега — `https://t.me/Lavrentev_Oleg` |
| `SETUP_DATE` | системная дата | `2026-09-02` |

## Базовый слой

| KEY | Откуда | Пример |
|-----|--------|--------|
| `USER_NAME` | Блок 1 в1 | «Олег» |
| `USER_BIO` | Блок 1 в2 | «предприниматель, клуб по нейросетям, автоматизатор» |
| `LANGUAGE` | Блок 1 в3 | «русский» |
| `PROJECT_PATH` | Блок 1 в4 | `/root/work/myproject` |
| `PROJECT_GIT` / `PROJECT_GIT_LINE` | Блок 1 в4 | «да, remote github.com/user/repo» / строка или пусто |
| `START_CONTEXT_FILES` / `START_CONTEXT_FILES_LIST` | Блок 1 + скан | `CLAUDE.md, STATUS.md, TODO.md` |
| `INBOX_PATH` | Блок 1 / дефолт | `_inbox/` или «нет» |
| `STATUS_FILES` | скан проекта | `STATUS.md, TODO.md, journal.md` |
| `START_EXTRA` | Блок 3 в9 | `n8n health check через MCP` или «—» |

## Память — заполняется только при `MEMORY_BACKEND` = `lightrag` / `lightrag_postgres`

Для `native` / `files` эти плейсхолдеры не нужны — соответствующие блоки в ядре/адаптере удаляются.
`PG_*` — только при `lightrag_postgres`.

| KEY | Откуда | Пример |
|-----|--------|--------|
| `LIGHTRAG_MCP` | Блок 2 в5 | `lightrag` |
| `LIGHTRAG_URL` | Блок 2 в5 / `~/lightrag/.env` | `https://lrag.example.ru` или `http://localhost:9621` |
| `PG_MCP` | Блок 2 в6 | `postgres` (read-only) |
| `PG_WRITE_MCP` | Блок 2 в6 | `postgres_write` |
| `PG_CONN_REF` / `PG_WRITE_REF` | Блок 2 в6 | `postgresql://user:pass@host/brain` (в credentials, не в файле) |
| `PG_TABLES` | Блок 2 в6 / дефолт | `clients, subscribers, analytics, key_facts` |
| `MEMORY_COORDS` | Блок 2 | «`~/lightrag/.env`, `~/.claude/mcp.json`» |

## Делегирование и модели

| KEY | Откуда | Пример |
|-----|--------|--------|
| `SELF_MODEL` | Блок 3 в7 / Т2 | «Claude Sonnet (подписка)» / «GigaChat-2-Pro» |
| `CHEAP_STACK` | Блок 3 в8 / Т2 | упорядоченный список: «1) субагенты 2) OmniRoute kiro 3) Groq llama-3.3-70b» |
| `DELEGATION_SHORT` | производное | 1-2 строки для рантайма: что куда |
| `DELEGATION_COORDS` | Блок 3 в8 | «OmniRoute localhost:20128, ключ в ~/.director/models.env» |
| `TOOLS_LIST` | Блок 3 в9 | `n8n (MCP), Telegram-бот алертов` |

## Правила и связь

| KEY | Откуда | Пример |
|-----|--------|--------|
| `TEST_ENV` | Блок 4 в10 | «тест-бот @x, тест-чат -100...» / «нет» |
| `TEST_ENV_LINE` / `TEST_ENV_BLOCK` | производное | текст правила 2 (или «тест-среда не настроена — …») |
| `PROD_DEFINITION` | Блок 4 в11 | «боевые рассылки, публикация в канал, продовая БД» |
| `ALERT_CHANNEL` | Блок 4 в12 | `telegram` / `slack` / `chat` |
| `ALERT_TARGET` | Блок 4 в12 | `Telegram chat_id 154329871` / «в чат» |
| `ALERT_CONTACT_LINE` | производное | строка в «КТО МЫ» или пусто |

## Точечный слой (опц., full/trial)

| KEY | Откуда | Пример |
|-----|--------|--------|
| `AUTONOMY_LEVEL` | Т1 / дефолт `balanced` | `conservative` / `balanced` / `aggressive` |
| `AUTONOMY_NOTE` | производное от Т1 | «Правки доки/конфигов — сам. Действия с последствиями — через ОК.» |
| `QUIET_HOURS` | Т3 / дефолт «—» | «после 19:00 и в выходные, кроме критики» |
| `COMMIT_STYLE` | Т4 / дефолт | «свободно, на языке общения» / «conventional» |
| `ALERT_VERBOSITY` | Т5 / дефолт `blockers-only` | `every-task` / `blockers-only` / `daily-digest` |
| `ADDRESS_FORM` | Т6 / дефолт «на ты» | «на ты» / «на вы» |
| `EXTRA_RULES` | Т7 | список доп. правил → в `03-rules.md` |
| `SKILLS_INVENTORY` | скан скиллов среды | таблица «задача → скилл» |
| `SKILLS_REPO` | конфиг / дефолт | `https://github.com/freemind-club/freemind-skills` |
| `SKILLS_LIB_INSTALLED` | Шаг 4.5 | `да, ~/freemind-skills` / `нет` |

## FreeMind (только full/trial)

| KEY | Откуда | Пример |
|-----|--------|--------|
| `FREEMIND_ENABLED` | Блок 5 в13 | `да` / `нет` |
| `FREEMIND_LINE` | производное | `> FreeMind-стек → см. references/06-freemind-stack.md` или пусто |
| `OMNIROUTE_URL` / `OMNIROUTE_KEY_REF` / `OMNIROUTE_CHEAP_MODEL` / `OMNIROUTE_FALLBACK_MODEL` | Блок 5 | `http://localhost:20128/v1` / … |
| `HERMES_URL` / `N8N_URL` | Блок 5 | координаты стека |
| `OPEN_QUESTIONS` | накопленное за интервью | список «— уточнить: …» |
