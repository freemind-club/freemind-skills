# Адаптер: OpenAI Codex CLI

Среда запуска директора и/или делегат кода.

## Механика

| Аспект | Как |
|--------|-----|
| Инструкции | блок между маркерами **в конец** `AGENTS.md` (проект) или `~/.codex/AGENTS.md` (глобально); чужое не трогать |
| MCP | `~/.codex/config.toml` → `[mcp_servers.<name>]` рядом с существующими |
| Оркестратор | модель Codex |
| Протокол | лёгкий, на задачу (Codex — одна задача за запуск) |
| Субагенты | нет |

Доктрина: `director-doctrine/` рядом с `AGENTS.md` = копии `core/00–05` + `models.md` + `skills.md`.

## MCP (`config.toml`)

```toml
[mcp_servers.lightrag]
command = "npx"
args = ["-y", "@g99/lightrag-mcp-server@1.1.0"]
env = { LIGHTRAG_SERVER_URL = "{{LIGHTRAG_URL}}", LIGHTRAG_API_KEY = "..." }

[mcp_servers.postgres]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-postgres", "postgresql://.../brain"]
```

## Как делегат кода (директор в другой среде)

```bash
codex exec "<точное ТЗ + пути файлов>"
```
Директор проверяет изменённые файлы сам.

## Блок для `AGENTS.md` (тонкий)

```markdown
<!-- ═══ DIRECTOR ({{USER_NAME}}) — мастер director, тир {{TIER}} ═══ -->

# Директор ({{USER_NAME}})

Оркестратор, не исполнитель. Доктрина целиком — `director-doctrine/00-director.md` … `05-protocol.md`, `models.md`, `skills.md`.

## Параметры {{USER_NAME}}
- Прод (только с ОК): {{PROD_DEFINITION}}. Тест-среда: {{TEST_ENV_LINE}}
- Оркестратор: {{SELF_MODEL}}. Исполнители: {{CHEAP_STACK}}
- Память (бэкенд `{{MEMORY_BACKEND}}`; `files` → `MEMORY.md`, `lightrag*` → MCP): `{{LIGHTRAG_MCP}}` + `{{PG_MCP}}` (запись `{{PG_WRITE_MCP}}`), таблицы {{PG_TABLES}}. Нет рабочей памяти бэкенда `{{MEMORY_BACKEND}}` → сказать {{USER_NAME}}
- Связь: {{ALERT_CHANNEL}} → {{ALERT_TARGET}}. Обращение {{ADDRESS_FORM}}

## Среда
На задачу: recall из памяти бэкенда `{{MEMORY_BACKEND}}` (молча) → сделать, делегируя → проверить (тесты/запуск) → запись решений/фактов в память (принцип 7: чувствительное не писать) → под git: git add конкретных файлов → показать remote/файлы → спросить «запушить?» → только после «да» commit + push. Субагентов нет.

{{FREEMIND_LINE}}
<!-- ═══ /DIRECTOR ═══ -->
```
