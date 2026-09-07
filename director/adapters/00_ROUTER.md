# Адаптеры — роутер по средам

Директор ставится в разные среды. Ядро ([../core/](../core/)) одинаковое, адаптер добавляет механику: где лежат файлы, в каком формате, как автозагрузка, как MCP, включён ли протокол сессии.

## Как выбрать адаптер

Мастер `director` определяет среду **сам**, потом подтверждает у пользователя:

| Признак | Среда | Файл |
|---------|-------|------|
| `~/.claude/` + запуск из Claude Code / Desktop | Claude Code | [claude-code.md](claude-code.md) |
| `hermes` в PATH / `~/.hermes/` / systemd `hermes-*` | Hermes | [hermes.md](hermes.md) |
| `~/.openclaw/` / `openclaw` в PATH | OpenClaw | [openclaw.md](openclaw.md) |
| `~/.cursor/` / `.clinerules` / `~/.codeium/windsurf/` | Cursor / Cline / Windsurf | [cursor-cline.md](cursor-cline.md) |
| `codex` в PATH / `~/.codex/` | OpenAI Codex CLI | [codex-cli.md](codex-cli.md) |
| `qwen` в PATH / `~/.qwen/` | Qwen Code CLI | [qwen-code.md](qwen-code.md) |
| ставим в AI Agent ноду воркфлоу n8n | n8n AI Agent | [n8n-ai-agent.md](n8n-ai-agent.md) |
| ничего из выше / другой агент / свой бот | Голый system-prompt | [generic.md](generic.md) |

Несколько сред на одной машине → поставить в каждую свой адаптер. Если бэкенд памяти `lightrag*` — он общий (один LightRAG/PostgreSQL на все среды). Если `native`/`files` — у каждой среды своя.

## Что общего у всех адаптеров

1. Тянут одни и те же `core/00…04` (доктрина, делегирование, память, правила, самоулучшение)
2. Требуют рабочую персистентную память бэкенда `{{MEMORY_BACKEND}}` (`native`/`files`/`lightrag`/`lightrag_postgres`) — [../core/02-memory.md](../core/02-memory.md), апгрейд → [../memory-setup/README.md](../memory-setup/README.md)
3. Заполняют `{{плейсхолдеры}}` из интервью — [../templates/PLACEHOLDERS.md](../templates/PLACEHOLDERS.md)
4. Кладут `profile.md` рядом

## Что различается

| Среда | Формат | Автозагрузка | Протокол сессии | Субагенты |
|-------|--------|--------------|-----------------|-----------|
| Claude Code | `SKILL.md` + `references/` | SessionStart-хук | полный (core/05) | `Task` |
| Hermes | блок в `~/.hermes/SOUL.md` | сам при задаче | **нет** — протокол задачи | суб-агенты Hermes |
| OpenClaw | блоки `AGENTS.md` + `USER.md` | сам | лёгкий | суб-агенты OpenClaw |
| Cursor/Cline/Windsurf | блок в файле правил | сам (проектные правила) | лёгкий | нет |
| Codex CLI | блок в `AGENTS.md` | сам | лёгкий (на задачу) | нет |
| Qwen Code | блок в `QWEN.md` | сам | лёгкий | нет (или task-tool) |
| n8n AI Agent | текст в System Message ноды | нода в воркфлоу | на триггер | sub-workflow |
| Generic | 1 блок в system-prompt | вручную | лёгкий/нет | нет |

Проверка сгенерированного скилла (`skill-creator`/`skill-conductor`) — только Claude Code.

## Модель (нейросеть)

Ортогонально среде: какая модель — оркестратор, какая для дешёвой пачки — роутер [../models/00_ROUTER.md](../models/00_ROUTER.md).
