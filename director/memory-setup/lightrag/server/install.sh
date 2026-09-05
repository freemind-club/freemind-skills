#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         LightRAG — Полная автоматическая установка           ║
# ║                                                              ║
# ║  Запуск: curl -sSL https://... | bash                        ║
# ║  Или:    bash install.sh                                     ║
# ╚══════════════════════════════════════════════════════════════╝
set -e

# ─── Цвета и хелперы ──────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
error() { echo -e "  ${RED}✗${NC} $1"; }
hint()  { echo -e "  ${GRAY}$1${NC}"; }
header(){ echo -e "\n${BOLD}$1${NC}"; }

# Безопасное присвоение по имени переменной — БЕЗ eval.
# Валидируем имя (только [A-Za-z_][A-Za-z0-9_]*), значение через printf -v — не парсится шеллом.
_safe_set() {
  local varname="$1" val="$2"
  if [[ ! "$varname" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    error "Внутренняя ошибка: недопустимое имя переменной '$varname'"
    exit 1
  fi
  printf -v "$varname" '%s' "$val"
}

ask_default() {
  local prompt="$1" default="$2" varname="$3"
  local val
  read -r -p "$(echo -e "  ${BOLD}${prompt}${NC} [${CYAN}${default}${NC}]: ")" val
  _safe_set "$varname" "${val:-$default}"
}

ask_required() {
  local prompt="$1" varname="$2"
  local val=""
  while [ -z "$val" ]; do
    read -r -p "$(echo -e "  ${BOLD}${prompt}${NC}: ")" val
    [ -z "$val" ] && error "Это обязательное поле"
  done
  _safe_set "$varname" "$val"
}

ask_choice() {
  local prompt="$1" varname="$2"
  shift 2
  local options=("$@")
  echo -e "\n  ${BOLD}${prompt}${NC}"
  for i in "${!options[@]}"; do
    echo -e "    ${CYAN}$((i+1)))${NC} ${options[$i]}"
  done
  local choice
  while true; do
    read -r -p "$(echo -e "  ${BOLD}Выбор${NC} [1]: ")" choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
      _safe_set "$varname" "$choice"
      return
    fi
    error "Введи число от 1 до ${#options[@]}"
  done
}

# ─── Баннер ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     LightRAG — Установка и настройка     ║${NC}"
echo -e "${BOLD}║     База знаний для AI-агентов            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Проверки и автоустановка ───────────────────────────────
header "1. Проверка системы"

OS="linux"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
  info "macOS обнаружена"
else
  info "Linux обнаружена"
fi

# Docker — НЕ ставим автоматически: скрипт из интернета + sudo + группа docker (= root)
# должен запускать сам пользователь осознанно, не этот установщик молча.
if command -v docker &> /dev/null; then
  info "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
  error "Docker не найден."
  echo ""
  if [ "$OS" = "macos" ]; then
    hint "Установи Docker Desktop: https://docker.com/products/docker-desktop"
  else
    hint "Установи Docker сам (это установка с sudo и добавлением тебя в группу docker —"
    hint "это даёт права, эквивалентные root, поэтому автоматически мы это не делаем):"
    hint ""
    hint "  curl -fsSL https://get.docker.com | sh"
    hint "  sudo usermod -aG docker \$USER"
    hint "  # перелогинься (exit + зайди заново), затем проверь: docker run hello-world"
  fi
  echo ""
  hint "После установки Docker запусти этот скрипт заново."
  exit 1
fi

# Docker Compose
if docker compose version &> /dev/null; then
  info "Docker Compose: $(docker compose version --short 2>/dev/null || echo 'ok')"
else
  error "Docker Compose не найден. Обнови Docker."
  exit 1
fi

# openssl
if command -v openssl &> /dev/null; then
  info "openssl доступен"
else
  error "openssl не найден — установи: sudo apt install openssl"
  exit 1
fi

# ─── 2. Сценарий использования ─────────────────────────────────
header "2. Настройка"

ask_choice "Где устанавливаем?" INSTALL_MODE \
  "Сервер с доменом (VPS)" \
  "Локально (Mac Mini / localhost)"

DOMAIN=""
PROXY_MODE=4
LIGHTRAG_URL=""

if [ "$INSTALL_MODE" = "1" ]; then
  echo ""
  ask_required "Домен (например lrag.example.com)" DOMAIN
  LIGHTRAG_URL="https://${DOMAIN}"

  ask_choice "Reverse proxy для SSL:" PROXY_MODE \
    "Caddy — добавить к существующему" \
    "Caddy — установить новый (Docker)" \
    "Nginx Proxy Manager — настрою сам" \
    "Без прокси (только localhost:9621)"
else
  LIGHTRAG_URL="http://localhost:9621"
  info "URL: ${LIGHTRAG_URL}"
fi

# ─── API ───
echo ""
header "3. API провайдер"
hint "LightRAG использует LLM для извлечения сущностей из текста."
hint "Нужен OpenAI-совместимый API."
echo ""
hint "Популярные провайдеры:"
hint "  Polza.ai:   https://polza.ai/api/v1"
hint "  OpenRouter:  https://openrouter.ai/api/v1"
hint "  OpenAI:      https://api.openai.com/v1"
echo ""

ask_default "API endpoint" "https://polza.ai/api/v1" API_HOST
ask_required "API ключ" API_KEY

echo ""
header "4. Модели"
hint "LLM — для извлечения сущностей (главное — качество)"
hint "Embedding — для векторного поиска"
echo ""

ask_default "LLM модель" "google/gemini-2.5-flash" LLM_MODEL
ask_default "Embedding модель" "openai/text-embedding-3-small" EMBEDDING_MODEL

# ─── Caddy: путь к существующему Caddyfile ───
CADDY_FILE_PATH=""
if [ "$PROXY_MODE" = "1" ]; then
  echo ""
  ask_default "Путь к существующему Caddyfile" "/etc/caddy/Caddyfile" CADDY_FILE_PATH
fi

# ─── 3. Генерация секретов ─────────────────────────────────────
header "5. Генерация секретов"

LIGHTRAG_API_KEY=$(openssl rand -hex 32)
TOKEN_SECRET=$(openssl rand -hex 32)
ADMIN_SUFFIX=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $((RANDOM % 9000 + 1000)))
ADMIN_LOGIN="lrag_admin_${ADMIN_SUFFIX}"
ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
POSTGRES_PASSWORD=$(openssl rand -hex 20)

info "API ключ сгенерирован"
info "JWT секрет сгенерирован"
info "Логин: ${ADMIN_LOGIN}"
info "Пароль сгенерирован (16 символов)"
info "Пароль PostgreSQL сгенерирован (было бы небезопасно оставлять дефолтный rag/rag)"

# ─── 4. Создание файлов ───────────────────────────────────────
header "6. Создание конфигов"

INSTALL_DIR="${HOME}/lightrag"
# umask 077 — все файлы/папки ниже создаются без прав для group/other (0700/0600).
# Секреты (.env, docker-compose.yml с паролем) не должны быть читаемы другими пользователями системы.
umask 077
mkdir -p "${INSTALL_DIR}"
chmod 700 "${INSTALL_DIR}"

# --- docker-compose.yml ---
COMPOSE_CADDY_SERVICE=""
COMPOSE_CADDY_VOLUMES=""
COMPOSE_PORTS='      - "127.0.0.1:9621:9621"'
COMPOSE_EXTRA_NETWORKS=""
COMPOSE_EXTRA_NETWORK_DEF=""

if [ "$PROXY_MODE" = "2" ]; then
  # Caddy в Docker
  COMPOSE_PORTS='    expose:
      - "9621"'
  COMPOSE_CADDY_SERVICE="
  # ─── Caddy (reverse proxy + авто-SSL) ───
  caddy:
    image: caddy:2-alpine
    container_name: lightrag-caddy
    restart: unless-stopped
    ports:
      - \"80:80\"
      - \"443:443\"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - lightrag-net"
  COMPOSE_CADDY_VOLUMES="
  caddy_data:
  caddy_config:"
fi

cat > "${INSTALL_DIR}/docker-compose.yml" << COMPOSE_EOF
services:
  # ─── PostgreSQL (pgvector + Apache AGE) ───
  postgres:
    image: gzdaniel/postgres-for-rag:16.6
    container_name: lightrag-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: rag
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
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

  # ─── LightRAG Server ───
  lightrag:
    image: ghcr.io/hkuds/lightrag:1.4.9  # пин версии — обнови вручную после проверки changelog, не молча
    container_name: lightrag-server
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    env_file: .env
    ports:
${COMPOSE_PORTS}
    volumes:
      - rag_storage:/app/data/rag_storage
      - inputs:/app/data/inputs
    networks:
      - lightrag-net
${COMPOSE_CADDY_SERVICE}
volumes:
  postgres_data:
  rag_storage:
  inputs:${COMPOSE_CADDY_VOLUMES}

networks:
  lightrag-net:
    driver: bridge
COMPOSE_EOF

info "docker-compose.yml создан"

# --- .env ---
CORS_ORIGINS="*"
if [ -n "$DOMAIN" ]; then
  CORS_ORIGINS="https://${DOMAIN}"
fi

cat > "${INSTALL_DIR}/.env" << ENV_EOF
# ─── LLM ─────────────────────────────────────────────────────
LLM_BINDING=openai
LLM_BINDING_HOST=${API_HOST}
LLM_BINDING_API_KEY=${API_KEY}
LLM_MODEL=${LLM_MODEL}
LLM_MAX_TOKEN_SIZE=32768

# ─── Embeddings ──────────────────────────────────────────────
EMBEDDING_BINDING=openai
EMBEDDING_BINDING_HOST=${API_HOST}
EMBEDDING_BINDING_API_KEY=${API_KEY}
EMBEDDING_MODEL=${EMBEDDING_MODEL}
EMBEDDING_DIM=1536
EMBEDDING_MAX_TOKEN_SIZE=8192

# ─── PostgreSQL ──────────────────────────────────────────────
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=rag
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DATABASE=rag

LIGHTRAG_KV_STORAGE=PGKVStorage
LIGHTRAG_VECTOR_STORAGE=PGVectorStorage
LIGHTRAG_GRAPH_STORAGE=PGGraphStorage
LIGHTRAG_DOC_STATUS_STORAGE=PGDocStatusStorage

# ─── Авторизация ─────────────────────────────────────────────
LIGHTRAG_API_KEY=${LIGHTRAG_API_KEY}
AUTH_ACCOUNTS=${ADMIN_LOGIN}:${ADMIN_PASSWORD}
TOKEN_SECRET=${TOKEN_SECRET}
TOKEN_EXPIRE_HOURS=48

# ─── Безопасность ────────────────────────────────────────────
CORS_ORIGINS=${CORS_ORIGINS}
WHITELIST_PATHS=/health

# ─── Сервер ──────────────────────────────────────────────────
PORT=9621
HOST=0.0.0.0
LOG_LEVEL=INFO
TIMEOUT=150
ENV_EOF

chmod 600 "${INSTALL_DIR}/.env"
chmod 600 "${INSTALL_DIR}/docker-compose.yml"
info ".env создан (chmod 600)"

# --- Caddyfile ---
if [ "$PROXY_MODE" = "1" ]; then
  # Добавить к существующему Caddy
  CADDY_BLOCK="
# ─── LightRAG ───
${DOMAIN} {
    reverse_proxy 127.0.0.1:9621

    header {
        Strict-Transport-Security \"max-age=31536000;\"
        X-Content-Type-Options \"nosniff\"
        X-Frame-Options \"DENY\"
    }
}
"
  if [ -f "$CADDY_FILE_PATH" ]; then
    echo "$CADDY_BLOCK" | sudo tee -a "$CADDY_FILE_PATH" > /dev/null
    sudo caddy reload --config "$CADDY_FILE_PATH" 2>/dev/null || warn "Перезагрузи Caddy: sudo systemctl reload caddy"
    info "Блок добавлен в ${CADDY_FILE_PATH}"
  else
    warn "Файл ${CADDY_FILE_PATH} не найден — создаю"
    echo "$CADDY_BLOCK" | sudo tee "$CADDY_FILE_PATH" > /dev/null
    info "Caddyfile создан: ${CADDY_FILE_PATH}"
  fi
elif [ "$PROXY_MODE" = "2" ]; then
  # Caddy в Docker
  cat > "${INSTALL_DIR}/Caddyfile" << CADDY_EOF
${DOMAIN} {
    reverse_proxy lightrag:9621

    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
    }
}
CADDY_EOF
  info "Caddyfile создан"
fi

# --- credentials.txt ---
cat > "${INSTALL_DIR}/credentials.txt" << CREDS_EOF
# ╔══════════════════════════════════════════════════════════════╗
# ║  LightRAG — Учётные данные                                  ║
# ║  ХРАНИ ЭТОТ ФАЙЛ В БЕЗОПАСНОМ МЕСТЕ!                        ║
# ╚══════════════════════════════════════════════════════════════╝

URL:          ${LIGHTRAG_URL}
Веб-логин:    ${ADMIN_LOGIN}
Веб-пароль:   ${ADMIN_PASSWORD}
API ключ:     ${LIGHTRAG_API_KEY}
JWT секрет:   ${TOKEN_SECRET}

API endpoint: ${API_HOST}
LLM модель:   ${LLM_MODEL}
Embed модель: ${EMBEDDING_MODEL}
CREDS_EOF
chmod 600 "${INSTALL_DIR}/credentials.txt"
info "credentials.txt создан (chmod 600)"

# ─── 5. Запуск ─────────────────────────────────────────────────
header "7. Запуск LightRAG"

cd "${INSTALL_DIR}"
docker compose up -d 2>&1 | grep -E "Started|Created|Pulling|Error" || true

# Ожидание PG
echo -ne "  Жду PostgreSQL..."
for i in $(seq 1 30); do
  if docker exec lightrag-postgres pg_isready -U rag &>/dev/null; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 1
  if [ "$i" = "30" ]; then
    echo -e " ${RED}таймаут${NC}"
    error "PostgreSQL не запустился. Проверь: docker compose logs postgres"
    exit 1
  fi
done

# Образ gzdaniel/postgres-for-rag может создавать пользователя rag на этапе сборки
# образа, а не только через initdb — тогда переданный нами POSTGRES_PASSWORD может
# не примениться, и реальным паролем останется старый/дефолтный. Проверяем это,
# а не верим переменной на слово.
if docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" lightrag-postgres psql -U rag -d rag -c "SELECT 1" &>/dev/null; then
  info "Пароль PostgreSQL подтверждён рабочим (не дефолтный)"
else
  warn "Сгенерированный пароль PostgreSQL не подошёл при проверке — похоже, образ"
  warn "gzdaniel/postgres-for-rag игнорирует POSTGRES_PASSWORD после первой сборки."
  warn "Реальный пароль БД может остаться дефолтным. Смени его вручную:"
  hint "  docker exec -it lightrag-postgres psql -U rag -d rag -c \"ALTER USER rag WITH PASSWORD '${POSTGRES_PASSWORD}';\""
fi

# Ожидание LightRAG
echo -ne "  Жду LightRAG..."
HEALTH_URL="http://localhost:9621/health"
for i in $(seq 1 60); do
  if curl -sf "$HEALTH_URL" &>/dev/null; then
    echo -e " ${GREEN}✓${NC}"
    break
  fi
  echo -n "."
  sleep 2
  if [ "$i" = "60" ]; then
    echo -e " ${RED}таймаут${NC}"
    error "LightRAG не запустился. Проверь: docker compose logs lightrag"
    exit 1
  fi
done

# ─── 6. Итоги ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  ${GREEN}LightRAG установлен и работает!${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
# Секреты в терминал НЕ печатаем — терминал попадает в scrollback, tmux-логи,
# скриншоты, историю CI. Полные значения — только в credentials.txt (chmod 600).
echo -e "  ${BOLD}URL:${NC}        ${CYAN}${LIGHTRAG_URL}${NC}"
echo -e "  ${BOLD}Логин:${NC}      ${ADMIN_LOGIN}"
echo -e "  ${BOLD}Пароль:${NC}     ****$(printf '%s' "$ADMIN_PASSWORD" | tail -c 4)   (полностью — в credentials.txt)"
echo -e "  ${BOLD}API ключ:${NC}   ****$(printf '%s' "$LIGHTRAG_API_KEY" | tail -c 4)   (полностью — в credentials.txt)"
echo ""

# --- Claude Code (локальный Mac) ---
echo -e "  ${BOLD}─── Подключение к Claude Code (локально на Mac) ───${NC}"
echo ""
echo -e "  ${CYAN}claude mcp add --scope user lightrag \\\\${NC}"
echo -e "  ${CYAN}  -e LIGHTRAG_SERVER_URL=\"${LIGHTRAG_URL}\" \\\\${NC}"
echo -e "  ${CYAN}  -e LIGHTRAG_API_KEY=\"${LIGHTRAG_API_KEY}\" \\\\${NC}"
echo -e "  ${CYAN}  -- npx -y @g99/lightrag-mcp-server${NC}"
echo ""

# --- Claude Code (на сервере) ---
echo -e "  ${BOLD}─── Подключение к Claude Code (на сервере) ───${NC}"
echo ""
echo -e "  ${CYAN}claude mcp add --scope user lightrag \\\\${NC}"
echo -e "  ${CYAN}  -e LIGHTRAG_SERVER_URL=\"http://localhost:9621\" \\\\${NC}"
echo -e "  ${CYAN}  -e LIGHTRAG_API_KEY=\"${LIGHTRAG_API_KEY}\" \\\\${NC}"
echo -e "  ${CYAN}  -- npx -y @g99/lightrag-mcp-server${NC}"
echo ""

# --- OpenClaw (на сервере) ---
echo -e "  ${BOLD}─── Подключение к OpenClaw (на сервере) ───${NC}"
echo ""
echo -e "  Через CLI (рекомендуется):"
echo -e "  ${CYAN}openclaw mcp set lightrag '{\"command\":\"npx\",\"args\":[\"-y\",\"@g99/lightrag-mcp-server\"],\"env\":{\"LIGHTRAG_SERVER_URL\":\"http://localhost:9621\",\"LIGHTRAG_API_KEY\":\"${LIGHTRAG_API_KEY}\"}}'${NC}"
echo ""
echo -e "  Через домен (если OpenClaw на другой машине):"
echo -e "  ${CYAN}openclaw mcp set lightrag '{\"command\":\"npx\",\"args\":[\"-y\",\"@g99/lightrag-mcp-server\"],\"env\":{\"LIGHTRAG_SERVER_URL\":\"${LIGHTRAG_URL}\",\"LIGHTRAG_API_KEY\":\"${LIGHTRAG_API_KEY}\"}}'${NC}"
echo ""
echo -e "  Перезапусти: ${CYAN}docker restart <контейнер-openclaw>${NC}"
echo ""

# --- NPM инструкция ---
if [ "$PROXY_MODE" = "3" ]; then
  echo -e "  ${BOLD}─── Nginx Proxy Manager ───${NC}"
  echo ""
  echo -e "  В админке NPM добавь Proxy Host:"
  echo -e "    Domain:           ${CYAN}${DOMAIN}${NC}"
  echo -e "    Forward Hostname: ${CYAN}lightrag-server${NC}"
  echo -e "    Forward Port:     ${CYAN}9621${NC}"
  echo -e "    SSL:              Request new certificate, Force SSL"
  echo ""
  warn "NPM и LightRAG должны быть в одной Docker-сети!"
  echo -e "  Подключи: ${CYAN}docker network connect <сеть-npm> lightrag-server${NC}"
  echo ""
fi

echo -e "  ${BOLD}─── Не забудь! ───${NC}"
echo ""
echo -e "  Добавь инструкции памяти агентам (файлы в agents/):"
echo -e "  ${CYAN}Claude Code:${NC}  cat agents/CLAUDE.md >> ~/.claude/CLAUDE.md"
echo -e "  ${CYAN}OpenClaw:${NC}     cat agents/AGENTS.md >> ~/.openclaw/workspace/AGENTS.md"
echo ""
echo -e "  ${BOLD}Кредсы сохранены:${NC} ${INSTALL_DIR}/credentials.txt"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
