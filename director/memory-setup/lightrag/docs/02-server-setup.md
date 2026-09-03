# Шаг 2: Установка сервера

⛔ Убедись что ты прочитал `01-questions.md` и получил ВСЕ ответы от пользователя.

---

## 1. Требования

- Ubuntu 22.04+ / macOS с Docker Desktop / любой Linux с Docker
- 2 GB свободной RAM, 10 GB диска
- Docker + Docker Compose

## 2. Docker

```bash
# Проверка:
docker --version && docker compose version

# Если нет — установка (Linux):
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Перелогинься (exit + заново подключись по SSH)

# macOS: Docker Desktop — https://docker.com/products/docker-desktop
```

## 3. Создай директорию и файлы

⛔ **ВАЖНО:** Если на сервере уже есть `~/lightrag/.env` от предыдущей установки — **НЕ ИСПОЛЬЗУЙ ЕГО.** Старый `.env` содержит значения от прошлой установки, которые могут быть неправильными. ВСЕГДА создавай `.env` заново из `.env.example`, заполняй с нуля и спрашивай у пользователя все значения.

```bash
mkdir -p ~/lightrag && cd ~/lightrag
# Если есть старый .env — удали:
rm -f ~/lightrag/.env
```

### docker-compose.yml

Скопируй из `server/docker-compose.yml` репозитория. Или создай:

```yaml
services:
  postgres:
    image: gzdaniel/postgres-for-rag:16.6
    container_name: lightrag-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: rag
      POSTGRES_PASSWORD: rag
      POSTGRES_DB: rag
    volumes:
      - postgres_data:/var/lib/postgresql
    networks:
      - lightrag-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U rag"]
      interval: 5s
      timeout: 5s
      retries: 5

  lightrag:
    image: ghcr.io/hkuds/lightrag:latest
    container_name: lightrag-server
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    env_file: .env
    ports:
      # ТОЛЬКО localhost — наружу через reverse proxy!
      - "127.0.0.1:9621:9621"
    volumes:
      - rag_storage:/app/data/rag_storage
      - inputs:/app/data/inputs
    networks:
      - lightrag-net

volumes:
  postgres_data:
  rag_storage:
  inputs:

networks:
  lightrag-net:
    driver: bridge
```

⛔ **ВНИМАНИЕ:** порт `127.0.0.1:9621:9621` — это правильно. НЕ меняй на `0.0.0.0:9621:9621` — это откроет порт наружу без SSL и авторизации.

## 4. Создай .env

Сгенерируй секреты:
```bash
LIGHTRAG_API_KEY=$(openssl rand -hex 32)
TOKEN_SECRET=$(openssl rand -hex 32)
ADMIN_PASSWORD=$(openssl rand -hex 16)
echo "LIGHTRAG_API_KEY=$LIGHTRAG_API_KEY"
echo "TOKEN_SECRET=$TOKEN_SECRET"
echo "ADMIN_PASSWORD=$ADMIN_PASSWORD"
```

⛔ **ЗАПИШИ ЭТИ ЗНАЧЕНИЯ** — они понадобятся в конце для подключения агентов.

### .env для облачного провайдера (Polza.ai / OpenRouter / OpenAI)

```env
# ─── LLM ───
LLM_BINDING=openai
LLM_BINDING_HOST=<URL провайдера>
LLM_BINDING_API_KEY=<API ключ>
LLM_MODEL=google/gemini-2.5-flash
LLM_MAX_TOKEN_SIZE=32768

# ─── Embeddings ───
EMBEDDING_BINDING=openai
EMBEDDING_BINDING_HOST=<тот же URL провайдера>
EMBEDDING_BINDING_API_KEY=<тот же API ключ>
EMBEDDING_MODEL=openai/text-embedding-3-small
EMBEDDING_DIM=1536
EMBEDDING_MAX_TOKEN_SIZE=8192

# ─── PostgreSQL ───
# НЕ МЕНЯЙ — образ использует фиксированные rag/rag/rag
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=rag
POSTGRES_PASSWORD=rag
POSTGRES_DATABASE=rag

LIGHTRAG_KV_STORAGE=PGKVStorage
LIGHTRAG_VECTOR_STORAGE=PGVectorStorage
LIGHTRAG_GRAPH_STORAGE=PGGraphStorage
LIGHTRAG_DOC_STATUS_STORAGE=PGDocStatusStorage

# ─── Авторизация ───
LIGHTRAG_API_KEY=<сгенерированный>
AUTH_ACCOUNTS=admin:<сгенерированный пароль>
TOKEN_SECRET=<сгенерированный>
TOKEN_EXPIRE_HOURS=48

# ─── Безопасность ───
# Для localhost: CORS_ORIGINS=*
# Для домена: CORS_ORIGINS=https://lrag.your-domain.com
CORS_ORIGINS=<зависит от настройки — см. вопрос 2>
WHITELIST_PATHS=/health

# ─── Сервер ───
PORT=9621
HOST=0.0.0.0
LOG_LEVEL=INFO
TIMEOUT=150
```

**ВАЖНО:** переменная называется `POSTGRES_DATABASE` (НЕ `POSTGRES_DB`!).

### .env для Ollama (локальный, без API ключа)

Замени секцию LLM и Embeddings:
```env
LLM_BINDING=ollama
LLM_BINDING_HOST=http://host.docker.internal:11434
LLM_BINDING_API_KEY=ollama
LLM_MODEL=llama3.1:8b

EMBEDDING_BINDING=ollama
EMBEDDING_BINDING_HOST=http://host.docker.internal:11434
EMBEDDING_BINDING_API_KEY=ollama
EMBEDDING_MODEL=nomic-embed-text
EMBEDDING_DIM=768
EMBEDDING_MAX_TOKEN_SIZE=8192
```

Предварительно скачай модели:
```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text
```

## 5. Запуск

```bash
cd ~/lightrag
docker compose pull
docker compose up -d
```

Дождись запуска:
```bash
docker compose logs lightrag --tail 30
# Жди строку "Application startup complete"
```

Проверка:
```bash
curl -s http://localhost:9621/health | head -c 200
# Должен вернуть JSON со status: healthy
```

---

**Далее** → читай `docs/03-domain-proxy.md` (если нужен домен) или `docs/04-connect-agents.md` (если localhost)
