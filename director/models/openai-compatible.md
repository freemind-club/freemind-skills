# OpenAI-совместимые провайдеры и шлюзы

Все говорят на **OpenAI Chat Completions** (`POST {base_url}/chat/completions`, `Authorization: Bearer <key>`). Меняется только `base_url`, ключ и имена моделей. Один код вызова на всех.

```bash
curl "$BASE_URL/chat/completions" -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"<модель>","messages":[{"role":"user","content":"..."}]}'
```

| Провайдер | base_url | ключ env | рабочие модели | роль |
|-----------|----------|----------|----------------|------|
| **OpenAI** | `https://api.openai.com/v1` | `OPENAI_API_KEY` | `gpt-5.1`, `gpt-5-mini`, `gpt-5-nano` | оркестратор без Claude / фолбэк |
| **xAI Grok** | `https://api.x.ai/v1` | `XAI_API_KEY` | `grok-4`, `grok-4-fast`, `grok-code-fast-1` | пачка / код / фолбэк |
| **DeepSeek** | `https://api.deepseek.com` | `DEEPSEEK_API_KEY` | `deepseek-chat` (код), `deepseek-reasoner` (отладка) | код + reasoner, очень дёшево |
| **Gemini** | `https://generativelanguage.googleapis.com/v1beta/openai` | `GEMINI_API_KEY` | `gemini-2.5-pro`, `gemini-2.5-flash`, `-flash-lite` | пачка / большой контекст / сущности LightRAG |
| **OpenRouter** | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` | `anthropic/claude-sonnet-4.5`, `deepseek/deepseek-chat`, `google/gemini-2.5-flash`, `:free`-модели | пачка + авто-фолбэк (`models:[...]` в теле) |
| **OmniRoute** (FreeMind) | `http://localhost:20128/v1` | `OMNIROUTE_API_KEY` | `kiro/claude-sonnet-4.5`, `openai/gpt-4o-mini`, `groq/llama-3.3-70b` | пачка + Claude через `kiro/*` + фолбэк |
| **Polza.ai** (RU) | `https://polza.ai/api/v1` | `POLZA_API_KEY` | `google/gemini-2.5-flash-lite`, `openai/text-embedding-3-small` | **дефолт LightRAG** (LLM+эмбеддинги) + пачка |
| **Groq** | `https://api.groq.com/openai/v1` | `GROQ_API_KEY` | `llama-3.3-70b-versatile`, `llama-3.1-8b-instant` | быстрая бесплатная пачка, фильтр |
| **Fireworks** | `https://api.fireworks.ai/inference/v1` | `FIREWORKS_API_KEY` | `accounts/fireworks/models/llama-v3p3-70b-instruct`, `...qwen2p5-coder-32b-instruct` | код > 5 строк, n8n Code node |
| **SambaNova** | `https://api.sambanova.ai/v1` | `SAMBANOVA_API_KEY` | `Meta-Llama-3.3-70B-Instruct`, `DeepSeek-V3` | резерв пачки/кода |

## Как выбирать в `CHEAP_STACK`

- Есть FreeMind-стек → **OmniRoute** первым (Claude через `kiro`, один ключ).
- Нет, но нужен Claude на подхвате → **OpenRouter**.
- Просто быстро и бесплатно → **Groq** (текст) / **Fireworks** (код).
- Оплата в рублях → **Polza.ai**.
- Код/отладка дёшево → **DeepSeek**.

## Особенности

- `:free` (OpenRouter) — ноль цены, жёсткие лимиты и очередь. Демо/пачка — ок, прод — платные.
- Groq иногда отбивает лишние параметры (`reasoning_effort`) — слать минимальное тело.
- Fireworks: имя модели — полный путь `accounts/fireworks/models/...`.
- Секреты — в `~/.director/models.env` пользователя (см. `_template` там же), не в скилле.
