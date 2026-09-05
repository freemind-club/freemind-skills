#!/usr/bin/env bash
# director — установщик мастер-скилла (клуб FreeMind)
#   curl -fsSL https://raw.githubusercontent.com/freemind-club/freemind-skills/main/director/install.sh | bash
#   либо:  curl -fsSL <freemind-skills/install.sh> | bash -s director
#
# Фаза 1: промокод проверяется ЛОКАЛЬНО. Кладёт мастер-скилл `director` в ~/.claude/skills/.
# Персональную настройку доделывает ассистент: в Claude Code  /director
# Бренд-текст — источник в freemind-skills/BRAND.md (здесь встроен, синкается скриптом).

set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
# По умолчанию — ветка main (нет ещё версионированных релизов). Можно закрепиться на
# конкретном коммите/теге: DIRECTOR_REPO_REF=a04bab9 bash install.sh — тогда SUBDIR ниже
# подставится автоматически. Для проверки целостности — DIRECTOR_EXPECTED_SHA256=<хеш>.
DIRECTOR_REPO_REF="${DIRECTOR_REPO_REF:-main}"
REPO_TARBALL="${DIRECTOR_REPO_TARBALL:-https://github.com/freemind-club/freemind-skills/archive/${DIRECTOR_REPO_REF}.tar.gz}"
SUBDIR="freemind-skills-${DIRECTOR_REPO_REF}/director"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
err()  { printf '\n\033[31m%s\033[0m\n' "$*" >&2; }

# ── FREEMIND-BRAND ──────────────────────────────────────────
brand() {
cat <<'B'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚡ FreeMind — Олег Лаврентьев

  AI и автоматизация для тех, кто хочет, чтобы технологии
  работали на жизнь, а не наоборот. Без кода.

  Клуб и все соцсети:  lavrentevoleg.ru/social
  Telegram лично:      @Lavrentev_Oleg
  Канал:               @free_mind_rus
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
B
}
# ── /FREEMIND-BRAND ─────────────────────────────────────────

brand

# --- Промокод (локальная проверка; список валидных кодов НЕ показываем) ---
say "Директор — продукт клуба FreeMind."
printf 'Введи промокод: '
read -r CODE
CODE_NORM="$(printf '%s' "${CODE:-}" | tr '[:upper:]' '[:lower:]')"
case "$CODE_NORM" in
  freemind|nr_stas) TIER="full" ;;
  promo)            TIER="lite" ;;
  *)
    err "Промокод не распознан."
    cat <<'G'

Получить доступ:
  • напиши Олегу лично      → t.me/Lavrentev_Oleg
  • вступи в клуб FreeMind   → lavrentevoleg.ru/social/club
  • ты на интенсиве (NR)     → код у Стаса

Без кода установка не продолжается.
G
    exit 1 ;;
esac
say "Промокод принят."

# --- Снимок прошлого мастер-скилла (если был) ------------------------
BK="$HOME/.director-backup/$(date +%Y%m%d-%H%M%S)-installer"
for d in "$SKILLS_DIR/director" "$HOME/.hermes/skills/director" "$HOME/.qwen/skills/director" "$HOME/.codex/skills/director"; do
  [ -d "$d" ] || continue
  mkdir -p "$BK"; cp -R "$d" "$BK/$(echo "$d" | tr '/' '_')"
done
[ -d "$BK" ] && say "Прошлый мастер-скилл сохранён в $BK"

# --- Установка ------------------------------------------------------
say "Ставлю мастер-скилл в $SKILLS_DIR/director"
mkdir -p "$SKILLS_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TARBALL_FILE="$TMP/repo.tar.gz"
curl -fsSL -m 60 "$REPO_TARBALL" -o "$TARBALL_FILE"

TARBALL_SHA256="$(sha256sum "$TARBALL_FILE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$TARBALL_FILE" | cut -d' ' -f1)"
say "SHA-256 архива: ${TARBALL_SHA256}"
hint "Сверь с опубликованным хешем коммита ${DIRECTOR_REPO_REF}, если он у тебя есть."

if [ -n "${DIRECTOR_EXPECTED_SHA256:-}" ] && [ "$TARBALL_SHA256" != "$DIRECTOR_EXPECTED_SHA256" ]; then
  err "Хеш не совпадает с DIRECTOR_EXPECTED_SHA256. Архив мог измениться или сеть подменила ответ — установка остановлена."
  exit 1
fi

tar -xzf "$TARBALL_FILE" -C "$TMP"
rm -rf "$SKILLS_DIR/director"
cp -R "$TMP/$SUBDIR" "$SKILLS_DIR/director"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"code":"%s","tier":"%s","source":"curl-installer","ts":"%s"}\n' \
  "$CODE" "$TIER" "$TS" > "$SKILLS_DIR/director/.activation.json"
chmod 600 "$SKILLS_DIR/director/.activation.json" 2>/dev/null || true

for d in "$HOME/.hermes/skills" "$HOME/.qwen/skills" "$HOME/.codex/skills"; do
  [ -d "$(dirname "$d")" ] || continue
  mkdir -p "$d"; rm -rf "$d/director"; cp -R "$SKILLS_DIR/director" "$d/director"
done

# --- Готово --------------------------------------------------------
say "Готово. Мастер-скилл 'director' установлен (тир: $TIER)."
cat <<EOF

Дальше — в своём агенте (Claude Code / Hermes / Qwen Code / …):

    /director

Мастер определит среду, задаст вопросы и соберёт директора 'my-director'.
EOF
brand
