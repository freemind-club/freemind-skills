# Agent tooling

Мета-инструменты — не скиллы под конкретную задачу, а инфраструктура для агентов.

| Инструмент | Что делает | Вердикт | Хештеги |
|-----------|-----------|---------|---------|
| [CLI-Anything](https://github.com/HKUDS/CLI-Anything) | Генератор agent-native CLI из любой программы или API. Работает с Claude Code, Hermes, OpenClaw и др. Каталог готовых CLI: `cli-anything-hub` (`pip install cli-anything-hub`) | Кандидат на будущее — можно обернуть 3X-UI (VPN-панель) или n8n API в единый CLI вместо разрозненных вызовов. Не установлено | `#cli` `#agents` `#future` |
| [EGM-Downloader](https://github.com/egmtm/EGM-Downloader) | Electron GUI-приложение для скачивания видео/аудио с 1000+ сайтов (обёртка над yt-dlp) | ❌ Не подошло — это desktop GUI ("double-click и качай"), мы на headless-сервере. Движок (yt-dlp) уже стоит у нас и используется в `youtube-summary` напрямую как CLI | `#video` `#rejected` |

← [Все находки](../README.md)
