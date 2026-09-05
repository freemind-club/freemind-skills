# Адаптер: Hermes

Hermes — постоянный агент (Telegram-гейтвей + Kanban + cron), не сессии. Факты — из локальной установки (`/usr/local/lib/hermes-agent`, `~/.hermes/`) и `_inbox/natalia_hermes_install.md`.

## Механика

| Аспект | Как |
|--------|-----|
| Инструкции | блок между маркерами **в конец** `~/.hermes/SOUL.md`; существующий текст персоны не трогать |
| Профиль | `~/.hermes/memories/USER.md` (формат `key §` через `§`), **дополнить** |
| Доктрина | `~/.hermes/skills/director-doctrine/` = копии `core/00–04` + `models.md` + `skills.md` (нужен `hermes skills trust` проекта, если репо-локально) |
| MCP | `hermes mcp add <name> ...` (см. ниже) → рядом с существующими, `hermes mcp list` проверить |
| Оркестратор | `hermes config get model.default` |
| Протокол сессии (core/05) | **не применяется** — вместо него протокол задачи (в блоке ниже) |
| `~/.hermes/memories/MEMORY.md` | встроенная память Hermes — не трогать, наша память через MCP |

## MCP — показать и согласовать, не авто-одобрять

`hermes mcp add` спрашивает «Enable all tools? [Y/n/select]». Это осознанный выбор пользователя, не наш — **не отвечать `y` автоматически**.

1. `hermes mcp add --interactive` (или без флагов) → показать {{USER_NAME}} **какой сервер, какие именно инструменты** он даёт (`hermes mcp add --help` — список инструментов пакета, если поддерживается) → дать выбрать `select`, не `all`.
2. **LightRAG** обычно нужен read+write (query_text + insert_text) — это ожидаемо, объяснить зачем.
3. **PostgreSQL** — по умолчанию **read-only**. Write-доступ к БД — отдельный явный вопрос {{USER_NAME}}: «дать директору право писать в БД памяти? Без этого он не сможет создавать записи, но и не сможет случайно их сломать.» Ответил нет → не подключать write-сервер вовсе, только read.
4. Зафиксировать версии пакетов, не голый `npx -y` без версии, где это возможно: `npx -y @g99/lightrag-mcp-server@<версия>`.
5. После подключения — **обязательно** `hermes mcp list` и показать {{USER_NAME}} фактический список серверов и инструментов, которые реально включены. Сервера нет в списке → повторить или отдать команду {{USER_NAME}} вставить руками.

```bash
hermes mcp add lightrag --command npx --args -y '@g99/lightrag-mcp-server' \
  --env LIGHTRAG_SERVER_URL={{LIGHTRAG_URL}} LIGHTRAG_API_KEY=<из ~/lightrag/.env>
# postgres — только если {{USER_NAME}} явно согласился на write:
hermes mcp add postgres --command npx --args -y '@modelcontextprotocol/server-postgres' \
  'postgresql://<user>:<pass>@<host>:<port>/brain'
hermes mcp list   # показать {{USER_NAME}} этот вывод — что реально подключилось
```

## Блок для `~/.hermes/SOUL.md` (тонкий)

```markdown
<!-- ═══ DIRECTOR ({{USER_NAME}}) — мастер director, тир {{TIER}} ═══ -->

## Директор — как я работаю

Оркестратор, не исполнитель. Полная доктрина — читать целиком:
`~/.hermes/skills/director-doctrine/00-director.md` … `04-improvement.md`, `models.md`, `skills.md`.
Протокол сессии (05) НЕ применяется — вместо него протокол задачи.

### Протокол задачи (на каждое обращение / карточку Kanban)
1. Прочитать карточку/сообщение целиком
2. LightRAG `query_text` (hybrid) по теме — контекст. «🔍 Смотрю…» если >3 сек
3. Трогает реальных людей / прод ({{PROD_DEFINITION}})? → ОК {{USER_NAME}}, не раньше
4. Затратная задача (много ходов) → «⚠️ лучше с компьютера», ждать
5. Делать, делегируя: {{CHEAP_STACK}}
6. Проверить лично — curl/логи, не «✅»
7. **Сначала** LightRAG `insert_text` — решения / паттерны / уроки (не пересказ), PostgreSQL — цифры. Не код/логи/дампы
8. **Потом** под git → git add конкретных файлов + commit + push. Push без записи в память — нарушение
9. Отчёт в карточку: записал в память / сделано / проверено / запушено / осталось. Не завершается → сказать {{USER_NAME}}, не зависать

### Параметры {{USER_NAME}}
- Тест-среда: {{TEST_ENV_LINE}}
- Память: LightRAG MCP `{{LIGHTRAG_MCP}}` + PostgreSQL MCP `{{PG_MCP}}` (запись `{{PG_WRITE_MCP}}`), таблицы {{PG_TABLES}}. Нет памяти → не брать задачи
- Оркестратор: {{SELF_MODEL}}. Связь: {{ALERT_CHANNEL}} → {{ALERT_TARGET}}. Обращение {{ADDRESS_FORM}}
- Самоулучшение: «так не делай»/«запомни» → `insert_text` в LightRAG, тег `director-journal`

<!-- ═══ /DIRECTOR ═══ -->
```
