# Шаг 4: Подключение агентов

⛔ Убедись что LightRAG запущен и health endpoint отвечает (шаг 2 или 3).

---

## Как это работает — MCP + инструкции

Подключение состоит из **двух частей**:

| Часть | Что | Где | Зачем |
|---|---|---|---|
| **MCP** | Техническое подключение | Конфиг агента (settings.json, openclaw.json) | Даёт возможность вызывать LightRAG API |
| **Инструкции** | Когда/что запоминать | Файл инструкций агента (CLAUDE.md, AGENTS.md) | Объясняет агенту как пользоваться памятью |

Без MCP — агент не может обращаться к LightRAG.
Без инструкций — агент не знает что у него есть LightRAG.
**Нужны ОБЕ части.**

⛔ **НЕ ПЕРЕЗАПИСЫВАЙ существующие конфиги** — ДОПОЛНЯЙ их. Если в AGENTS.md или CLAUDE.md уже есть содержимое — добавляй блок в конец, не удаляй то что есть.

---

## Определи URL LightRAG

- **Агент на том же сервере** → `http://localhost:9621`
- **Агент на другой машине** → `https://lrag.your-domain.com` (нужен домен из шага 3)

---

## Claude Code (CLI — терминал)

### MCP

```bash
# Если Claude Code на том же сервере что и LightRAG:
claude mcp add --scope user lightrag \
  -e LIGHTRAG_SERVER_URL="http://localhost:9621" \
  -e LIGHTRAG_API_KEY="<LIGHTRAG_API_KEY из .env>" \
  -- npx -y @g99/lightrag-mcp-server

# Если Claude Code на другой машине (Mac, ноутбук):
claude mcp add --scope user lightrag \
  -e LIGHTRAG_SERVER_URL="https://lrag.your-domain.com" \
  -e LIGHTRAG_API_KEY="<LIGHTRAG_API_KEY из .env>" \
  -- npx -y @g99/lightrag-mcp-server
```

Или через `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "lightrag": {
      "command": "npx",
      "args": ["-y", "@g99/lightrag-mcp-server@1.1.0"],
      "env": {
        "LIGHTRAG_SERVER_URL": "<URL>",
        "LIGHTRAG_API_KEY": "<LIGHTRAG_API_KEY>"
      }
    }
  }
}
```

⛔ Если `settings.json` уже содержит другие `mcpServers` — **ДОБАВЬ** `lightrag` в существующий объект, не перезаписывай!

---

## Claude Desktop (приложение macOS/Windows)

⚠️ **ВАЖНО:** Claude Desktop использует **отдельный конфиг**, отличный от CLI. Если добавил LightRAG в CLI через `claude mcp add` — он НЕ появится в Claude Desktop автоматически. Нужно добавить в оба места.

### MCP

Файл конфига:
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

Добавь `lightrag` в объект `mcpServers`:

```json
{
  "mcpServers": {
    "lightrag": {
      "command": "npx",
      "args": ["-y", "@g99/lightrag-mcp-server@1.1.0"],
      "env": {
        "LIGHTRAG_SERVER_URL": "<URL>",
        "LIGHTRAG_API_KEY": "<LIGHTRAG_API_KEY>"
      }
    }
  }
}
```

⛔ Если в `claude_desktop_config.json` уже есть другие `mcpServers` — **ДОБАВЬ** `lightrag` рядом, не перезаписывай!

После изменения конфига — **перезапусти Claude Desktop** (полностью закрыть и открыть заново).

### Инструкции

Добавь блок памяти в `~/.claude/CLAUDE.md` (глобально) 

```bash
# Проверь что блока ещё нет:
grep -q "LightRAG" ~/.claude/CLAUDE.md 2>/dev/null && echo "уже есть" || cat agents/CLAUDE.md >> ~/.claude/CLAUDE.md
```

Содержимое блока — файл `agents/CLAUDE.md` из этого репозитория.

---

## OpenClaw

### MCP

```bash
# Если OpenClaw на том же сервере:
openclaw mcp set lightrag '{"command":"npx","args":["-y","@g99/lightrag-mcp-server@1.1.0"],"env":{"LIGHTRAG_SERVER_URL":"http://localhost:9621","LIGHTRAG_API_KEY":"<LIGHTRAG_API_KEY>"}}'

# Если OpenClaw на другой машине:
openclaw mcp set lightrag '{"command":"npx","args":["-y","@g99/lightrag-mcp-server@1.1.0"],"env":{"LIGHTRAG_SERVER_URL":"https://lrag.your-domain.com","LIGHTRAG_API_KEY":"<LIGHTRAG_API_KEY>"}}'
```

Или через `~/.openclaw/openclaw.json` — добавь в `mcp.servers`:
```json
{
  "mcp": {
    "servers": {
      "lightrag": {
        "command": "npx",
        "args": ["-y", "@g99/lightrag-mcp-server@1.1.0"],
        "env": {
          "LIGHTRAG_SERVER_URL": "<URL>",
          "LIGHTRAG_API_KEY": "<LIGHTRAG_API_KEY>"
        }
      }
    }
  }
}
```

⛔ Если в `mcp.servers` уже есть другие серверы — **ДОБАВЬ** `lightrag` рядом, не перезаписывай!

### Инструкции — главный агент

```bash
grep -q "LightRAG" ~/.openclaw/workspace/AGENTS.md 2>/dev/null && echo "уже есть" || cat agents/AGENTS.md >> ~/.openclaw/workspace/AGENTS.md
```

### Инструкции — суб-агенты (если есть)

```bash
# Посмотри какие агенты есть:
ls ~/.openclaw/agents/ 2>/dev/null

# Добавь каждому:
for agent_dir in ~/.openclaw/agents/*/; do
  [ -d "$agent_dir" ] || continue
  name=$(basename "$agent_dir")
  if grep -q "LightRAG" "${agent_dir}AGENTS.md" 2>/dev/null; then
    echo "${name}: уже есть"
  else
    cat agents/AGENTS.md >> "${agent_dir}AGENTS.md"
    echo "${name}: добавлено"
  fi
done
```

### Перезапуск

После добавления MCP перезапусти OpenClaw:
```bash
docker restart <контейнер-openclaw>
# или если не в Docker:
openclaw gateway restart
```

---

## Paperclip

Paperclip — суб-агент Claude Code. Он **наследует MCP и CLAUDE.md автоматически**. Дополнительная настройка не нужна.

Если у Paperclip есть свой проектный конфиг — добавь блок памяти по аналогии с Claude Code.

---

## Другие агенты / свои боты

Для любого агента с поддержкой MCP:

1. **MCP-сервер:**
   ```
   npx -y @g99/lightrag-mcp-server
   ```
   Переменные:
   ```
   LIGHTRAG_SERVER_URL=<URL LightRAG>
   LIGHTRAG_API_KEY=<ключ>
   ```

2. **Инструкции** — добавь в системный промпт агента:
   ```
   У тебя есть MCP-инструменты LightRAG — общая база знаний.

   При старте сессии: ищи контекст через query_text (mode: hybrid). Молча.
   Во время работы: сохраняй важные факты через insert_text. Не жди конца сессии.
   Сохраняй: решения, предпочтения, факты о проектах, баги, личную информацию.
   Пропускай: опечатки, отладку, дубли, временные значения.
   Формат: 1-3 предложения. Указывай проект и причину.

   "remember <текст>" → сохрани через insert_text.
   "recall <тема>" → найди через query_text (hybrid), покажи результат.
   ```

---

**Далее** → читай `docs/05-verify-and-output.md`
