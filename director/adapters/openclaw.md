# Адаптер: OpenClaw

MCP есть, «скиллов»/субагент-типов Claude Code нет. Интерактив → протокол сессии лёгкий.

> Проверить актуальность: у части заказчиков OpenClaw заменён на Hermes. Стоит и то и другое → ставить в Hermes, OpenClaw пропустить.

## Механика среды

| Аспект | Как |
|--------|-----|
| Инструкции | блок между маркерами `<!-- DIRECTOR -->` **в конец** `~/.openclaw/workspace/AGENTS.md` (+ каждому суб-агенту в `~/.openclaw/agents/*/AGENTS.md`); чужой текст не трогать |
| Профиль | блок в `USER.md` рядом |
| MCP | `openclaw mcp set lightrag '{...}'` / `openclaw mcp set postgres '{...}'` — **рядом** с существующими в `~/.openclaw/openclaw.json` → `mcp.servers`. Перезапуск OpenClaw после |
| Оркестратор | основная модель OpenClaw |
| Протокол | core/05, лёгкий (без `skill-creator`/хука) |
| «Субагент» | суб-агент OpenClaw, не `Task` |

## Что генерит мастер

Рядом с `AGENTS.md`: `director-doctrine/` = дословные копии `core/00–05.md` + `models.md` + `skills.md`. Блок в `AGENTS.md` ссылается на них.

`journal.md` рядом. tier lite: `02-memory.md` = `core/02-memory-lite.md`, протокол убрать.

## Блок для `AGENTS.md` (тонкий)

```markdown
<!-- ═══ DIRECTOR ({{USER_NAME}}) — мастер director, тир {{TIER}} ═══ -->

# Директор ({{USER_NAME}})

Оркестратор, не исполнитель. Полная доктрина — читать целиком:
`director-doctrine/00-director.md` … `05-protocol.md`, `models.md`, `skills.md`.

## Параметры {{USER_NAME}}
- Прод (только с ОК): {{PROD_DEFINITION}}
- Тест-среда: {{TEST_ENV_LINE}}
- Оркестратор: {{SELF_MODEL}}. Исполнители: {{CHEAP_STACK}}
- Память: LightRAG MCP `{{LIGHTRAG_MCP}}` + PostgreSQL MCP `{{PG_MCP}}` (запись `{{PG_WRITE_MCP}}`), таблицы {{PG_TABLES}}. Нет памяти на старте → сказать {{USER_NAME}}, не начинать.
- Старт-контекст: {{START_CONTEXT_FILES}}. Связь: {{ALERT_CHANNEL}} → {{ALERT_TARGET}} ({{ALERT_VERBOSITY}}).
- Автономия: {{AUTONOMY_LEVEL}}. Обращение {{ADDRESS_FORM}}. Часы тишины {{QUIET_HOURS}}.

## Среда
Протокол сессии (core/05) — лёгкий: старт = recall из LightRAG (молча) + контекст + git status + брифинг; финал = журнал + память (с ОК) + git add конкретных файлов + commit + push. «Субагент» = суб-агент OpenClaw. Скилл под задачу есть → использовать молча.

{{FREEMIND_LINE}}
<!-- ═══ /DIRECTOR ═══ -->
```

## Блок для `USER.md`

```markdown
<!-- ═══ DIRECTOR PROFILE ═══ -->
## {{USER_NAME}}
{{USER_BIO}}. Язык: {{LANGUAGE}}. Папка: `{{PROJECT_PATH}}`.
Прод (только с ОК): {{PROD_DEFINITION}}. Тест-среда: {{TEST_ENV}}.
Связь: {{ALERT_CHANNEL}} → {{ALERT_TARGET}}. Память: LightRAG `{{LIGHTRAG_URL}}` + PostgreSQL (brain).
<!-- ═══ /DIRECTOR PROFILE ═══ -->
```
