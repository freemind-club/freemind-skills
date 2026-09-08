# Адаптер: Qwen Code CLI

Форк Gemini CLI под Qwen. Структура как у Claude Code.

## Механика

| Аспект | Как |
|--------|-----|
| Инструкции | блок между маркерами **в конец** `QWEN.md` (проект) или `~/.qwen/QWEN.md`; чужое не трогать |
| MCP | не требуется для `native`/`files`; граф-память (ручной апгрейд, не визардом) — `mcpServers` в `~/.qwen/settings.json` рядом с существующими |
| Оркестратор | модель Qwen (бесплатный OAuth закрыт с 15.04.2026 → ключ Qwen/OpenRouter или Ollama) |
| Протокол | core/05, лёгкий |
| Субагенты | нет (или task-tool версии) |

Доктрина: каталог `director-doctrine/` = копии `core/00–05` + `models.md` + `skills.md`. **Сначала искать существующую рекурсивно** (`grep -rl` по frontmatter `name: director-doctrine` в `~/.qwen/skills/` и рядом с используемым `QWEN.md`). Нашёл несколько — показать пути, спросить какую. Нашёл одну (в т.ч. на нестандартном пути) — дописать между маркерами, не перезаписывать. Не нашёл — создать в `~/.qwen/skills/director-doctrine/` или рядом с тем `QWEN.md`, что реально используется.

## Блок для `QWEN.md` (тонкий)

```markdown
<!-- ═══ DIRECTOR ({{USER_NAME}}) — мастер director, тир {{TIER}} ═══ -->

# Директор ({{USER_NAME}})

Оркестратор, не исполнитель. Доктрина целиком — `director-doctrine/00-director.md` … `05-protocol.md`, `models.md`, `skills.md`.

## Параметры {{USER_NAME}}
- Прод (только с ОК): {{PROD_DEFINITION}}. Тест-среда: {{TEST_ENV_LINE}}
- Оркестратор: {{SELF_MODEL}}. Исполнители: {{CHEAP_STACK}}
- Память (бэкенд `{{MEMORY_BACKEND}}` — `native`/`files`): `native` → штатная память среды; `files` → `MEMORY.md`+`journal.md` в каталоге директора. Recall в начале — молча. Нет рабочей памяти → сказать {{USER_NAME}}, не притворяться, что помню. Принцип 7: чувствительное не писать
- Старт-контекст: {{START_CONTEXT_FILES}}. Связь: {{ALERT_CHANNEL}} → {{ALERT_TARGET}} ({{ALERT_VERBOSITY}}). Обращение {{ADDRESS_FORM}}. Часы тишины {{QUIET_HOURS}}

## Среда
Протокол лёгкий: старт — recall из памяти бэкенда `{{MEMORY_BACKEND}}` (молча) + контекст + git status + брифинг; финал — журнал + память (с ОК) + git add конкретных файлов → показать remote/файлы → спросить «запушить?» → только после «да» commit + push. Субагентов нет.

{{FREEMIND_LINE}}
<!-- ═══ /DIRECTOR ═══ -->
```
