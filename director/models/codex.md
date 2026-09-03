# Codex (модель для кода)

**Роль:** делегат кода — генерация/правка по чёткому образцу, рефакторинг, тесты.

> Это про **модель через API**. Codex CLI как отдельный агент-исполнитель → [../adapters/codex-cli.md](../adapters/codex-cli.md).

| | |
|--|--|
| base_url | `https://api.openai.com/v1` |
| Ключ (env) | `OPENAI_API_KEY` |
| API-формат | OpenAI Chat Completions / Responses |
| Модели | `gpt-5.1-codex`, `gpt-5-codex` (код-специализированные) |

## Когда

- Код > 5 строк по понятному ТЗ
- Массовые однотипные правки в файлах
- Написание тестов по существующему коду

## Когда НЕ

- Архитектурные решения по коду → `SELF_MODEL`
- Отладка с рассуждением → `SELF_MODEL` или DeepSeek-reasoner

## Вызов

```bash
curl https://api.openai.com/v1/chat/completions -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-5-codex","messages":[{"role":"user","content":"<точное ТЗ + контекст файла>"}]}'
```

Ответ — в файл, директор проверяет файл (не верит на слово).
