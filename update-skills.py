#!/usr/bin/env python3
"""Проверка и обновление авторских скиллов FreeMind у себя (для участников клуба).

Запуск из папки клона витрины (git clone https://github.com/freemind-club/freemind-skills):
  git pull                                  # получить свежие версии
  python3 update-skills.py                  # показать: что у вас устарело
  python3 update-skills.py --apply          # обновить устаревшие (старые — в бэкап)
  python3 update-skills.py --apply tg-audit # обновить только выбранные

Безопасно: ничего не скачивает и не запускает из интернета, берёт файлы только из этого клона;
перед заменой копирует вашу версию в ~/.freemind-skills-backup/<дата>/; без --apply ничего не меняет.
"""
import json, os, re, shutil, sys, datetime
REPO = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.expanduser(os.environ.get('CLAUDE_SKILLS_DIR', '~/.claude/skills'))

def version(skill_md):
    try: t = open(skill_md, encoding='utf-8').read()
    except OSError: return None
    m = re.search(r'version:\s*["\']?([\d.]+)', t.split('---', 2)[1] if t.startswith('---') else '')
    return m.group(1) if m else '?'

def vkey(v): return tuple(int(x) for x in v.split('.') if x.isdigit()) if v and v != '?' else (-1,)

try: man = json.load(open(os.path.join(REPO, 'versions.json'), encoding='utf-8'))
except (OSError, ValueError):
    sys.exit('Нет versions.json — запустите скрипт из папки клона freemind-skills после `git pull`.')

apply = '--apply' in sys.argv
only = [a for a in sys.argv[1:] if not a.startswith('--')]
todo = []
print(f"Витрина от {man.get('updated','?')}. Ваши скиллы: {DEST}\n")
print(f"{'скилл':22} {'у вас':8} {'витрина':8} статус")
for name, info in sorted(man['skills'].items()):
    pv = info['version']; mine = version(os.path.join(DEST, name, 'SKILL.md'))
    if mine is None: st = '— не установлен'
    elif vkey(mine) < vkey(pv): st = '⬆️ есть обновление'; todo.append((name, info['path']))
    else: st = '✅ актуально'
    print(f"{name:22} {mine or '—':8} {pv:8} {st}")

if not todo: sys.exit('\nВсё актуально.')
if not apply: sys.exit(f"\nМожно обновить: {', '.join(n for n,_ in todo)}.\nКоманда: python3 update-skills.py --apply")
bk = os.path.expanduser(f"~/.freemind-skills-backup/{datetime.datetime.now():%Y%m%d-%H%M%S}")
for name, path in todo:
    if only and name not in only: continue
    src = os.path.join(REPO, path); dst = os.path.join(DEST, name)
    if not os.path.isfile(os.path.join(src, 'SKILL.md')): print('пропуск', name, '(нет в клоне)'); continue
    os.makedirs(bk, exist_ok=True); shutil.copytree(dst, os.path.join(bk, name)); shutil.rmtree(dst)
    shutil.copytree(src, dst); print(f"✅ {name} → {version(os.path.join(dst,'SKILL.md'))} (старая копия: {bk}/{name})")
