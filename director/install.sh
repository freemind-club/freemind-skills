#!/usr/bin/env bash
# director — установщик мастер-скилла (клуб FreeMind)
#   curl -fsSL https://raw.githubusercontent.com/freemind-club/freemind-skills/main/director/install.sh | bash
#   либо:  curl -fsSL <freemind-skills/install.sh> | bash -s director
#
# Фаза 1: промокод проверяется ЛОКАЛЬНО. Кладёт мастер-скилл `director` в ~/.claude/skills/.
# Персональную настройку доделывает ассистент: в Claude Code  /director
# Бренд-текст — источник в freemind-skills/BRAND.md (здесь встроен, синкается скриптом).

set -euo pipefail

# `curl -fsSL …/director/install.sh | bash` кладёт текст скрипта в stdin —
# тогда интерактивные `read` читали бы не пользователя, а сам скрипт.
# Есть управляющий терминал — переключаем ввод на него. Нет — работаем
# только по env-переменным (DIRECTOR_CODE / DIRECTOR_TARGETS), иначе стоп.
INTERACTIVE=1
if [ ! -t 0 ]; then
  if [ -e /dev/tty ] && ( : </dev/tty ) 2>/dev/null; then
    exec </dev/tty; INTERACTIVE=1
  else
    INTERACTIVE=0
  fi
fi

# Каталоги сред: сначала уважаем общепринятые *_HOME, потом дефолт $HOME/.X.
#   Claude Code — CLAUDE_CONFIG_DIR (официально);  Hermes — HERMES_HOME (официально);
#   Codex — CODEX_HOME (официально).  У Qwen Code и Cursor общепринятой переменной нет —
#   там остаётся $HOME/.X (это осознанно).
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
QWEN_HOME="$HOME/.qwen"
CURSOR_HOME="$HOME/.cursor"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$CLAUDE_HOME/skills}"
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

# Реконфиг найденной на нестандартном пути установки (см. resolve_target):
#   DIRECTOR_RECONFIG_DIR=<путь из показанного списка> — ставить мастер поверх неё,
#   не создавая второй одноимённый скилл рядом.
DIRECTOR_RECONFIG_DIR="${DIRECTOR_RECONFIG_DIR:-}"

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
if [ -n "${DIRECTOR_CODE:-}" ]; then
  CODE="$DIRECTOR_CODE"
  say "Промокод взят из DIRECTOR_CODE."
elif [ "$INTERACTIVE" = 1 ]; then
  printf 'Введи промокод: '
  read -r CODE || CODE=""
else
  err "Нет терминала для ввода промокода. Запусти установщик в терминале, либо:"
  err "  curl -fsSL <url>/director/install.sh -o d.sh && DIRECTOR_CODE=<код> bash d.sh"
  exit 1
fi
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

  # Движущаяся ветка (main и т.п.): содержимое меняется между установками.
  MOVING_REF=0
  case "$DIRECTOR_REPO_REF" in main|master|HEAD|develop|latest) MOVING_REF=1 ;; esac

  if [ -n "${DIRECTOR_EXPECTED_SHA256:-}" ]; then
    if [ "$TARBALL_SHA256" != "$DIRECTOR_EXPECTED_SHA256" ]; then
      err "SHA-256 не совпал с DIRECTOR_EXPECTED_SHA256 — архив изменился или подменён. Стоп."
      exit 1
    fi
    say "Контрольная сумма совпала."
  else
    if [ "$MOVING_REF" = 1 ]; then
      err  "⚠ Ставишь ДВИЖУЩУЮСЯ ветку «$DIRECTOR_REPO_REF» БЕЗ проверки целостности."
      err  "  Её содержимое меняется между установками — нельзя доказать, что ты получил"
      err  "  именно тот код, который кто-то проверял. Это НЕ рекомендуется."
      hint "  Надёжно: закрепись на теге или коммите  →  DIRECTOR_REPO_REF=<tag|sha>"
      hint "           и сверь архив                   →  DIRECTOR_EXPECTED_SHA256=<хеш выше>"
      hint "  Или ставь из уже проверенной копии       →  DIRECTOR_LOCAL_DIR=<путь>"
    else
      hint "Ожидаемый хеш не задан (DIRECTOR_EXPECTED_SHA256). Режим UNVERIFIED —"
      hint "ты не можешь доказать, что скачал именно то, что проверял."
    fi
    if [ "$INTERACTIVE" = 1 ]; then
      read -r -p "Продолжить без проверки целостности? [y/N]: " _unv || _unv=""
      [ "$_unv" = "y" ] || [ "$_unv" = "Y" ] || { err "Отменено."; exit 1; }
    else
      err "Режим UNVERIFIED без терминала запрещён. Задай DIRECTOR_EXPECTED_SHA256=<хеш архива>"
      err "или ставь из проверенной копии: DIRECTOR_LOCAL_DIR=<путь>."
      exit 1
    fi
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

# --- Выбор целевых сред: ТОЛЬКО реально найденные (не плодим пустых каталогов) ---
CANDIDATES=()
add_cand() {
  local p="$1"
  case " ${CANDIDATES[*]-} " in *" $p "*) return 0 ;; esac
  CANDIDATES+=("$p")
}

# 1) среда, из которой явно запущен установщик → рекомендуемый первый пункт
case "${DIRECTOR_ENV:-}" in
  claude) add_cand "$CLAUDE_HOME/skills" ;;
  hermes) add_cand "$HERMES_HOME/skills" ;;
  qwen)   add_cand "$QWEN_HOME/skills" ;;
  codex)  add_cand "$CODEX_HOME/skills" ;;
  cursor) add_cand "$CURSOR_HOME/skills" ;;
esac
[ -n "${CLAUDE_SKILLS_DIR:-}" ] && add_cand "$SKILLS_DIR"

# 2) далее — по факту: каталог среды существует ИЛИ бинарь в PATH
{ [ -d "$CLAUDE_HOME" ]  || command -v claude >/dev/null 2>&1; }  && add_cand "$CLAUDE_HOME/skills"
{ [ -d "$HERMES_HOME" ]  || command -v hermes >/dev/null 2>&1; }  && add_cand "$HERMES_HOME/skills"
{ [ -d "$QWEN_HOME"   ]  || command -v qwen   >/dev/null 2>&1; }  && add_cand "$QWEN_HOME/skills"
{ [ -d "$CODEX_HOME"  ]  || command -v codex  >/dev/null 2>&1; }  && add_cand "$CODEX_HOME/skills"
[ -d "$CURSOR_HOME" ] && add_cand "$CURSOR_HOME/skills"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  err "Не нашёл ни одной поддерживаемой среды (Claude Code / Hermes / Qwen Code / Codex / Cursor)."
  err "Поставь агента, либо укажи каталог скиллов явно:"
  err "  CLAUDE_SKILLS_DIR=/путь/к/skills  curl -fsSL … | bash"
  exit 1
fi

# --- Рекурсивный поиск уже существующей установки ------------------
# Мастер НЕ должен создавать второй одноимённый скилл рядом с чужим,
# если director / director-doctrine у пользователя лежит на нестандартном
# пути (напр. ~/.hermes/skills/autonomous-ai-agents/director-doctrine/).
# Ищем по frontmatter `name:` в первых строках любого *.md.
_NAME_RE='^[[:space:]]*name:[[:space:]]*["'"'"']?(director|director-doctrine)["'"'"']?[[:space:]]*$'
find_existing() {   # $1 — корень поиска; печатает каталоги-носители, по одному в строку
  local root="$1" mdf
  [ -d "$root" ] || return 0
  find "$root" -type f -name '*.md' 2>/dev/null | while IFS= read -r mdf; do
    head -n 15 "$mdf" 2>/dev/null | grep -qE "$_NAME_RE" && dirname "$mdf"
  done | sort -u
}

RESOLVED_TARGET=""
resolve_target() {  # $1 — каталог скиллов среды. Ставит RESOLVED_TARGET или возвращает 1 (пропуск)
  local base="$1" std="$1/director" found n
  RESOLVED_TARGET=""
  found="$(find_existing "$base" | grep -vxF "$std" || true)"
  if [ -z "$found" ]; then
    RESOLVED_TARGET="$std"; return 0
  fi
  n="$(printf '%s\n' "$found" | grep -c .)"
  err "В «$base» уже есть установка директора на НЕстандартном пути:"
  printf '%s\n' "$found" | sed 's/^/    /' >&2
  if [ -n "$DIRECTOR_RECONFIG_DIR" ]; then
    if printf '%s\n' "$found" | grep -qxF "$DIRECTOR_RECONFIG_DIR"; then
      say "Реконфиг существующей: $DIRECTOR_RECONFIG_DIR (DIRECTOR_RECONFIG_DIR)"
      RESOLVED_TARGET="$DIRECTOR_RECONFIG_DIR"; return 0
    fi
    err "DIRECTOR_RECONFIG_DIR=$DIRECTOR_RECONFIG_DIR не совпал ни с одним найденным путём — пропуск «$base»."
    return 1
  fi
  if [ "$INTERACTIVE" != 1 ]; then
    err "Без терминала дубль не создаю. Обновить существующую → DIRECTOR_RECONFIG_DIR=<путь из списка>."
    err "Чистая установка мастера рядом (осознанно) → DIRECTOR_RECONFIG_DIR=$std."
    return 1
  fi
  [ "$n" -gt 1 ] && err "Найдено несколько — выбери, какую обновлять."
  printf '  0) поставить ЧИСТУЮ установку мастера в %s\n' "$std" >&2
  local i=1 p
  while IFS= read -r p; do
    printf '  %d) обновить %s\n' "$i" "$p" >&2; i=$((i+1))
  done < <(printf '%s\n' "$found")
  printf 'Выбор [0..%d], Enter = 0: ' "$((i-1))" >&2
  read -r pick || pick=""
  [ -z "${pick// }" ] && pick=0
  if [ "$pick" = 0 ]; then RESOLVED_TARGET="$std"; return 0; fi
  case "$pick" in *[!0-9]*) err "Не понял выбор — пропуск «$base»."; return 1 ;; esac
  p="$(printf '%s\n' "$found" | sed -n "${pick}p")"
  [ -n "$p" ] || { err "Пункт $pick вне списка — пропуск «$base»."; return 1; }
  RESOLVED_TARGET="$p"; return 0
}

say "Найденные среды для установки:"
for i in "${!CANDIDATES[@]}"; do
  mark=" (есть старая версия)"; [ -d "${CANDIDATES[$i]}/director" ] || mark=""
  printf '  %d) %s%s\n' "$((i+1))" "${CANDIDATES[$i]}" "$mark"
done

if [ -n "${DIRECTOR_TARGETS:-}" ]; then
  PICKS="$DIRECTOR_TARGETS"
  say "Цели из DIRECTOR_TARGETS: $PICKS"
elif [ "${#CANDIDATES[@]}" -eq 1 ]; then
  PICKS="1"
  say "Среда одна — ставлю в неё: ${CANDIDATES[0]}"
elif [ "$INTERACTIVE" = 1 ]; then
  printf 'Куда ставить? номера через пробел, Enter = только 1 (%s): ' "${CANDIDATES[0]}"
  read -r PICKS || PICKS=""
  [ -z "${PICKS// }" ] && PICKS="1"
else
  PICKS="1"
  say "Без терминала — ставлю в первую найденную среду: ${CANDIDATES[0]} (переопредели DIRECTOR_TARGETS)"
fi

# --- Атомарная замена: снимок → swap → откат при сбое --------------
BK="$HOME/.director-backup/$(date +%Y%m%d-%H%M%S)"
install_to() {
  local dst="$1" base; base="$(dirname "$dst")"
  mkdir -p "$base"
  if [ -d "$dst" ]; then
    mkdir -p "$BK"; cp -R "$dst" "$BK/$(printf '%s' "$dst" | tr '/' '_')"
  fi
  local newdir="$dst.new.$$"
  rm -rf "$newdir"
  cp -R "$STAGE" "$newdir"
  # обязательные файлы на месте в новой копии?
  local ok=1
  for f in "${REQUIRED_FILES[@]}"; do [ -f "$newdir/$f" ] || ok=0; done
  if [ "$ok" != 1 ]; then
    rm -rf "$newdir"; err "Staging-копия для $dst битая — активная версия не тронута."; return 1
  fi
  local olddir="$dst.old.$$"
  [ -d "$dst" ] && mv "$dst" "$olddir"
  mv "$newdir" "$dst"
  rm -rf "$olddir"
  say "→ $dst"
}
INSTALLED_COUNT=0
for n in $PICKS; do
  case "$n" in
    ''|*[!0-9]*) err "Пропущен нечисловой пункт: '$n'"; continue ;;
  esac
  idx=$((n-1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#CANDIDATES[@]}" ]; then
    if resolve_target "${CANDIDATES[$idx]}" && install_to "$RESOLVED_TARGET"; then
      INSTALLED_COUNT=$((INSTALLED_COUNT+1))
    fi
  else
    err "Пункт $n вне списка (1..${#CANDIDATES[@]}) — пропущен."
  fi
done
[ -d "$BK" ] && say "Снимок прошлых версий: $BK"

if [ "$INSTALLED_COUNT" -eq 0 ]; then
  err "Ничего не установлено: не выбрано ни одного корректного пункта (1..${#CANDIDATES[@]})."
  err "Директор НЕ установлен. Запусти снова и укажи номер из списка."
  exit 1
fi

# --- Готово --------------------------------------------------------
say "Готово. Мастер-скилл 'director' установлен в $INSTALLED_COUNT среду(-ы) (тир: $TIER)."
cat <<EOF

Дальше — в своём агенте (Claude Code / Hermes / Qwen Code / …):

    /director

Мастер определит среду, задаст вопросы и соберёт директора 'my-director'.
EOF
brand
