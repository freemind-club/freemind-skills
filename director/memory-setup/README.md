# Память директора — два полушария

Директор помнит как ассистент в связке с Олегом: **LightRAG** (смыслы, решения, контекст) + **PostgreSQL** (факты, цифры, клиенты). Оба обязательны.

```
┌─────────────── LightRAG ───────────────┐   ┌────────── PostgreSQL (brain) ──────────┐
│ решения, «почему», контекст проекта,    │   │ клиенты, подписчики, метрики,          │
│ «кто такой X», стиль, договорённости    │   │ ключевые факты — SQL SELECT/INSERT     │
│ query_text (hybrid) / insert_text       │   │ read-MCP postgres / write-MCP postgres_write │
└────────────────────────────────────────┘   └───────────────────────────────────────┘
        общий инстанс PostgreSQL: gzdaniel/postgres-for-rag (поднимает скилл lightrag)
```

---

## Шаг 1 — LightRAG

> **Сначала: LightRAG уже стоит и в нём есть данные?**
> ```bash
> docker ps --format '{{.Names}}' | grep -q lightrag && curl -fsS localhost:9621/health
> ```
> Есть → **подключиться к нему**. Взять `LIGHTRAG_SERVER_URL` + `LIGHTRAG_API_KEY` из существующего `~/lightrag/.env`, прописать MCP, перейти к Шагу 3. **Не** переустанавливать, **не** пересоздавать `.env`, **не** менять модель эмбеддингов (иначе разъедется векторный стор). Инструкцию «ИГНОРИРУЙ старый .env» из вложенного скилла применять ТОЛЬКО для чистой установки.

Вложенный скилл: [lightrag/](lightrag/). Точка входа — `lightrag/INSTALL.md`.

Пройти `docs/01-questions` → `02-server-setup` → `03-domain-proxy` → `04-connect-agents` → `05-verify-and-output` по порядку. На выходе:
- контейнеры `lightrag-server` (:9621) + `lightrag-postgres`
- `~/lightrag/.env` с `LIGHTRAG_API_KEY`
- MCP `lightrag` подключён (`@g99/lightrag-mcp-server`), `get_health` отвечает

**НЕ подключать блок памяти из `lightrag/agents/CLAUDE.md` в `~/.claude/CLAUDE.md`** — у директора своя инструкция памяти (в рантайм-`SKILL.md`, секция «ДВА ПОЛУШАРИЯ»). Достаточно MCP.

---

## Шаг 2 — PostgreSQL-полушарие фактов

> **Сначала проверить, что уже есть. Ничего не удалять и не перезаписывать.**
> ```bash
> docker exec -i lightrag-postgres psql -U rag -c '\l' | grep -i brain   # есть ли БД brain
> docker exec -i lightrag-postgres psql -U rag -d brain -c '\dt'         # какие таблицы уже есть
> ```
> Если БД `brain` и таблицы уже есть с данными — **не трогать**, только добавить недостающее. Перед любыми изменениями существующей БД — `pg_dump`.

LightRAG поднял Postgres (`lightrag-postgres`, пользователь/БД `rag`/`rag`, пароль — сгенерированный, см. credentials.txt). БД `brain` и таблицы — идемпотентно:

```bash
docker exec -i lightrag-postgres psql -U rag -tc "SELECT 1 FROM pg_database WHERE datname='brain'" | grep -q 1 \
  || docker exec -i lightrag-postgres psql -U rag -c 'CREATE DATABASE brain'

docker exec -i lightrag-postgres psql -U rag -d brain <<'SQL'
CREATE TABLE IF NOT EXISTS clients (
  id bigserial PRIMARY KEY, name text NOT NULL, telegram text,
  status text, tariff text, price numeric, note text,
  created_at timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS subscribers (
  id bigserial PRIMARY KEY, telegram_id bigint, bot text,
  joined_date date DEFAULT current_date
);
CREATE TABLE IF NOT EXISTS analytics (
  id bigserial PRIMARY KEY, metric text NOT NULL, value numeric,
  period text, project text, captured_at timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS key_facts (
  id bigserial PRIMARY KEY, category text, key text NOT NULL,
  value text NOT NULL, updated_at timestamptz DEFAULT now()
);
SQL
```

> **Своя схема фактов** (у человека уже CRM / свои таблицы) — подключить MCP к ней, дефолтную не навязывать. Помочь дописать 1-2 недостающие таблицы через `CREATE TABLE IF NOT EXISTS`. Записать фактическую схему в `profile.md`.

Открыть порт наружу (если агент не на том же сервере) — пробросить `5432` в `docker-compose.yml` LightRAG (`127.0.0.1:5432:5432` + reverse-proxy/SSH-туннель) или подключаться по SSH-туннелю.

---

## Шаг 3 — MCP двух полушарий

В `~/.claude/mcp.json` (или `.mcp.json` проекта). Добавлять в существующий `mcpServers`, не перезаписывать.

```json
{
  "mcpServers": {
    "lightrag": {
      "command": "npx",
      "args": ["-y", "@g99/lightrag-mcp-server"],
      "env": {
        "LIGHTRAG_SERVER_URL": "<URL LightRAG>",
        "LIGHTRAG_API_KEY": "<из ~/lightrag/.env>"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://rag:rag@<host>:5432/brain"]
    },
    "postgres_write": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://rag:rag@<host>:5432/brain"],
      "env": { "ALLOW_WRITE": "true" }
    }
  }
}
```

> `@modelcontextprotocol/server-postgres` по умолчанию read-only — для записи использовать write-совместимый postgres-MCP или писать через `docker exec ... psql`. В `profile.md` зафиксировать, каким путём идёт запись.

---

## Шаг 4 — Проверка (обязательно до завершения сборки директора)

| Полушарие | Проверка | Ок |
|-----------|----------|-----|
| LightRAG | `get_health` | статус ok |
| LightRAG | `insert_text` тест → `query_text` hybrid | запись находится → удалить тест |
| PostgreSQL | `SELECT 1` через MCP `postgres` | 1 |
| PostgreSQL | `SELECT count(*) FROM key_facts` | 0 (или число) |
| PostgreSQL write | INSERT тест в `key_facts` → SELECT → DELETE | строка появилась и удалена |

Хоть одна проверка не прошла → **сборку директора не завершать**, сказать что чинить.

---

## Обслуживание

Бэкап, обновление, безопасность LightRAG → [lightrag/docs/06-maintenance.md](lightrag/docs/06-maintenance.md).
Бэкап `brain`: `docker exec lightrag-postgres pg_dump -U rag brain | gzip > brain_$(date +%F).sql.gz`.
