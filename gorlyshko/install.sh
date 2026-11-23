#!/usr/bin/env bash
# Установка скилла «Горлышко» (gorlyshko) для Claude Code и/или Hermes.
#
#   curl -fsSL https://raw.githubusercontent.com/freemind-club/freemind-skills/main/gorlyshko/install.sh -o gorlyshko-install.sh
#   bash gorlyshko-install.sh
#
# Что делает: скачивает папку скилла с GitHub (закреплённая версия), кладёт её в
#   ~/.claude/skills/gorlyshko            (если есть Claude Code)
#   ~/.hermes/skills/freemind/gorlyshko   (если есть Hermes)
# Старую версию не удаляет — переносит в ~/.gorlyshko-backup/<дата>/ (вне папки скиллов, чтобы агент не видел дубль).
# Не требует sudo, ничего не ставит в систему, в сеть ходит только за архивом скилла.
# Версия: GORLYSHKO_REF=<тег|коммит> bash gorlyshko-install.sh
set -euo pipefail

REF="${GORLYSHKO_REF:-gorlyshko-v0.4.1}"
case "$REF" in *[!A-Za-z0-9._-]*) echo "Неверная версия: $REF" >&2; exit 1 ;; esac
URL="https://codeload.github.com/freemind-club/freemind-skills/tar.gz/${REF}"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.gorlyshko-backup/$TS"

say() { printf '%s\n' "$*"; }
command -v curl >/dev/null || { say "Нужен curl."; exit 1; }
command -v tar  >/dev/null || { say "Нужен tar."; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Скачиваю «Горлышко» (версия $REF)…"
curl -fsSL -m 60 "$URL" -o "$TMP/repo.tar.gz" || { say "Не скачалось. Проверь интернет или версию."; exit 1; }
tar -xzf "$TMP/repo.tar.gz" -C "$TMP"
SRC="$(find "$TMP" -path '*/gorlyshko/SKILL.md' -print -quit | xargs -r dirname)"
[ -n "$SRC" ] && [ -f "$SRC/scripts/calc.py" ] || { say "В архиве нет скилла gorlyshko."; exit 1; }

install_to() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    local b="$BACKUP/$(basename "$(dirname "$dest")")"; mkdir -p "$b"
    mv "$dest" "$b/"; say "  старая версия → $b/gorlyshko"
  fi
  mkdir -p "$dest"
  cp -R "$SRC/SKILL.md" "$SRC/scripts" "$SRC/references" "$dest/"
  [ -d "$SRC/examples" ] && cp -R "$SRC/examples" "$dest/"
  say "  ✅ $dest"
}

DONE=0
if [ -d "$CLAUDE_HOME" ]; then install_to "$CLAUDE_HOME/skills/gorlyshko"; DONE=1; fi
if [ -d "$HERMES_HOME" ]; then install_to "$HERMES_HOME/skills/freemind/gorlyshko"; DONE=1; fi
if [ "$DONE" = 0 ]; then
  say "Не нашёл ни Claude Code (~/.claude), ни Hermes (~/.hermes)."
  say "Ставлю в ~/.claude/skills/gorlyshko — перенеси вручную, если у тебя другой агент."
  install_to "$CLAUDE_HOME/skills/gorlyshko"
fi

if command -v python3 >/dev/null; then
  say "Python 3 есть — калькулятор будет работать."
else
  say "⚠ Нет python3: скилл заработает, но цифры придётся считать нейросети (менее точно)."
fi

say ""
say "Готово. Дальше:"
say "  1) Google-таблица с карточкой → Файл → Скачать → CSV."
say "  2) Напиши своему агенту: «найди моё горлышко» и прикрепи этот CSV."
say "  (Hermes: если скилл не виден — новая сессия /new.)"
