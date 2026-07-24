# Hermes-ecosystem

[Hermes-agent](https://github.com/NousResearch/hermes-agent) — отдельный от Claude Code агент, которым мы реально пользуемся (канбан-доски, фоновые воркеры). У него своя экосистема скиллов — не путать с `skills-base/` (это Claude Code / Codex / OpenClaw).

Источник: [awesome-hermes-skills](https://github.com/ZeroPointRepo/awesome-hermes-skills) — каталог 250+ скиллов (72 built-in + 101 optional + community). Проверено 21.07.2026: бóльшая часть уже стоит у нас из коробки. Ниже — то, что реально стоит добавить.

| Скилл | Что делает | Зачем | Хештеги |
|-------|-----------|-------|---------|
| [youtube-full](https://github.com/ZeroPointRepo/youtube-skills) | YouTube транскрипты/поиск через TranscriptAPI.com | Встроенный `youtube-content` не работает с VPS/облака — YouTube блокирует облачные IP. Прямой апгрейд | `#youtube` `#hermes` `#vps` |
| [rtk](https://github.com/akillness/oh-my-skills) | Сжимает вывод терминала перед тем как он попадёт в контекст LLM (60-90% экономии токенов) | Токены — реальная боль на параллельных kanban-воркерах | `#tokens` `#optimization` `#hermes` |
| [watchers](https://github.com/NousResearch/hermes-agent/tree/main/optional-skills) | Поллинг RSS/JSON API/GitHub с dedup по watermark | Дополняет `blogwatcher` (только RSS) — подходит под контент-конвейеры | `#rss` `#automation` `#hermes` |
| duckduckgo-search / searxng-search | Бесплатный веб-поиск без API ключа | Фоллбэк для research-задач без платных ключей | `#search` `#free` `#hermes` |
| 1password | CLI для 1Password — секреты в команды без хардкода | Альтернатива ручным credentials-файлам, но это смена процесса — сначала обсудить | `#security` `#credentials` |
| jupyter-live-kernel | Итеративный Python через живой Jupyter kernel | ✅ Уже стоит у нас (built-in). Для тяжёлой аналитики пока не нужен | `#datascience` `#python` |

**Установка:** `hermes skills search <название>` → найти точный identifier → `hermes skills install <identifier>`

← [Все находки](../README.md)
