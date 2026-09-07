# Шаг 5: Проверка и вывод результатов

⛔ **ЭТОТ ШАГ ОБЯЗАТЕЛЬНЫЙ.** Установка НЕ считается завершённой без проверки и вывода credentials.

---

## 1. Проверка health endpoint

```bash
# Локально (на сервере):
curl -s http://localhost:9621/health | python3 -m json.tool

# Через домен (если настроен):
curl -s https://lrag.your-domain.com/health | python3 -m json.tool
```

Ожидаемый ответ: `"status": "healthy"`

Если не работает:
```bash
docker compose logs lightrag --tail 30
docker ps -a  # проверь что контейнеры running
```

## 2. Проверка API-ключа

```bash
curl -s -H "X-API-Key: <LIGHTRAG_API_KEY>" http://localhost:9621/documents | head -c 200
```

Должен вернуть JSON (пустой список документов), а не 401 Unauthorized.

## 3. Проверка MCP

```bash
# Claude Code:
claude mcp list
# Должен показать: lightrag: connected

# OpenClaw — проверь что MCP в конфиге:
cat ~/.openclaw/openclaw.json | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('mcp',{}), indent=2))"
```

## 4. Тест через агентов

Через **каждого** подключённого агента:
1. Скажи: `remember LightRAG подключён и работает`
2. Подожди 15 секунд
3. Скажи: `recall LightRAG`
4. Агент должен вернуть то, что записал

Если не работает:
- Нет ответа на "remember" → инструкции не добавлены (проверь CLAUDE.md / AGENTS.md)
- Ошибка MCP → MCP не настроен или URL неправильный
- Connection refused → контейнер не запущен или порт неправильный

---

## ⛔ 5. ОБЯЗАТЕЛЬНО ВЫДАЙ ПОЛЬЗОВАТЕЛЮ ЭТУ ИНФОРМАЦИЮ

После завершения установки **ВСЕГДА** выведи пользователю следующую сводку. Это критически важно — без этой информации пользователь не сможет управлять системой и подключать новые агенты.

### Шаблон вывода:

```
=== LightRAG установлен ===

Сервер: <IP или hostname>
URL (локальный): http://localhost:9621
URL (внешний): https://lrag.your-domain.com (если настроен домен)
Health: <статус — healthy/unhealthy>

--- Credentials ---

LIGHTRAG_API_KEY: <полный ключ>
  (для подключения агентов через MCP)

Веб-интерфейс: https://lrag.your-domain.com (или http://localhost:9621)
  Логин: admin
  Пароль: <пароль из AUTH_ACCOUNTS>

--- Подключённые агенты ---

Claude Code: ✓/✗ (MCP: ✓/✗, инструкции: ✓/✗)
OpenClaw: ✓/✗ (MCP: ✓/✗, инструкции: ✓/✗)
Paperclip: наследует от Claude Code

--- Команды для подключения новых агентов ---

Claude Code (на этом сервере):
  claude mcp add --scope user lightrag \
    -e LIGHTRAG_SERVER_URL="http://localhost:9621" \
    -e LIGHTRAG_API_KEY="<ключ>" \
    -- npx -y @g99/lightrag-mcp-server

Claude Code (с другой машины):
  claude mcp add --scope user lightrag \
    -e LIGHTRAG_SERVER_URL="https://lrag.your-domain.com" \
    -e LIGHTRAG_API_KEY="<ключ>" \
    -- npx -y @g99/lightrag-mcp-server

OpenClaw (на этом сервере):
  openclaw mcp set lightrag '{"command":"npx","args":["-y","@g99/lightrag-mcp-server@1.1.0"],"env":{"LIGHTRAG_SERVER_URL":"http://localhost:9621","LIGHTRAG_API_KEY":"<ключ>"}}'

--- Полезные команды ---

Логи:       cd ~/lightrag && docker compose logs lightrag --tail 30
Перезапуск: cd ~/lightrag && docker compose restart
Остановка:  cd ~/lightrag && docker compose down
Бэкап:      docker exec lightrag-postgres pg_dump -U rag rag > backup.sql
Обновление: cd ~/lightrag && docker compose pull && docker compose up -d
```

⛔ **НЕ ПРОПУСКАЙ ЭТОТ ВЫВОД.** Пользователь должен видеть credentials, URL, и команды подключения. Без этого он не сможет:
- Подключить новые агенты
- Зайти в веб-интерфейс
- Управлять системой

---

**Справка** → `docs/06-maintenance.md` (бэкап, безопасность, обновление)
