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
# Источник:
#   1) DIRECTOR_LOCAL_DIR=/path/to/director  — ставить из уже проверенной локальной копии,
#      БЕЗ повторного скачивания (нет TOCTOU: что проверил — то и ставишь).
#   2) DIRECTOR_REPO_REF=<tag|commit>        — закрепиться на неизменяемой ревизии.
#   3) DIRECTOR_EXPECTED_SHA256=<хеш>        — обязательная сверка контрольной суммы архива.
# По умолчанию тянется ветка main. Без ожидаемого хеша — режим UNVERIFIED с явным согласием.
DIRECTOR_LOCAL_DIR="${DIRECTOR_LOCAL_DIR:-}"
DIRECTOR_REPO_REF="${DIRECTOR_REPO_REF:-main}"
REPO_TARBALL="${DIRECTOR_REPO_TARBALL:-https://github.com/freemind-club/freemind-skills/archive/${DIRECTOR_REPO_REF}.tar.gz}"
SUBDIR="freemind-skills-${DIRECTOR_REPO_REF}/director"
# Файлы, без которых распакованный каталог считается битым (проверка перед заменой).
REQUIRED_FILES=(SKILL.md core/00-director.md adapters/00_ROUTER.md models/00_ROUTER.md)

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
err()  { printf '\n\033[31m%s\033[0m\n' "$*" >&2; }
hint() { printf '\033[90m%s\033[0m\n' "$*"; }

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

# --- Получаем исходник в staging ($SRC) -----------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC=""

if [ -n "$DIRECTOR_LOCAL_DIR" ]; then
  [ -d "$DIRECTOR_LOCAL_DIR" ] || { err "DIRECTOR_LOCAL_DIR не существует: $DIRECTOR_LOCAL_DIR"; exit 1; }
  say "Ставлю из локальной копии: $DIRECTOR_LOCAL_DIR (без скачивания)"
  SRC="$DIRECTOR_LOCAL_DIR"
else
  say "Скачиваю мастер-скилл (ревизия: $DIRECTOR_REPO_REF)"
  TARBALL_FILE="$TMP/repo.tar.gz"
  curl -fsSL -m 60 "$REPO_TARBALL" -o "$TARBALL_FILE"
  TARBALL_SHA256="$(sha256sum "$TARBALL_FILE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$TARBALL_FILE" | cut -d' ' -f1)"
  say "SHA-256 архива: ${TARBALL_SHA256}"

  if [ -n "${DIRECTOR_EXPECTED_SHA256:-}" ]; then
    if [ "$TARBALL_SHA256" != "$DIRECTOR_EXPECTED_SHA256" ]; then
      err "SHA-256 не совпал с DIRECTOR_EXPECTED_SHA256 — архив изменился или подменён. Стоп."
      exit 1
    fi
    say "Контрольная сумма совпала."
  else
    hint "Ожидаемый хеш не задан (DIRECTOR_EXPECTED_SHA256). Это режим UNVERIFIED —"
    hint "ты не можешь доказать, что скачал именно то, что проверял."
    read -r -p "Продолжить без проверки целостности? [y/N]: " _unv
    [ "$_unv" = "y" ] || [ "$_unv" = "Y" ] || { err "Отменено."; exit 1; }
  fi

  tar -xzf "$TARBALL_FILE" -C "$TMP"
  SRC="$TMP/$SUBDIR"
fi

# --- Проверяем структуру ДО того, как трогать активную установку ----
[ -d "$SRC" ] || { err "Каталог director не найден в источнике ($SRC). Активная установка не тронута."; exit 1; }
for f in "${REQUIRED_FILES[@]}"; do
  [ -f "$SRC/$f" ] || { err "В источнике нет обязательного файла: $f. Активная установка не тронута."; exit 1; }
done

STAGE="$TMP/stage/director"
mkdir -p "$TMP/stage"
cp -R "$SRC" "$STAGE"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"code":"%s","tier":"%s","source":"curl-installer","ts":"%s"}\n' \
  "$CODE" "$TIER" "$TS" > "$STAGE/.activation.json"
chmod 600 "$STAGE/.activation.json" 2>/dev/null || true

# --- Выбор целевых сред (не перезаписываем всё молча) ---------------
CANDIDATES=("$SKILLS_DIR")
for base in "$HOME/.hermes/skills" "$HOME/.qwen/skills" "$HOME/.codex/skills"; do
  [ -d "$(dirname "$base")" ] && CANDIDATES+=("$base")
done

say "Найденные среды для установки:"
for i in "${!CANDIDATES[@]}"; do
  mark=" (есть старая версия)"; [ -d "${CANDIDATES[$i]}/director" ] || mark=""
  printf '  %d) %s%s\n' "$((i+1))" "${CANDIDATES[$i]}" "$mark"
done
printf 'Куда ставить? номера через пробел, Enter = только 1 (%s): ' "$SKILLS_DIR"
read -r PICKS
[ -z "${PICKS// }" ] && PICKS="1"

# --- Атомарная замена: снимок → swap → откат при сбое --------------
BK="$HOME/.director-backup/$(date +%Y%m%d-%H%M%S)"
install_to() {
  local base="$1" dst="$1/director"
  mkdir -p "$base"
  if [ -d "$dst" ]; then
    mkdir -p "$BK"; cp -R "$dst" "$BK/$(printf '%s' "$base" | tr '/' '_')_director"
  fi
  local newdir="$base/director.new.$$"
  rm -rf "$newdir"
  cp -R "$STAGE" "$newdir"
  # обязательные файлы на месте в новой копии?
  local ok=1
  for f in "${REQUIRED_FILES[@]}"; do [ -f "$newdir/$f" ] || ok=0; done
  if [ "$ok" != 1 ]; then
    rm -rf "$newdir"; err "Staging-копия для $base битая — активная версия не тронута."; return 1
  fi
  local olddir="$base/director.old.$$"
  [ -d "$dst" ] && mv "$dst" "$olddir"
  mv "$newdir" "$dst"
  rm -rf "$olddir"
  say "→ $dst"
}
for n in $PICKS; do
  case "$n" in
    ''|*[!0-9]*) continue ;;
  esac
  idx=$((n-1))
  [ "$idx" -ge 0 ] && [ "$idx" -lt "${#CANDIDATES[@]}" ] && install_to "${CANDIDATES[$idx]}" || err "Пропущен пункт $n"
done
[ -d "$BK" ] && say "Снимок прошлых версий: $BK"

# --- Готово --------------------------------------------------------
say "Готово. Мастер-скилл 'director' установлен (тир: $TIER)."
cat <<EOF

Дальше — в своём агенте (Claude Code / Hermes / Qwen Code / …):

    /director

Мастер определит среду, задаст вопросы и соберёт директора 'my-director'.
EOF
brand
