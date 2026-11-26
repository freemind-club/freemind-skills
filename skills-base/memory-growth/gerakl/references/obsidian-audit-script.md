# audit-graph.py — аудит графа связей (файлы-сироты)

Источник: `<системная папка>/kb/доп_материалы/БОНУС-7-Связывание-базы-Obsidian.md` (методология Дмитрия
Попова, «Второй мозг», гайд для клуба «Нейроренессанс»). Скопирован сюда как готовый инструмент
Зоны 2 чек-листа — не нужно каждый раз искать оригинал в гайдах.

## Что делает

Обходит все `.md` файлы в указанной папке, извлекает все `[[wiki-ссылки]]`, строит граф входящих
ссылок и находит **файлы-сироты** — те, на которые никто не ссылается. Работает не только на
Obsidian-vault: любая папка с markdown-файлами, использующая синтаксис `[[имя-файла]]` для
перекрёстных ссылок, подходит (например служебные каталоги агента, папки заметок студентов,
потенциально — база самого проекта ClaudeCode, если в ней когда-нибудь появятся wiki-ссылки).

## Скрипт

```python
#!/usr/bin/env python3
"""Аудит графа связей — найти файлы-сироты."""
import os, re
from pathlib import Path
from collections import defaultdict

VAULT = Path("~/obsidian-vault")  # ← поменять на реальный путь перед запуском
SKIP_DIRS = {".obsidian", ".trash", "__pycache__", "Входящие"}

def find_all_md_files():
    files = []
    for root, dirs, filenames in os.walk(VAULT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in filenames:
            if fname.endswith(".md"):
                files.append(Path(root) / fname)
    return files

def extract_links(filepath):
    """Извлечь все [[ссылки]] из файла."""
    try:
        with open(filepath, encoding="utf-8") as f:
            content = f.read()
        links = re.findall(r'\[\[([^\]]+)\]\]', content)
        return [link.split('|')[0].split('#')[0].strip() for link in links]
    except:
        return []

def build_graph():
    files = find_all_md_files()
    incoming = defaultdict(set)

    for fpath in files:
        for link in extract_links(fpath):
            link_clean = link.replace('.md', '')
            incoming[link_clean].add(str(fpath.relative_to(VAULT)))

    return files, incoming

def analyze_orphans(files, incoming):
    orphans = []
    for fpath in files:
        stem = fpath.stem
        if stem not in incoming or len(incoming[stem]) == 0:
            orphans.append(fpath.relative_to(VAULT))
    return orphans

files, incoming = build_graph()
orphans = analyze_orphans(files, incoming)

print(f"📊 Статистика:")
print(f"   Всего файлов: {len(files)}")
print(f"   Файлов с входящими ссылками: {len([f for f in files if f.stem in incoming])}")
print(f"   Файлов-сирот: {len(orphans)} ({len(orphans)*100//len(files)}%)")

if orphans:
    print(f"\n📋 Топ-10 сирот:")
    for orphan in sorted(orphans)[:10]:
        print(f"   • {orphan}")
```

## Как применять

1. Сохранить как `audit-graph.py` куда угодно (например в scratchpad или прямо в целевую папку).
2. Поменять `VAULT = Path(...)` на реальный путь к базе, которую проверяешь.
3. Запустить: `python3 audit-graph.py`
4. Прочитать метрику `%` сирот и ориентироваться по шкале из чек-листа (Зона 2):
   - ≤ 30% — норма
   - 30–50% — стоит предложить владельцу базы связать активные материалы
   - > 50% — база не связана вообще, нужна структура MOC-карт с нуля

## Ограничения (знать заранее)

- Скрипт матчит ссылки **по имени файла (stem)**, не по полному пути — если два файла в разных
  папках называются одинаково, скрипт их не различит. Для больших/сложных vault это может давать
  ложноположительные «не сирота» на самом деле не той ссылкой.
- Не учитывает markdown-ссылки вида `[текст](путь.md)` — только `[[wiki-ссылки]]`. Если база
  использует обычные markdown-ссылки, скрипт занизит связность.
- Не различает «сирота потому что черновик» от «сирота потому что забыли связать» — это разбирает
  человек по списку, скрипт только считает.
- Не трогает и не правит файлы — чисто read-only аудит, безопасно запускать сколько угодно раз.

## Соседний скрипт из того же гайда (для контекста, не входит в Зону 2 напрямую)

БОНУС-7 также даёт `разметить-базу.py` — автоматически добавляет frontmatter (теги + дату) файлам,
у которых его нет. Это не аудит, а модификация файлов студента — Геракл им не пользуется
автоматически (см. правило Зоны 2 — не трогать чужие файлы без владельца рядом), но можно
порекомендовать студенту запустить самому, если у него много файлов без frontmatter. Полный текст
скрипта — в оригинале гайда, `<системная папка>/kb/доп_материалы/БОНУС-7-Связывание-базы-Obsidian.md`.
