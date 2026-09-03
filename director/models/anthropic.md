# Claude (Anthropic) — модель-оркестратор по умолчанию

**Роль:** `SELF_MODEL` — сам директор: архитектура, оркестрация, общение, контроль.

| | |
|--|--|
| base_url | `https://api.anthropic.com` (или подписка Claude Code — модель уже активна) |
| Ключ env | `ANTHROPIC_API_KEY` |
| API | Anthropic Messages (`/v1/messages`), **не** OpenAI-формат |
| Модели | `claude-opus-4` (сложное), `claude-sonnet-4.5` (баланс), `claude-haiku-4.5` (быстро) |

## Когда

Только: разбор задачи, план, выбор инструмента, оркестрация субагентов, контроль, общение с {{USER_NAME}}, код где логика неочевидна (< ~5 строк).

## Когда НЕ

Рерайт, переводы, резюме, фильтрация, пакетная обработка, код по образцу → `CHEAP_STACK`.

## Фолбэк

Лимиты подписки Claude Code кончились → `SELF_MODEL` временно берётся из `CHEAP_STACK` (обычно OpenRouter `anthropic/claude-sonnet-4.5` или OmniRoute `kiro/claude-sonnet-4.5`).
