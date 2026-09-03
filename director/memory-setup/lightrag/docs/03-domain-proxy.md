# Шаг 3: Домен и Reverse Proxy

⛔ Этот шаг нужен ТОЛЬКО если пользователь ответил "да" на вопрос про домен (шаг 1, вопрос 2).
Если LightRAG работает только на localhost — **пропусти этот файл**, переходи к `04-connect-agents.md`.

---

## 1. Проверь DNS

A-запись должна быть создана ЗАРАНЕЕ: `lrag.your-domain.com → IP_сервера`

```bash
dig +short lrag.your-domain.com
# Должен вернуть IP сервера
```

Если не возвращает — DNS ещё не распространился. Подожди или попроси пользователя проверить настройки DNS.

## 2. Определи какой reverse proxy стоит на сервере

```bash
systemctl is-active caddy 2>/dev/null       # → active = Caddy
docker ps | grep -iE 'nginx|proxy|npm'      # → есть = Nginx Proxy Manager
docker ps | grep traefik                     # → есть = Traefik
```

## 3. Настрой reverse proxy

### Вариант A: Nginx Proxy Manager (NPM)

1. Подключи контейнер LightRAG к сети NPM:
```bash
# Найди сеть NPM:
docker network ls | grep -i nginx
# Подключи:
docker network connect <сеть-npm> lightrag-server
```

2. В админке NPM → **Add Proxy Host**:
   - **Domain:** `lrag.your-domain.com`
   - **Forward Hostname:** `lightrag-server` (имя контейнера, НЕ 127.0.0.1!)
   - **Forward Port:** `9621`
   - **SSL:** Request a new SSL Certificate, Force SSL

### Вариант B: Caddy (системный)

Добавь блок в Caddyfile (обычно `/etc/caddy/Caddyfile`):
```
lrag.your-domain.com {
    reverse_proxy 127.0.0.1:9621
    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
    }
}
```

```bash
sudo systemctl reload caddy
```

### Вариант C: Ничего нет — поставь Caddy в Docker

Используй скрипт `install.sh` (способ 1 в INSTALL.md) — он умеет поставить Caddy автоматически.

Или добавь Caddy в docker-compose.yml вручную:
```yaml
  caddy:
    image: caddy:2
    container_name: lightrag-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - lightrag-net
```

И создай `Caddyfile`:
```
lrag.your-domain.com {
    reverse_proxy lightrag:9621
}
```

## 4. После настройки прокси

1. Обнови `CORS_ORIGINS` в `.env`:
```bash
# Замени на свой домен:
sed -i 's|CORS_ORIGINS=.*|CORS_ORIGINS=https://lrag.your-domain.com|' ~/lightrag/.env
```

2. Перезапусти LightRAG:
```bash
cd ~/lightrag && docker compose restart lightrag
```

3. Проверь через домен:
```bash
curl -sf https://lrag.your-domain.com/health
# Должен вернуть JSON со status: healthy
```

Если не работает — проверь логи:
```bash
docker compose logs lightrag --tail 20
docker compose logs caddy --tail 20  # если Caddy в Docker
```

---

**Далее** → читай `docs/04-connect-agents.md`
