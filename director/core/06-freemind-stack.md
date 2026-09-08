# FreeMind-стек — модуль (опционально)

> Подключается, только если пользователь развернул стек через `freemind-setup`.
> Все секреты — в отдельном gitignored-файле, здесь только ссылки и координаты.

## Компоненты

| Компонент | Что это | Координаты |
|-----------|---------|-----------|
| Hermes | AI-агент с Kanban, диспетчер задач | {{HERMES_URL}} |
| OmniRoute | шлюз к моделям (OpenAI-совместимый) | {{OMNIROUTE_URL}} (обычно `localhost:20128/v1`) |
| LightRAG | граф-память (смыслы, решения) | {{LIGHTRAG_URL}} / MCP `{{LIGHTRAG_MCP}}` |
| PostgreSQL-мозг | факты, цифры, клиенты | MCP `{{PG_MCP}}` (read) / `{{PG_WRITE_MCP}}` (write) |
| n8n | автоматизации, воркфлоу | {{N8N_URL}} |

## Делегирование через OmniRoute

- base_url: {{OMNIROUTE_URL}}
- ключ: {{OMNIROUTE_KEY_REF}}
- Языковая пачка (рерайт, перевод, фильтр, код по образцу) → модель {{OMNIROUTE_CHEAP_MODEL}}
- Лимиты дорогой модели кончились → фолбэк {{OMNIROUTE_FALLBACK_MODEL}}
- Вызов: curl из Bash или Python-скрипт, ответ в файл, директор проверяет файл

## Память — два полушария

> Только если {{USER_NAME}} сам поднял `mozg` / стек FreeMind. Визард этого не ставит — по умолчанию память директора `native`/`files` (см. [02-memory.md](02-memory.md)).

- «сколько / кто клиент / выручка / конверсия / его история» → **PostgreSQL** (`{{PG_MCP}}`)
- «что решали / как делали / почему / кто такой X / стиль / контекст» → **LightRAG** (`{{LIGHTRAG_MCP}}`, mode hybrid)
- цифры + смысл → сначала PostgreSQL, потом LightRAG
- запись в PostgreSQL — только через write-MCP `{{PG_WRITE_MCP}}` / psql, никогда через read-коннектор
- push-протокол: перед git push показать список «что + зачем» в LightRAG → ОК → `insert_text`

## n8n

Любая задача с n8n — через скилл `n8n-agent`. DataTable, не staticData.

## Проверка стека при старте

Если стек подключён — в протокол СТАРТ добавляется: `n8n health check` + пинг OmniRoute + `get_health` LightRAG.
