# Справка: Обслуживание, безопасность, обновление

Этот файл — справочный. Не обязателен при установке.

---

## Безопасность

### Чеклист
- [ ] `LIGHTRAG_API_KEY` — сгенерирован (64 символа hex)
- [ ] `TOKEN_SECRET` — сгенерирован (64 символа hex)
- [ ] `AUTH_ACCOUNTS` — пароль установлен
- [ ] `CORS_ORIGINS` — только твой домен, не `*` (для серверной установки с доменом)
- [ ] Порт 9621 слушает на `127.0.0.1` (не `0.0.0.0`)
- [ ] SSL работает (https) — если есть домен
- [ ] UFW: только 22, 80, 443

### Две системы авторизации

| Что | Для кого | Как передаётся |
|---|---|---|
| API Key (`X-API-Key`) | Агенты, скрипты, MCP | HTTP-заголовок |
| Логин/пароль (JWT) | Человек в браузере | Форма логина → токен |

### PostgreSQL (rag/rag)

Безопасно — PG не пробрасывает порт наружу, доступен только внутри Docker-сети.

### Опционально: fail2ban

```bash
sudo apt install fail2ban -y
sudo tee /etc/fail2ban/jail.d/lightrag.conf << 'EOF'
[lightrag-auth]
enabled = true
port = http,https
filter = lightrag-auth
logpath = /var/lib/docker/volumes/*npm*/_data/logs/*.log
maxretry = 5
bantime = 3600
EOF
sudo tee /etc/fail2ban/filter.d/lightrag-auth.conf << 'EOF'
[Definition]
failregex = <HOST>.*"(GET|POST).*" 401
EOF
sudo systemctl restart fail2ban
```

---

## Бэкап

### Ручной
```bash
docker exec lightrag-postgres pg_dump -U rag rag > backup_$(date +%Y%m%d).sql
```

### Автоматический (cron, каждый день в 3:00)
```bash
mkdir -p ~/backups
crontab -e
# Добавь:
0 3 * * * docker exec lightrag-postgres pg_dump -U rag rag | gzip > ~/backups/lightrag_$(date +\%Y\%m\%d).sql.gz
0 4 * * * find ~/backups -name "lightrag_*.sql.gz" -mtime +30 -delete
```

---

## Обновление

```bash
cd ~/lightrag && docker compose pull && docker compose up -d
```

---

## Логи

```bash
docker compose logs lightrag --tail 50
docker compose logs -f lightrag  # в реальном времени
```

---

## Размер данных

```bash
docker exec lightrag-postgres psql -U rag -c "SELECT pg_size_pretty(pg_database_size('rag'));"
```

---

## Полный сброс (удалит ВСЕ данные!)

```bash
cd ~/lightrag
docker compose down
docker volume rm lightrag_postgres_data lightrag_rag_storage lightrag_inputs
docker compose up -d
```
