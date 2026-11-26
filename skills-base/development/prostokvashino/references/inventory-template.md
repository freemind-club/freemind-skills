# Шаблон инвентаризации сервера — перед любым необратимым действием

> Шаблон общий, к конкретному переезду не привязан. Цель — описать ВСЁ, что живёт на сервере, до
> того как что-то переносится или удаляется. Если чего-то нет в описи, это не унесут.
>
> Тот же принцип в миниатюре, при переносе одной папки проекта: `<системная папка>/templates/ШАБЛОН_ПРОЕКТА.md`,
> грабля 1. Папка может быть привязана к живому systemd-сервису по абсолютному пути.

## Правила заполнения

- **Только чтение.** Ничего не останавливать, не перезапускать, не менять.
- **Значения секретов никогда не выводить.** Из `.env` берутся только имена ключей, из `ps` —
  вывод с маской. Подробно в §4.
- **Где лежит опись:** `<системная папка>/logs/migration/INVENTORY_<YYYY-MM-DD>.md`. В шапке указать сервер,
  ОС, ресурсы, IP, дату и время снятия, ссылку на план.
- **Формат:** таблицы по разделам ниже. **У каждой строки обязательна колонка «Метка»** с одним
  из трёх значений:
  - **ПЕРЕНОСИМ** — нужно на новом месте (указать как: файлом, дампом, установкой заново);
  - **НЕ ПЕРЕНОСИМ** — мёртвое, архив, специфика старого хостинга. Сразу пометить «→ Геракл»,
    если это кандидат на чистку;
  - **СПРОСИТЬ** — решает владелец. Номер вопроса проставить в блоке «Вопросы к владельцу».
- Без метки допустимы только справочные строки (порт, «не установлено»). Им ставится метка
  `справочно`, и в счёт они не идут.
- Если найденное критично до переноса (нет дампа, мёртвый путь, порт в интернет), это идёт в
  раздел **«§0 Критично ДО Шага 3»** в самом верху описи. Пункт §0 ссылается на номер строки.
- **КРИТИЧНЫЙ риск** (в §0 с пометкой «КРИТИЧНЫЙ»): СУБД слушает все интерфейсы (`0.0.0.0`/`[::]`/
  `listen_addresses='*'`) **и** в её `pg_hba.conf` есть `host`-правило на `0.0.0.0/0`, `::/0` или `all`.
  Это верно и тогда, когда порт сейчас закрывает ufw: одна правка ufw, и база открыта в интернет.
  На новом сервере `pg_hba.conf` как есть не копировать. Команды в §5.
- В шелле Claude Code `grep` — функция-обёртка над **ugrep**, которая уважает `.gitignore`. Во всех
  командах шаблона стоит `command grep`, так и оставлять (подробно в SKILL.md, «Грабли»).

**Нумерация позиций.** Номер строки = префикс раздела + дефис + две цифры. На эти номера ссылаются
§0, план и вопросы, поэтому префиксы фиксированы:

| Префикс | Раздел | Префикс | Раздел |
|---|---|---|---|
| `C` | §1 планировщики | `I` | §5 инстансы СУБД (`V` — висячие volume с данными БД) |
| `S` | §2 system-юниты | `N` | §6 сеть, веб, DNS, файрвол |
| `U` | §2 user-юниты | `H` | §7 захардкоженные IP |
| `P` | §2 процессы вне systemd | `F` | §8 файлы, `/root`, рантайм |
| `D` | §3 Docker | `Y` | §9 синхронизация |
| `K` | §4 секреты | `E` | §10 внешние привязки |

Пример: `I-01`, `S-12`, `V-01`. Нумерация сквозная внутри префикса, номера не переиспользуются при
правке описи (удалённая строка оставляет дырку). Вопросы к владельцу — `СПРОСИТЬ-<n>`. Если в плане уже
есть нумерованные вопросы, новые продолжают его нумерацию, а не начинают с 1.

**Правило подсчёта** для таблицы счёта:
- считается строка таблицы с номером, у которой последняя колонка начинается с `ПЕРЕНОСИМ`,
  `НЕ ПЕРЕНОСИМ` или `СПРОСИТЬ`; уточнение после метки («ПЕРЕНОСИМ (дампом)») не мешает;
- одна строка = одна метка. Составная метка («ПЕРЕНОСИМ, а двойник — СПРОСИТЬ») запрещена: разбить на
  две строки;
- один объект в двух разделах описывается один раз. Во втором разделе строка с меткой `= <номер>`
  (например `= N-12`), в счёт она не идёт;
- справочные строки (`справочно`) не считаются.

Счёт по описи (проверено на описи 27.10):
```bash
command grep -E '^\| [A-Z]-[0-9]{2} \|' INVENTORY_<дата>.md \
  | command grep -oE '\| (НЕ ПЕРЕНОСИМ|ПЕРЕНОСИМ|СПРОСИТЬ)[^|]*\|\s*$' \
  | sed -E 's/^\| //; s/(СПРОСИТЬ|ПЕРЕНОСИМ).*/\1/' | sort | uniq -c
```

Базовая строка таблицы:

```
| # | Что | Где / путь | Состояние | Данные / зависимости | Метка |
| S-01 | postgresql@14-main | /var/lib/postgresql/14/main | active | oleg_brain | ПЕРЕНОСИМ (дампом) |
```

## 1. Планировщики

```bash
# все пользователи, включая root (отдельный crontab -l не нужен — будет дубль)
for u in $(cut -d: -f1 /etc/passwd); do crontab -l -u "$u" 2>/dev/null | sed "s/^/[$u] /"; done
ls /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/
systemctl list-timers --all
systemctl --user list-timers --all
```

**Cron внутри приложений** crontab не покажет, проверять отдельно:
- Гермес: `~/.hermes/cron/jobs.json` (и в каждом профиле);
- n8n: Schedule/Cron-триггеры живут в его БД и едут вместе с дампом. Список активных воркфлоу
  снимать через MCP n8n или API, к БД напрямую не ходить. Для описи разрешён **один прямой read-only
  вызов** `n8n_list_workflows` (active=true) без субагента `n8n-agent`: это чтение списка, не работа с
  n8n. Любые изменения воркфлоу — только через `n8n-agent`;
- прочие приложения со своим планировщиком (боты на APScheduler и т.п.):
  `command grep -rlE 'schedule|cron' <код>`.

## 2. systemd — system и user

```bash
systemctl list-units --type=service --all --no-legend --no-pager | command grep -vE '^\s*(systemd|dbus|getty|user@)'
systemctl list-unit-files --type=service --state=enabled --no-pager
ls /etc/systemd/system/*.service
# user-юниты: здесь может жить половина системы (Гермес и т.п.). Только service/timer/socket,
# иначе ~90% вывода — device/mount/slice
loginctl show-user root -p Linger
systemctl --user list-units --all --type=service,timer,socket --no-legend --no-pager
ls ~/.config/systemd/user/
```

**Мёртвые пути в юнитах.** Цикл по `grep -o … [^ ]+` ломается: путь с пробелом даёт ложную тревогу,
ExecStart в кавычках и путь во втором аргументе (`node /…/index.js`) пропускаются. Разбирать
shell-словами, проверять каждый абсолютный путь в WorkingDirectory, EnvironmentFile и всех Exec*,
включая drop-in `*.service.d/*.conf` и `--opt=/путь`:
```bash
python3 -I - /etc/systemd/system/*.service /etc/systemd/system/*.service.d/*.conf \
  ~/.config/systemd/user/*.service ~/.config/systemd/user/*.service.d/*.conf <<'PY'
import sys, os, re, shlex
KEYS = ('WorkingDirectory', 'EnvironmentFile', 'ExecStart', 'ExecStartPre', 'ExecStartPost', 'ExecStop', 'ExecReload')
for f in sys.argv[1:]:
    if not os.path.isfile(f): continue
    text = re.sub(r'\\\n', ' ', open(f, encoding='utf-8', errors='replace').read())
    for line in text.splitlines():
        k, sep, v = line.strip().partition('=')
        k = k.strip()
        if not sep or k not in KEYS or not v.strip(): continue
        if k.startswith('Exec'):
            try: toks = shlex.split(v)
            except ValueError: toks = v.split()
        else: toks = [v.strip().strip('"')]          # путь целиком, пробелы допустимы
        for i, t in enumerate(toks):
            if i == 0: t = t.lstrip('-@+!:')            # префиксы systemd
            for p in [t] + re.findall(r'=(/[^\s:,]+)', t):
                if not p.startswith('/') or '%' in p or '$' in p: continue
                if not os.path.exists(p): print(f'МЁРТВЫЙ ПУТЬ: {f} {k} -> {p}')
PY
```
Префикс `-` у EnvironmentFile означает «необязательный»: такой мёртвый путь не ломает юнит, но в
опись всё равно идёт.

**Процессы вне systemd:**
```bash
tmux ls 2>/dev/null; screen -ls 2>/dev/null
# без потоков ядра, дочерних процессов postgres, containerd-shim и VS Code (docker-proxy оставлен: он нужен для §6)
ps -eo pid,user,unit,cmd --sort=unit | sed -E 's#://[^:/@ ]+:[^@ ]+@#://***:***@#g' \
  | command grep -vE '\[.*\]$|postgres: |containerd-shim|vscode-server'
```

По каждому нестандартному юниту указать: что делает, где конфиг и env-файл (только путь),
active/enabled. Отдельно отметить противоречия с памятью вида «по памяти не используется, а юнит
active» и пометить СПРОСИТЬ.

## 3. Docker

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker volume ls; docker network ls
docker system df
docker compose ls 2>/dev/null
# откуда поднят каждый контейнер: compose-файл, или его нет (тогда это docker run)
for c in $(docker ps -aq); do
  n=$(docker inspect -f '{{.Name}}' "$c")
  f=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$c")
  if [ -z "$f" ]; then echo "$n  БЕЗ COMPOSE"; else
    for x in ${f//,/ }; do [ -e "$x" ] && echo "$n  $x" || echo "$n  МЁРТВЫЙ ПУТЬ $x"; done; fi; done
```

- **Контейнер без compose** по файлу не пересоздать. Снять параметры запуска (образ, порты, volumes,
  сеть, restart): `docker inspect -f '{{.Config.Image}} {{json .HostConfig.PortBindings}} {{json .Mounts}} {{.HostConfig.RestartPolicy.Name}}' <c>`.
  Env смотреть только по именам: `docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' <c> | command grep -oE '^[A-Za-z_][A-Za-z0-9_]*='`.
- **Мёртвый путь compose** означает, что контейнер жив только за счёт `restart:`. Найти, куда
  переехали исходники, или пометить СПРОСИТЬ.
- Висячие volume и сети без контейнеров тоже описать: в них бывают данные (например, БД закрытого
  проекта). Volume с данными СУБД ищутся командой из §5 и получают номер `V-NN`.
- Неиспользуемые образы не переносятся, их можно скачать заново.

## 4. Секреты, ключи, конфиги — только пути

Печатаются **только пути**. Ищем там, где живут конфиги (`/usr`, `/var/lib/dpkg`, слои Docker и
`/proc` не обходим — это шум), исходный код и шаблоны отсекаем по расширению:
```bash
find /root /home /etc /opt /srv /var/www /usr/local/etc -xdev \( -path /etc/letsencrypt -o -path /etc/ssl \
    -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/venv' -o -path '*/site-packages' -o -path '*/.cache' \
    -o -path '*/cache' -o -path '*/.npm' -o -path '*/.nvm' -o -path '*/.vscode-server' -o -path '*/.git' \
    -o -path '*/.hermes/tools' -o -path '*/.hermes/installs' -o -path '*/sessions' -o -path '*/sessions-archive' \) -prune -o \
  -type f \( -iname '*.env' -o -iname '.env*' -o -iname '*credentials*' -o -iname '*secret*' -o -iname '*token*' \
    -o -iname '*pass*' -o -iname '*key' -o -iname '*.key' -o -iname '*access_key*' -o -iname 'auth.json' \
    -o -iname 'hosts.yml' -o -iname '*.pem' -o -iname 'id_*' -o -path '*/.ssh/*' -o -path '*/.docker/config.json' \) \
  ! \( -iname '*.py' -o -iname '*.pyc' -o -iname '*.js' -o -iname '*.mjs' -o -iname '*.ts' -o -iname '*.tsx' \
    -o -iname '*.jsx' -o -iname '*.map' -o -iname '*.go' -o -iname '*.rs' -o -iname '*.md' -o -iname '*.html' \
    -o -iname '*.css' -o -iname '*.svg' -o -iname '*.example' -o -iname '*.sample' -o -iname '*.template' \
    -o -path '*/man/*' -o -name 'passwd*' -o -name 'gshadow*' -o -path '/etc/pam.d/*' \) -print 2>/dev/null | sort
# известные места, которые маской по имени не ловятся: печатает только права и путь
ls -ld ~/.ssh ~/.ssh/* ~/.config/gh/hosts.yml ~/.pgpass ~/.git-credentials ~/.docker/config.json \
  ~/.claude/.credentials.json ~/.claude.json ~/.netrc 2>/dev/null | awk '{print $1, $NF}'
# сертификаты: каталогом, а не сотней файлов (переносятся целиком или перевыпускаются, §6)
du -sh /etc/letsencrypt 2>/dev/null
# только ИМЕНА ключей, не значения
command grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' /path/to/.env
# права (644 на .env = читают все)
stat -c '%a %n' /path/to/.env
```
`-maxdepth` после `-prune` не ставить: GNU find ругается на порядок опций. На сервере 27.10 команда
нашла 122 пути за 1 с, включая `.credentials.json`, `~/.ssh/*`, `~/.config/gh/hosts.yml`,
`.vpn_root_pass`, `.jev_access_key`, которые шаблон 0.2.0 пропускал.

- **Значения секретов никогда не выводить** в терминал, опись или отчёт. Фильтр
  `grep -viE 'key|token|pass|secret'` для этого не годится: пропускает `AUTH_ACCOUNTS=user:<хэш>`,
  `DATABASE_URL=postgres://u:p@…` и т.п. Значение допустимо показать только по белому списку
  несекретных имён (HOST, PORT, MODEL, BINDING, URL без логина и пароля).
- **Пароли в строке подключения видны в `ps`** всем пользователям. Каждый такой случай внести в
  опись как **риск**, а в план добавить исправление: на новом сервере передавать через env или файл.
- **Ключ шифрования n8n** (`N8N_ENCRYPTION_KEY` в env или `~/.n8n/config` в volume): без него
  credentials n8n на новом месте не расшифруются. Отдельная строка, метка ПЕРЕНОСИМ. Что в `.env`,
  в `config` и в живом контейнере один и тот же ключ, проверять по хэшу, значение не печатается.
  `printf %s` и `tr -d '\n'` обязательны: хэш строки с `\n` от `cut`/`sed` другой, и выйдет ложное «≠»:
  ```bash
  ENVF=<папка n8n>/.env; CFG=<n8n_storage>/config; C=<контейнер n8n>
  h(){ sha256sum | cut -c1-16; }; E=$(printf '' | h)   # E = хэш пустой строки
  h1=$(sed -n 's/^N8N_ENCRYPTION_KEY=//p' "$ENVF" | tail -1 | tr -d '\r\n"'"'" | h)
  h2=$(python3 -I -c 'import json,sys; sys.stdout.write(json.load(open(sys.argv[1])).get("encryptionKey",""))' "$CFG" | h)
  h3=$(docker exec "$C" sh -c 'printf %s "$N8N_ENCRYPTION_KEY"' 2>/dev/null | h)
  for x in "env:$h1" "config:$h2" "контейнер:$h3"; do [ "${x#*:}" = "$E" ] && echo "${x%%:*}: ПУСТО"; done
  [ "$h1" = "$h2" ] && echo "env = config" || echo "env ≠ config"
  [ "$h1" = "$h3" ] && echo "env = контейнер" || echo "env ≠ контейнер"
  ```
- Ключи устройства Syncthing на новый сервер не копировать: там генерируется новый Device ID.
- Для каждого файла указать способ переноса: файлом по SSH/rsync (не git, не Syncthing) или
  перевыпуск на новом месте.

## 5. Базы данных — ВСЕ инстансы

**Инстанс** — отдельный процесс СУБД: хостовый кластер (`pg_lsclusters`) или контейнер. Внутри
каждого инстанса считать **базы**. Одинаковое имя базы в двух инстансах — ловушка: выяснить, какая
из них боевая.

```bash
# 1) кто слушает типовые порты СУБД (хост И docker-proxy)
ss -tlnpH | command grep -E ':(543[0-9]|3306|3307|27017|6379)\b'
# 2) хостовые СУБД вне Docker
systemctl list-units --all --no-legend --no-pager | command grep -iE 'postgres|mysql|mariadb|mongo|redis'
pg_lsclusters 2>/dev/null
# cd / — иначе psql под postgres ругается на чужую текущую папку
(cd / && sudo -u postgres psql -d postgres -Atc "select datname, pg_size_pretty(pg_database_size(datname)) from pg_database where not datistemplate and datname <> current_database()")
# 3) СУБД в Docker, включая контейнеры без опубликованных портов (их нет в ss)
docker ps -a --format '{{.Names}}\t{{.Image}}' | command grep -iE 'postgres|pgvector|mysql|mariadb|mongo|redis'
```

**Счёт баз.** Служебная база `postgres` не считается: `pg_dumpall` не пишет для неё
`CREATE DATABASE`, и счёт «живые ↔ дамп» иначе всегда расходится на 1. Подключаемся к `postgres`
(`-d postgres`), а `datname <> current_database()` её же и отсекает.

Список баз во всех Postgres-контейнерах. `-d postgres` обязателен: без него psql идёт в базу с именем
пользователя (`database "raguser" does not exist`). Если peer не пускает, второй заход — по TCP с
паролем из env самого контейнера; пароль в командную строку хоста не попадает:
```bash
Q='select datname from pg_database where not datistemplate and datname <> current_database()'
for c in $(docker ps --format '{{.Names}}\t{{.Image}}' | awk -F'\t' 'tolower($2) ~ /postgres|pgvector/ {print $1}'); do
  printf '%-25s ' "$c"
  docker exec -e Q="$Q" "$c" sh -c 'U="${POSTGRES_USER:-postgres}"
    psql -U "$U" -d postgres -Atc "$Q" 2>/dev/null ||
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$U" -d postgres -Atc "$Q" 2>&1' | tr '\n' ' '; echo
done
```
Остановленный контейнер так не прочитать: смотреть `CREATE DATABASE` в его свежем дампе.

**Висячие volume с данными СУБД** (ни один контейнер, даже остановленный, их не использует). В
списке инстансов их нет, поэтому без этой проверки они теряются. Каждый — строка `V-NN`:
```bash
for v in $(docker volume ls -qf dangling=true); do m=$(docker volume inspect -f '{{.Mountpoint}}' "$v")
  k=$(find "$m" -maxdepth 2 \( -name PG_VERSION -o -name ibdata1 -o -name WiredTiger \) -printf '%P ' 2>/dev/null)
  [ -n "$k" ] && echo "$v  $(du -sh "$m" | cut -f1)  $k"; done
```
По каждому нужно одно из двух: архив/дамп (`volume_<имя>.tar.gz` в папке дампов) или решение владельца
«не нужен» в `DECISIONS.tsv` той же папки. Иначе гейт не пройден (`risk-gates.md` §0).

**Redis и прочие кэши/очереди** в описи нужны (порт, volume, кто пишет), но гейт дампов их не
требует: обычно это очередь или кэш. Если в Redis лежит то, что нельзя потерять (сессии ботов,
очередь n8n в режиме queue), в плане это отдельный пункт: копировать `dump.rdb`/`appendonly.aof`
из volume после остановки.

**Кто может подключиться снаружи** (вход для метки КРИТИЧНЫЙ, см. «Правила заполнения»):
```bash
# хостовые кластеры: listen_addresses и host-правила pg_hba
for d in /etc/postgresql/*/*/; do echo "== $d"
  command grep -hE '^\s*listen_addresses' "$d/postgresql.conf" "$d"/conf.d/*.conf 2>/dev/null
  command grep -vE '^\s*(#|$)' "$d/pg_hba.conf" | awk '$1 ~ /^host/ {print $1, $2, $3, $4, $5}'; done
# какие порты СУБД слушают все интерфейсы
ss -tlnH | awk '$4 ~ /^(0\.0\.0\.0|\[::\]|\*):(543[0-9]|3306|27017)$/ {print "ВСЕ ИНТЕРФЕЙСЫ:", $4}'
# pg_hba внутри контейнеров (критично, если порт контейнера опубликован на 0.0.0.0, §6)
for c in $(docker ps --format '{{.Names}}\t{{.Image}}' | awk -F'\t' 'tolower($2) ~ /postgres|pgvector/ {print $1}'); do
  printf '%s: ' "$c"; docker exec "$c" sh -c 'U="${POSTGRES_USER:-postgres}"
    f=$(psql -U "$U" -d postgres -Atc "show hba_file" 2>/dev/null || PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$U" -d postgres -Atc "show hba_file" 2>/dev/null)
    grep -vE "^\s*(#|$)" "$f" | awk "\$1 ~ /^host/ {print \$4, \$5}" | sort -u | tr "\n" ";"'; echo; done
```
`0.0.0.0/0`, `::/0` или `all` в host-правиле при прослушивании всех интерфейсов — КРИТИЧНЫЙ риск в
§0, даже если сейчас порт закрывает ufw.

По каждому инстансу записать: тип (host/docker), порт, bind (127.0.0.1 или 0.0.0.0), volume или
каталог данных, базы с размерами, кто подключается, есть ли дамп. Таблица инстансов — вход для
гейта «все БД задамплены» (`risk-gates.md` §0).

> Хук-стопор ложно срабатывает на команды, где встречаются `n8n` и `execut`. SQL к базе n8n класть
> в файл: `docker exec -i <c> psql -U <user> -d <db> < query.sql`.

## 6. Сеть, веб, DNS

```bash
ss -tulpn
sudo ufw status verbose
ip -br a
# всё, что слушает все интерфейсы: Docker-порты идут мимо ufw (iptables DOCKER), хостовые закрывает ufw
ss -tulpnH | awk '$5 ~ /^(0\.0\.0\.0|\[::\]|\*):/ {w=($7 ~ /docker-proxy/) ? "DOCKER (мимо ufw!)" : "host (сверить с ufw)"; print $1, $5, w, $7}' \
  | sed -E 's/,pid=[0-9]+,fd=[0-9]+//g' | sort -u
docker ps --format '{{.Names}}\t{{.Ports}}' | command grep -E '0\.0\.0\.0:|:::'
# файрвол, сохранённый в обход ufw: iptables-persistent / netfilter-persistent и nftables
systemctl is-enabled netfilter-persistent nftables 2>&1 | paste -sd' '
dpkg -l iptables-persistent netfilter-persistent nftables 2>/dev/null | awk '/^ii/{print $2}' | paste -sd' '
ls -l --time-style=+%F /etc/iptables/ 2>/dev/null
for f in /etc/iptables/rules.v4 /etc/iptables/rules.v6; do [ -f "$f" ] && printf '%s: правил %s, из них DOCKER %s, таблица nat: %s\n' \
  "$f" "$(command grep -c '^-A' "$f")" "$(command grep -c '^-A DOCKER' "$f")" "$(command grep -c '^\*nat' "$f")"; done
[ -f /etc/nftables.conf ] && echo "nftables.conf: $(command grep -cvE '^\s*(#|$)' /etc/nftables.conf) значимых строк"
nft list tables 2>/dev/null
# веб-сервер
ls /etc/nginx/sites-enabled/ 2>/dev/null
command grep -hE '^\s*(server_name|proxy_pass|root|return)\b' /etc/nginx/sites-enabled/* 2>/dev/null | sort -u
[ -f /etc/caddy/Caddyfile ] && command grep -nE '^[^#[:space:]].*\{|reverse_proxy|root' /etc/caddy/Caddyfile
sudo certbot certificates 2>/dev/null | command grep -E 'Certificate Name|Domains|Expiry'
du -sh /var/www/* 2>/dev/null
# DNS по всем доменам из конфигов (обычный grep здесь падает: ugrep не принимает пустую альтернативу)
for d in $(command grep -hoE 'server_name[^;]+' /etc/nginx/sites-enabled/* | sed 's/server_name//' | tr ' \t' '\n\n' | command grep -vE '^(_|)$' | sort -u); do
  printf '%-35s %s\n' "$d" "$(dig +short A "$d" | tr '\n' ' ')"; done
```

- Порт на `0.0.0.0` от Docker = открыт в интернет, даже если ufw его «не пускает». Пометить как риск;
  на новом сервере биндить на `127.0.0.1`.
- **Хостовые сервисы на `0.0.0.0`** (строки `host` в выводе выше) сверить с `ufw status`: что ufw
  пускает, то открыто. На новом сервере ufw может быть другим, поэтому такие сервисы записать в опись
  с пометкой «закрыт только ufw» и в плане решить, биндить ли их на `127.0.0.1`.
- **iptables-persistent / nftables** — отдельная строка `N-NN`, метка СПРОСИТЬ. Сохранённые правила
  содержат цепочки DOCKER и ufw, снятые на этом сервере. Скопировать `rules.v4` и поставить пакет на
  новом сервере «как есть» нельзя: правила перетрут цепочки Docker/ufw и сломают сеть. Выяснить,
  какие правила свои (обычно NAT/форвардинг VPN), и переносить только их, отдельным скриптом или
  через конфиг сервиса.
- **Статика `/var/www`** (редиректы, лендинги) переносится. От неё могут зависеть ссылки в постах.
- DNS: `dig` видит только известные имена. Полный список записей всё равно смотреть у регистратора.
  Домены, которые смотрят на чужой IP или не резолвятся, пометить СПРОСИТЬ.

## 7. Захардкоженные IP

```bash
# публичные IP сервера (без 127/10/172) + старые; точки экранированы
IPS="$(hostname -I | tr ' ' '\n' | command grep -E '^[0-9.]+$' | command grep -vE '^(127|10|172)\.' | sed 's/\./\\./g' | paste -sd'|')|<старый\.IP>"
command grep -lE "$IPS" ~/.claude/settings.json ~/.claude.json <репо>/.mcp.json /etc/postgresql/*/main/pg_hba.conf 2>/dev/null
command grep -rlE "$IPS" /etc/systemd/system ~/.config/systemd/user /etc/nginx /etc/network /etc/iptables 2>/dev/null
# command grep обязателен: обёртка ugrep молча пропускает gitignored-файлы, а там конфиги и секреты.
# Сессии Гермеса (request_dump_*.json) — 70% шума, исключены
command grep -rlE "$IPS" <репо> ~/.hermes --include='*.json' --include='*.yaml' --include='*.yml' --include='*.env' \
  --include='*.py' --include='*.sh' --include='*.md' --include='*.conf' --include='*.toml' \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=venv \
  --exclude-dir=sessions --exclude-dir=sessions-archive 2>/dev/null
```

По каждому файлу решить: заменить на `localhost` или домен, либо обновить на новый IP после переезда.

## 8. Файлы: репо, домашняя папка, инструменты

```bash
# репо: сколько НЕ в git (переносить rsync, а не clone). Пути идут через \0, поэтому кириллица и
# пробелы не ломают подсчёт (git status --porcelain экранирует кириллицу и даёт 1.1 ГБ вместо 3.0)
cd <репо>
echo "всё без .git: $(du -sh --exclude=.git . | cut -f1)   .git: $(du -sh .git | cut -f1)"
echo "tracked:      $(git ls-files -z | du -sch --files0-from=- 2>/dev/null | tail -1 | cut -f1)"
echo "gitignored:   $(git ls-files -z --others --ignored --exclude-standard --directory | du -sch --files0-from=- 2>/dev/null | tail -1 | cut -f1)"
echo "untracked:    $(git ls-files -z --others --exclude-standard --directory | du -sch --files0-from=- 2>/dev/null | tail -1 | cut -f1)"
# верхний уровень домашней папки
du -sh ~/* ~/.[!.]* 2>/dev/null | sort -rh | head -50
# рантайм
ls ~/.nvm/versions/node/ 2>/dev/null; for v in ~/.nvm/versions/node/*; do echo "$v:"; ls "$v/lib/node_modules"; done
node -v
# в шелле субагента claude может не быть в PATH (другая default-версия node)
command -v claude || ls -1 ~/.nvm/versions/node/*/bin/claude 2>/dev/null
# uv/pipx тоже бывают не в PATH: смотреть каталоги, а не только `uv tool list`
command -v uv pipx; ls ~/.local/share/uv/tools/ ~/.local/share/pipx/venvs/ 2>/dev/null
ls ~/.local/bin; du -sh /opt/* 2>/dev/null
# где nvm-версия вшита абсолютным путём
command grep -rlE '\.nvm/versions/node/v[0-9.]+' ~/.claude/settings.json ~/.claude.json <репо>/.mcp.json ~/.config/systemd/user ~/.hermes/config.yaml 2>/dev/null
```
`du -sh . .git` не годится: `du` не считает `.git` второй раз, он уже вошёл в `.`.

- Если gitignored-данных много, репо переносится только rsync.
- **`~/.claude`** отдельным разделом: skills, hooks, settings.json, plugins, память
  `projects/<slug>/memory/`. **Путь репо на новом сервере должен совпасть**, иначе slug папки памяти
  поменяется и память «потеряется».
- `~/*` разобрать по строкам. Кэши (`~/.cache`, `~/.npm`, `~/.vscode-server`) не переносятся.
  Неясное — СПРОСИТЬ, а не решать за владельца.
- Инструменты на новом сервере ставятся заново **тех же версий**. Венвы и `node_modules` не копировать.

## 9. Синхронизация

- Syncthing: устройства и папки (`curl -s -H "X-API-Key: $(command grep -oP '(?<=<apikey>)[^<]+' ~/.local/state/syncthing/config.xml)" http://127.0.0.1:8384/rest/config | jq '.devices[].name, .folders[].path'` — ключ не печатается). Путь конфига `~/.local/state/syncthing/` (или `~/.config/syncthing/`). Грабли — `syncthing-technical-notes.md`.
- Другие механизмы (облачный диск, git remote) — только если реально установлены. Названия папок
  бывают историческими.

## 10. Внешние привязки

- Домены и поддомены, которые смотрят на сервер (§6).
- Webhook-и сторонних сервисов (Telegram-боты, платёжки, n8n webhooks): меняется домен или только A-запись?
- OAuth redirect URI, IP в белых списках чужих сервисов, `pg_hba.conf`/ufw с внешними IP
  (бэкап-серверы и т.п.). По каждому — СПРОСИТЬ, жив ли он.

## Итог описи

1. **§0 Критично ДО Шага 3**: нет дампа, висячие volume с данными СУБД без решения, мёртвые пути,
   порты в интернет, пароли в `ps`, сохранённые правила iptables/nftables. Сверху — КРИТИЧНЫЕ (СУБД
   на всех интерфейсах + `0.0.0.0/0` в `pg_hba`). Каждый пункт со ссылкой на номер строки.
2. **Таблица счёта** (по правилу подсчёта из «Правил заполнения», командой оттуда же):

| Метка | Позиций |
|-------|---------|
| ПЕРЕНОСИМ | N |
| НЕ ПЕРЕНОСИМ (→ Геракл/архив) | N |
| СПРОСИТЬ | N |

3. **Кандидаты для Геракла**: список НЕ ПЕРЕНОСИМ → Геракл и решение, чистить ДО или ПОСЛЕ переезда.
4. **Вопросы к владельцу**: пронумерованы, на них ссылаются метки СПРОСИТЬ.
5. Контрольный вопрос: **«если выключить сервер прямо сейчас, что сломается и что потеряется?»**
   Каждый ответ должен быть строкой ПЕРЕНОСИМ или закрытым вопросом.
