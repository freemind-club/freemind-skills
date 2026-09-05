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

### PostgreSQL (пользователь rag, пароль — сгенерированный)

Безопасно — PG не пробрасывает порт наружу, доступен только внутри Docker-сети.

### Опционально: fail2ban

⚠️ Меняет системные службы (`/etc/fail2ban/*`, `systemctl restart fail2ban`) — это отдельное действие с sudo на живом сервере, не часть стандартной настройки памяти. Выполняй только по отдельной просьбе пользователя, не молча вместе с остальной установкой.

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

## Полный сброс (удалит ВСЕ данные — необратимо!)

⛔ Это не рутинное обслуживание. Выполняй ТОЛЬКО когда пользователь явно попросил стереть всю память и подтвердил, что понимает — назад пути нет. Перед этим — сделай бэкап (см. раздел «Бэкап» выше) и покажи пользователю путь к файлу бэкапа.

```bash
cd ~/lightrag
# Бэкап перед сбросом — обязательно:
docker exec lightrag-postgres pg_dump -U rag rag > ~/backups/before_reset_$(date +%Y%m%d_%H%M%S).sql

# Подтверждение — пользователь должен ввести точное имя ресурса, не просто "да":
read -r -p "Для необратимого удаления памяти введи 'УДАЛИТЬ ВСЁ': " CONFIRM
if [ "$CONFIRM" != "УДАЛИТЬ ВСЁ" ]; then
  echo "Отменено."
  exit 1
fi

docker compose down
docker volume rm lightrag_postgres_data lightrag_rag_storage lightrag_inputs
docker compose up -d
```
