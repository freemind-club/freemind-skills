#!/usr/bin/env python3
"""
Lesson Processor — транскрипция + саммари + тайм-коды
======================================================
Создаёт HTML-конспект урока с тайм-кодами и ключевыми мыслями.

Использование:
  python process_lesson.py "https://youtube.com/watch?v=..."
  python process_lesson.py /path/to/audio.mp3
  python process_lesson.py /path/to/video.mp4

Зависимости:
  - ffmpeg: brew install ffmpeg (macOS)
  - yt-dlp: pip install yt-dlp
  - requests: pip install requests
"""

import sys
import re
import os
import json
import time
import subprocess
import tempfile
import shutil
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional

# ─────────────────────────────────────────────
# Настройка путей и API ключа
# ─────────────────────────────────────────────

def find_env_file() -> Optional[Path]:
    """Ищет .env файл начиная от текущей директории вверх до 5 уровней."""
    current = Path(__file__).parent
    for _ in range(5):
        env_path = current / ".env"
        if env_path.exists():
            return env_path
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


def load_env_key(name: str) -> Optional[str]:
    """Ключ из переменных окружения, ближайшего .env или ~/.env."""
    if os.getenv(name):
        return os.getenv(name)
    for env_path in (find_env_file(), Path.home() / ".env"):
        if env_path and env_path.exists():
            for line in env_path.read_text().splitlines():
                line = line.strip()
                if line.startswith(name + "="):
                    key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    os.environ[name] = key
                    return key
    return None


# Расшифровка: Deepgram nova-3 по умолчанию, Groq Whisper — резерв.
# Саммари и тайм-коды — Groq LLM (нужен GROQ_API_KEY).
DEEPGRAM_API_KEY = load_env_key("DEEPGRAM_API_KEY")
GROQ_API_KEY = load_env_key("GROQ_API_KEY")
CF_AI_TOKEN = load_env_key("CF_AI_TOKEN")  # запасной Whisper (Cloudflare Workers AI), 23.11
CF_ACCOUNT = load_env_key("CF_ACCOUNT_ID")  # ID аккаунта Cloudflare (необязательно, запасной Whisper)
if not GROQ_API_KEY:
    print("❌ GROQ_API_KEY не найден (нужен для саммари и как резерв расшифровки).")
    print("   Добавь в .env файл или в переменные окружения:")
    print("   export GROQ_API_KEY=ваш_ключ")
    print("   Бесплатный ключ: https://console.groq.com")
    sys.exit(1)

# ─────────────────────────────────────────────
# Пути и кэш
# ─────────────────────────────────────────────

OUTPUT_DIR = Path(__file__).parent / "processed"
OUTPUT_DIR.mkdir(exist_ok=True)

CACHE_DIR = Path(__file__).parent / "cache"
CACHE_DIR.mkdir(exist_ok=True)


def log(msg):
    """Красивый вывод в консоль."""
    print(msg, flush=True)


def check_dependencies():
    """Проверяет наличие ffmpeg и yt-dlp."""
    missing = []
    for tool in ['ffmpeg']:
        if not shutil.which(tool):
            missing.append(tool)
    
    if missing:
        print(f"❌ Не установлены: {', '.join(missing)}")
        print(f"   macOS: brew install {' '.join(missing)}")
        print(f"   Linux: sudo apt install {' '.join(missing)}")
        sys.exit(1)


def get_cache_key(source: str) -> str:
    """Создаёт ключ кэша на основе источника."""
    return hashlib.md5(source.encode()).hexdigest()


def load_cache(cache_key: str) -> Optional[dict]:
    """Загружает кэш если существует."""
    cache_file = CACHE_DIR / f"{cache_key}.json"
    if cache_file.exists():
        try:
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            log(f"♻️  Загружено из кэша: {cache_file.name}")
            return data
        except Exception as e:
            log(f"⚠️  Ошибка чтения кэша: {e}")
    return None


def save_cache(cache_key: str, data: dict):
    """Сохраняет результат в кэш."""
    cache_file = CACHE_DIR / f"{cache_key}.json"
    try:
        cache_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        log(f"💾 Кэш сохранён: {cache_file.name}")
    except Exception as e:
        log(f"⚠️  Ошибка сохранения кэша: {e}")


# ─────────────────────────────────────────────
# YouTube Download
# ─────────────────────────────────────────────

def check_yt_dlp():
    """Проверяет наличие yt-dlp."""
    if not shutil.which("yt-dlp"):
        print("❌ yt-dlp не найден.")
        print("   macOS: brew install yt-dlp")
        print("   pip: pip install yt-dlp")
        sys.exit(1)


def download_youtube_audio(url: str, tmpdir: str) -> tuple[str, str]:
    """Скачивает аудио с YouTube, возвращает (путь_к_файлу, название_видео)"""
    check_yt_dlp()
    log("⬇️  Скачиваю аудио с YouTube...")
    audio_file = os.path.join(tmpdir, "audio.%(ext)s")

    # Получаем название
    result = subprocess.run(
        ["yt-dlp", "--dump-json", "--no-playlist", url],
        capture_output=True, text=True, timeout=60
    )
    title = "урок"
    if result.returncode == 0:
        try:
            info = json.loads(result.stdout)
            title = info.get("title", "урок")
        except json.JSONDecodeError:
            log("⚠️  Не удалось получить название видео")

    # Скачиваем аудио
    result = subprocess.run([
        "yt-dlp", "-x", "--audio-format", "mp3",
        "--audio-quality", "0",
        "-o", audio_file,
        "--no-playlist",
        url
    ], capture_output=True, text=True, timeout=300)

    if result.returncode != 0:
        error_msg = result.stderr[:200] if result.stderr else "Неизвестная ошибка"
        print(f"❌ Ошибка скачивания: {error_msg}")
        sys.exit(1)

    # Ищем скачанный файл
    for f in Path(tmpdir).glob("audio.*"):
        return str(f), title

    print("❌ Аудио файл не найден после скачивания")
    sys.exit(1)


# ─────────────────────────────────────────────
# Audio Processing
# ─────────────────────────────────────────────

def split_audio_if_needed(audio_path: str, tmpdir: str) -> list[str]:
    """Если файл > 24мб — нарезает по 10 минут через ffmpeg"""
    size_mb = os.path.getsize(audio_path) / (1024 * 1024)
    if size_mb <= 24:
        return [audio_path]

    log(f"✂️  Файл {size_mb:.1f}мб > 24мб, нарезаю по 10 минут...")
    parts_dir = os.path.join(tmpdir, "parts")
    os.makedirs(parts_dir, exist_ok=True)
    pattern = os.path.join(parts_dir, "part_%03d.mp3")

    result = subprocess.run([
        "ffmpeg", "-i", audio_path,
        "-f", "segment", "-segment_time", "600",
        "-c", "copy", pattern, "-y"
    ], capture_output=True, text=True, timeout=120)

    if result.returncode != 0:
        log(f"❌ Ошибка нарезки аудио: {result.stderr[:200]}")
        sys.exit(1)

    parts = sorted(Path(parts_dir).glob("part_*.mp3"))
    return [str(p) for p in parts]


def transcribe_groq(audio_path: str) -> dict:
    """Транскрибирует аудио через Groq Whisper, возвращает {text, segments}"""
    import requests

    try:
        with open(audio_path, "rb") as f:
            resp = requests.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                files={"file": (os.path.basename(audio_path), f, "audio/mpeg")},
                data={
                    "model": "whisper-large-v3",
                    "response_format": "verbose_json",
                    "language": "ru",
                },
                timeout=120,
            )
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.RequestException as e:
        log(f"⚠️  Groq Whisper не сработал ({e}), пробую Cloudflare Whisper")
        result = transcribe_cf(audio_path)
        if result is not None:
            return result
        log("❌ Все сервисы расшифровки отказали (Deepgram, Groq, Cloudflare)")
        sys.exit(1)


def transcribe_cf(audio_path: str) -> Optional[dict]:
    """Cloudflare Workers AI whisper-large-v3-turbo → {text, segments}. None при ошибке."""
    import base64, requests

    if not CF_AI_TOKEN or not CF_ACCOUNT:
        return None
    try:
        with open(audio_path, "rb") as f:
            audio_b64 = base64.b64encode(f.read()).decode()
        resp = requests.post(
            f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT}/ai/run/@cf/openai/whisper-large-v3-turbo",
            headers={"Authorization": f"Bearer {CF_AI_TOKEN}"},
            json={"audio": audio_b64, "language": "ru"},
            timeout=600,
        )
        resp.raise_for_status()
        r = resp.json()["result"]
        segments = [{"start": x["start"], "end": x["end"], "text": x["text"]} for x in r.get("segments", [])]
        return {"text": r.get("text", ""), "segments": segments}
    except Exception as e:
        log(f"⚠️  Cloudflare Whisper не сработал ({e})")
        return None


def transcribe_deepgram(audio_path: str) -> Optional[dict]:
    """Deepgram nova-3 → {text, segments} в формате как у Groq. None при ошибке."""
    import requests

    if not DEEPGRAM_API_KEY:
        return None
    try:
        with open(audio_path, "rb") as f:
            resp = requests.post(
                "https://api.deepgram.com/v1/listen",
                params={"model": "nova-3", "language": "ru",
                        "smart_format": "true", "utterances": "true"},
                headers={"Authorization": f"Token {DEEPGRAM_API_KEY}",
                         "Content-Type": "audio/mpeg"},
                data=f,
                timeout=600,
            )
        resp.raise_for_status()
        data = resp.json()
        alt = data["results"]["channels"][0]["alternatives"][0]
        segments = [
            {"start": u["start"], "end": u["end"], "text": u["transcript"]}
            for u in data["results"].get("utterances", [])
        ]
        return {"text": alt.get("transcript", ""), "segments": segments}
    except Exception as e:
        log(f"⚠️  Deepgram не сработал ({e}), перехожу на Groq Whisper")
        return None


def transcribe_part(audio_path: str, use_deepgram: bool = True) -> dict:
    """Deepgram по умолчанию, Groq Whisper — резерв."""
    result = transcribe_deepgram(audio_path) if use_deepgram else None
    if result is not None and result.get("text"):
        return result
    # Резерв: Groq принимает до 25 МБ — большой файл режем на куски
    if os.path.getsize(audio_path) > 24 * 1024 * 1024:
        tmp = tempfile.mkdtemp(prefix="lesson_parts_")
        try:
            parts = split_audio_if_needed(audio_path, tmp)
            text, segments = transcribe_all_parts(parts, use_deepgram=False)
            return {"text": text, "segments": segments}
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    return transcribe_groq(audio_path)


def transcribe_all_parts(parts: list[str], use_deepgram: bool = True) -> tuple[str, list[dict]]:
    """Транскрибирует все части, объединяет текст и сегменты с правильными смещениями"""
    full_text = ""
    all_segments = []
    time_offset = 0.0

    for i, part in enumerate(parts):
        log(f"🎤 Транскрибирую часть {i+1}/{len(parts)}...")
        result = transcribe_part(part, use_deepgram)
        full_text += result.get("text", "") + " "

        for seg in result.get("segments", []):
            seg_copy = dict(seg)
            seg_copy["start"] = seg["start"] + time_offset
            seg_copy["end"] = seg["end"] + time_offset
            all_segments.append(seg_copy)

        # Смещение = конец последнего сегмента
        if result.get("segments"):
            time_offset = all_segments[-1]["end"]

    return full_text.strip(), all_segments


# ─────────────────────────────────────────────
# Summary & Timecodes
# ─────────────────────────────────────────────

def seconds_to_mmss(seconds: float) -> str:
    """ММ:СС до часа, Ч:ММ:СС после (1:03:08, а не 63:08)."""
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def safe_json_parse(content: str) -> dict:
    """Безопасный парсинг JSON с fallback если LLM вернул кривой ответ."""
    # Попытка 1: прямой парсинг
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass
    
    # Попытка 2: извлечение из markdown блока
    if "```" in content:
        try:
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
            return json.loads(content.strip())
        except (json.JSONDecodeError, IndexError):
            pass
    
    # Попытка 3: поиск JSON объекта
    import re
    json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', content, re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group())
        except json.JSONDecodeError:
            pass
    
    # Fallback: возвращаем пустую структуру
    log("⚠️  Не удалось распарсить JSON от LLM, использую fallback")
    return {
        "summary": "Ошибка анализа: LLM вернул некорректный JSON",
        "timecodes": [],
        "key_points": []
    }


SUMMARY_MODEL = "openai/gpt-oss-120b"


def _mmss_to_min(t: str) -> float:
    try:
        parts = [int(x) for x in t.split(":")]
    except ValueError:
        return -1
    if len(parts) == 3:
        return parts[0] * 60 + parts[1] + parts[2] / 60
    return parts[0] + (parts[1] / 60 if len(parts) > 1 else 0)


def warn_timecode_gaps(timecodes: list, duration_min: float, max_gap: float = 15) -> None:
    """Предупреждает, если между тайм-кодами (или в хвосте) провал > max_gap минут."""
    marks = sorted(m for m in (_mmss_to_min(tc.get("time", "")) for tc in timecodes) if m >= 0)
    if not marks:
        return
    points = marks + ([duration_min] if duration_min else [])
    for a, b in zip(points, points[1:]):
        if b - a > max_gap:
            log(f"⚠️  Провал в тайм-кодах: {int(a)}–{int(b)} мин без отметок — проверь подпись")


def fix_timecodes(tcs: list, windows: list, segments: list) -> list:
    """Время тайм-кода = точная секунда фразы-цитаты ("quote"), найденной по ВСЕЙ расшифровке
    (номер окна модель путает — описание уезжало от момента). Нет цитаты → время модели,
    привязанное к ближайшей фразе. Сортировка, дубли ближе 60 с убираются. Ч:ММ:СС после часа."""
    if not segments:
        return tcs
    W = [set(re.findall(r"\w+", (segments[k]["text"] + " " + (segments[k + 1]["text"] if k + 1 < len(segments) else "")).lower()))
         for k in range(len(segments))]
    placed = []
    for tc in tcs:
        desc = tc.get("description", "").strip()
        q = set(re.findall(r"\w+", tc.get("quote", "").lower()))
        seg = None
        if len(q) >= 3:
            best = max(range(len(segments)), key=lambda k: len(q & W[k]))
            if len(q & W[best]) >= max(2, (len(q) + 1) // 2):
                seg = segments[best]
        if seg is None:
            want = _mmss_to_min(tc.get("time", "")) * 60
            if want < 0:
                continue
            seg = min(segments, key=lambda x: abs(x["start"] - want))
        placed.append((seg["start"], desc))
    placed.sort()
    out = []
    for st, desc in placed:
        if out and st - out[-1][0] < 60:
            continue
        out.append((st, desc))
    if out:
        out[0] = (0, out[0][1]) if out[0][0] < 90 else out[0]
    return [{"time": seconds_to_mmss(st), "description": d} for st, d in out]


def _groq_json(prompt: str, max_tokens: int = 4000) -> dict:
    """Один вызов Groq с JSON-ответом и повтором на 429 (free: 8000 токенов/мин)."""
    import requests
    payload = {
        "model": SUMMARY_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": max_tokens,
        "reasoning_effort": "low",  # иначе рассуждения съедают ответ и JSON обрезается
        "response_format": {"type": "json_object"},
    }
    for attempt in range(6):
        resp = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json=payload, timeout=120)
        if resp.status_code != 429:
            break
        wait = 20 * (attempt + 1)
        log(f"⏳ Лимит Groq (429), жду {wait} с и повторяю...")
        time.sleep(wait)
    resp.raise_for_status()
    return safe_json_parse(resp.json()["choices"][0]["message"]["content"].strip())


def create_summary_and_timecodes(full_text: str, segments: list[dict]) -> dict:
    """Саммари и тайм-коды через Groq LLM.
    23.11: длинную запись режем на части по ~30 мин (6 окон по ~5 мин) — за один вызов
    модель читала только первые ~28 минут из 88 и размазывала их по всему уроку.
    Каждая часть — свой вызов с цитатами; итоговое саммари — отдельный вызов по частям."""
    import requests

    duration_s = segments[-1]["end"] if segments else 0
    duration_min = duration_s / 60
    n_tc = int(min(20, max(6, round(duration_min / 5))))
    desc_limit = 60 if n_tc <= 10 else 45  # подпись к видео в Telegram ≤ 1024
    win = duration_s / n_tc if n_tc else 1
    PART_CHARS = 11000
    WIN_PER_PART = 6
    windows = []
    for w in range(n_tc):
        w0, w1 = w * win, (w + 1) * win
        segs = [s for s in segments if w0 <= s["start"] < w1]
        windows.append((w0, w1, segs))
    groups = [windows[i:i + WIN_PER_PART] for i in range(0, len(windows), WIN_PER_PART)]

    def window_text(segs, budget):
        sub, cur = [], None
        for s in segs:
            if cur is None or s["start"] - cur[0] >= 20:
                cur = [s["start"], ""]
                sub.append(cur)
            cur[1] += " " + s["text"]
        per_line = max(60, budget // max(1, len(sub)) - 9)
        out = []
        for st, tx in sub:
            tx = tx.strip()
            if len(tx) > per_line:
                tx = tx[:per_line].rsplit(" ", 1)[0] + "…"
            out.append(f"[{seconds_to_mmss(st)}] {tx}")
        return "\n".join(out)

    all_tcs, part_notes = [], []
    try:
        for gi, grp in enumerate(groups, 1):
            budget = PART_CHARS // len(grp)
            body = "\n".join(f"=== ОКНО {i + 1} ===\n" + window_text(segs, budget) for i, (_, _, segs) in enumerate(grp))
            p0, p1 = seconds_to_mmss(grp[0][0]), seconds_to_mmss(grp[-1][1])
            log(f"🧠 Часть {gi}/{len(groups)} ({p0}–{p1})...")
            prompt = f"""Ты помощник для создания конспектов уроков. Перед тобой часть {gi} из {len(groups)} записи урока ({p0}–{p1}), разбитая на {len(grp)} окон.

Транскрипция с таймкодами:
{body}

Ответь JSON:
{{
  "timecodes": [{{"window": 1, "time": "12:34", "quote": "дословная фраза из транскрипции", "description": "о чём"}}],
  "part_summary": "2-3 предложения: о чём эта часть, конкретно",
  "key_points": ["конкретная мысль с цифрами"]
}}

Дай РОВНО {len(grp)} тайм-кодов — по одному на каждое окно, по порядку. Для окна найди строку, где автор НАЧИНАЕТ главную тему окна (новый слайд, вопрос, пример, «давайте…», «следующее…»), и возьми её метку времени точно как в транскрипции. "quote" — 4–8 слов ДОСЛОВНО из этой строки (по ним найдём точную секунду). Описание — не длиннее {desc_limit} знаков, по сути, без слов «обсуждение», «вступление».
2-4 ключевые мысли этой части — конкретно, с цифрами. Только JSON. На русском."""
            d = _groq_json(prompt)
            all_tcs += d.get("timecodes", [])
            part_notes.append(f"Часть {gi} ({p0}–{p1}): {d.get('part_summary', '')}\nМысли: " + "; ".join(d.get("key_points", [])))

        final = _groq_json(f"""Ниже краткие конспекты частей одного урока (по порядку).

{chr(10).join(part_notes)}

Ответь JSON:
{{"summary": "О чём весь урок одним абзацем, 2-3 предложения", "key_points": ["5-7 ключевых мыслей всего урока — конкретно, с цифрами и выводами, не общими словами"]}}
Только JSON. На русском.""", max_tokens=2000)
        data = {"summary": final.get("summary", ""), "key_points": final.get("key_points", []),
                "timecodes": fix_timecodes(all_tcs, windows, segments)}
        warn_timecode_gaps(data["timecodes"], duration_min)
        return data

    except requests.exceptions.Timeout:
        log("❌ Таймаут Groq LLM API")
        return {"summary": "Таймаут анализа", "timecodes": [], "key_points": []}
    except requests.exceptions.RequestException as e:
        log(f"❌ Ошибка Groq LLM API: {e}")
        return {"summary": f"Ошибка анализа: {e}", "timecodes": [], "key_points": []}
    except (KeyError, IndexError) as e:
        log(f"❌ Неожиданный формат ответа API: {e}")
        return {"summary": "Ошибка формата ответа API", "timecodes": [], "key_points": []}


# ─────────────────────────────────────────────
# HTML Generation
# ─────────────────────────────────────────────

def generate_html(title: str, summary_data: dict, full_transcript: str) -> str:
    # &nbsp;-спейсер между блоками — реальный текстовый узел, переживает
    # копирование в Telegram/соцсети как пустая строка (в отличие от
    # margin/padding, которые при копировании обычно теряются).
    spacer = '<div class="spacer">&nbsp;</div>'
    timecodes_html = spacer.join(
        f'<div class="timecode"><span class="tc-time">{tc["time"]}</span> <span class="tc-dash">—</span> {tc["description"]}</div>'
        for tc in summary_data.get("timecodes", [])
    )
    keypoints_html = spacer.join(
        f'<div class="keypoint">→ {point}</div>'
        for point in summary_data.get("key_points", [])
    )
    date_str = datetime.now().strftime("%d.%m.%Y")

    return f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0d0d0d;
    color: #e0e0e0;
    font-family: 'Segoe UI', system-ui, sans-serif;
    line-height: 1.7;
    padding: 40px 20px;
  }}
  .container {{ max-width: 860px; margin: 0 auto; }}
  h1 {{
    font-size: 1.8em;
    font-weight: 700;
    color: #fff;
    border-bottom: 2px solid #333;
    padding-bottom: 16px;
    margin-bottom: 8px;
  }}
  .meta {{ color: #666; font-size: 0.85em; margin-bottom: 40px; }}
  .section {{ margin-bottom: 40px; }}
  .spacer {{ font-size: 0.5em; line-height: 1; }}
  h2 {{
    font-size: 1.1em;
    font-weight: 700;
    color: #aaa;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    margin-bottom: 16px;
  }}
  .summary {{
    background: #1a1a1a;
    border-left: 3px solid #4a9eff;
    padding: 20px 24px;
    border-radius: 4px;
    font-size: 1.05em;
    color: #d0d0d0;
    font-style: italic;
  }}
  .timecode {{
    padding: 10px 0;
  }}
  .tc-time {{
    font-family: 'Courier New', monospace;
    color: #4a9eff;
    font-size: 0.9em;
    font-weight: normal;
    margin-right: 8px;
  }}
  .tc-dash {{ font-weight: normal; }}
  .keypoint {{ padding: 8px 0; }}
  details {{ margin-top: 0; }}
  summary {{
    cursor: pointer;
    padding: 14px 18px;
    background: #1a1a1a;
    border-radius: 6px;
    color: #aaa;
    font-size: 0.9em;
    user-select: none;
    list-style: none;
  }}
  summary:hover {{ color: #fff; background: #222; }}
  summary::-webkit-details-marker {{ display: none; }}
  .transcript-text {{
    background: #111;
    padding: 24px;
    margin-top: 8px;
    border-radius: 6px;
    font-size: 0.88em;
    color: #999;
    white-space: pre-wrap;
    line-height: 1.9;
  }}
  .badge {{
    display: inline-block;
    background: #1e3a5f;
    color: #4a9eff;
    font-size: 0.75em;
    padding: 2px 8px;
    border-radius: 10px;
    margin-left: 8px;
    vertical-align: middle;
  }}
</style>
</head>
<body>
<div class="container">
  <h1>{title} <span class="badge">конспект</span></h1>
  <div class="meta">Создан {date_str} · Deepgram / Groq Whisper + {SUMMARY_MODEL}</div>

  <div class="section">
    <h2>О чём урок</h2>
    <div class="summary"><em>{summary_data.get("summary", "")}</em></div>
  </div>

  {spacer}

  <div class="section">
    <h2>Тайм-коды</h2>
    {timecodes_html}
  </div>

  {spacer}

  <div class="section">
    <h2>Ключевые мысли</h2>
    {keypoints_html}
  </div>

  {spacer}

  <div class="section">
    <h2>Полная транскрипция</h2>
    <details>
      <summary>▶ Показать транскрипцию</summary>
      <div class="transcript-text">{full_transcript}</div>
    </details>
  </div>
</div>
</body>
</html>"""


TELEGRAM_CAPTION_LIMIT = 1024


def pretty_title(stem: str) -> str:
    """Имя файла → заголовок: в именах файлов нельзя «:», его заменяют на «-»
    («Гермесе- мозг» → «Гермесе: мозг»). Заголовок НЕ обрезаем — обрезается
    только имя выходного файла (safe_filename)."""
    import re
    return re.sub(r"(?<=[\wА-Яа-яЁё])- ", ": ", stem).strip()


def tg_len(text: str) -> int:
    """Длина так, как считает Telegram (UTF-16: эмодзи = 2+ символа)."""
    return len(text.encode("utf-16-le")) // 2


def generate_caption(title: str, summary_data: dict) -> str:
    """Короткая ПОДПИСЬ под видео — только заголовок + тайм-коды, чистый
    plain text без HTML/CSS. Держим её отдельно от полного конспекта:
    Telegram обрезает подпись к видео на 1024 символах, а тайм-коды сами
    по себе уже могут занимать 500-1000 — саммари и ключевые мысли туда
    не влезают и должны идти отдельным сообщением после видео."""
    lines = [title, ""]
    for tc in summary_data.get("timecodes", []):
        lines.append(f'{tc["time"]} — {tc["description"]}')
    caption = "\n".join(lines)
    if tg_len(caption) > TELEGRAM_CAPTION_LIMIT:
        log(f"⚠️  Подпись {tg_len(caption)} символов > {TELEGRAM_CAPTION_LIMIT} (лимит Telegram на подпись к видео) — сократи тайм-коды вручную")
    return caption


def safe_filename(title: str) -> str:
    import re
    safe = re.sub(r'[^\w\s\-а-яёА-ЯЁ]', '', title)
    safe = re.sub(r'\s+', '_', safe.strip())
    return safe[:50] or "урок"


# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("╔══════════════════════════════════════════════════╗")
        print("║  Lesson Processor — транскрипция + конспект      ║")
        print("╚══════════════════════════════════════════════════╝")
        print()
        print("Использование: python process_lesson.py <источник>")
        print()
        print("Источники:")
        print("  🎬 YouTube URL    — скачать и обработать")
        print("  🎵 Аудио файл     — mp3, wav, ogg, m4a")
        print("  📹 Видео файл     — mp4, mov, avi (авто-конвертация)")
        print()
        print("Примеры:")
        print('  python process_lesson.py "https://youtube.com/watch?v=..."')
        print("  python process_lesson.py lesson.mp3")
        print("  python process_lesson.py video.mp4")
        sys.exit(1)

    # Проверка зависимостей
    check_dependencies()

    source = sys.argv[1]
    cache_key = get_cache_key(source)

    # Проверяем кэш
    cached = load_cache(cache_key)
    if cached and "--resummary" in sys.argv and cached.get("segments"):
        log("🧠 --resummary: пересоздаю саммари и тайм-коды по сегментам из кэша...")
        cached["summary"] = create_summary_and_timecodes(cached["transcript"], cached["segments"])
        save_cache(cache_key, cached)
    elif cached and "--resummary" in sys.argv:
        log("⚠️  В кэше нет сегментов (старый формат) — расшифрую заново")
        cached = None
    if cached:
        log(f"♻️  Найден кэш для: {source[:50]}...")
        log("🎨 Генерирую HTML из кэша...")
        date_str = datetime.now().strftime("%Y-%m-%d")
        filename = f"{safe_filename(cached['title'])}_{date_str}.html"
        output_path = OUTPUT_DIR / filename
        html = generate_html(cached['title'], cached['summary'], cached['transcript'])
        output_path.write_text(html, encoding="utf-8")
        caption_path = output_path.with_name(output_path.stem + "_caption.txt")
        caption_path.write_text(generate_caption(cached['title'], cached['summary']), encoding="utf-8")
        log(f"✅ Готово (из кэша): {output_path}")
        log(f"✅ Подпись под видео: {caption_path}")
        return

    tmpdir = tempfile.mkdtemp(prefix="lesson_")

    try:
        # Шаг 1: получаем аудио файл
        if source.startswith("http"):
            check_yt_dlp()
            audio_path, title = download_youtube_audio(source, tmpdir)
        else:
            title = pretty_title(Path(source).stem)
            log(f"📁 Использую файл: {source}")
            # Конвертируем видео/аудио в MP3 если не MP3
            if not source.lower().endswith(".mp3"):
                log("🔄 Конвертирую в MP3...")
                mp3_path = os.path.join(tmpdir, "audio.mp3")
                result = subprocess.run([
                    "ffmpeg", "-i", source, "-vn",
                    "-acodec", "libmp3lame", "-ar", "16000", "-ac", "1",
                    mp3_path, "-y"
                ], capture_output=True, text=True, timeout=300)
                if result.returncode != 0:
                    print(f"❌ Ошибка конвертации: {result.stderr[:200]}")
                    sys.exit(1)
                audio_path = mp3_path
            else:
                audio_path = source

        # Шаг 2: нарезаем если нужно (Deepgram берёт файл целиком, лимит 25 МБ — только у Groq)
        parts = [audio_path] if DEEPGRAM_API_KEY else split_audio_if_needed(audio_path, tmpdir)

        # Шаг 3: транскрипция
        log(f"🎤 Транскрибирую ({'Deepgram nova-3, резерв Groq' if DEEPGRAM_API_KEY else 'Groq Whisper'})...")
        full_text, segments = transcribe_all_parts(parts)
        log(f"   Транскрипция: {len(full_text)} символов, {len(segments)} сегментов")

        # Шаг 4: саммари и тайм-коды
        log("🧠 Создаю саммари и тайм-коды...")
        summary_data = create_summary_and_timecodes(full_text, segments)

        # Сохраняем в кэш
        save_cache(cache_key, {
            "title": title,
            "transcript": full_text,
            "summary": summary_data,
            "segments_count": len(segments),
            "segments": [{"start": round(s["start"], 2), "end": round(s["end"], 2), "text": s["text"]} for s in segments],
            "created": datetime.now().isoformat()
        })

        # Шаг 5: генерируем HTML
        date_str = datetime.now().strftime("%Y-%m-%d")
        filename = f"{safe_filename(title)}_{date_str}.html"
        output_path = OUTPUT_DIR / filename

        html = generate_html(title, summary_data, full_text)
        output_path.write_text(html, encoding="utf-8")

        caption_path = output_path.with_name(output_path.stem + "_caption.txt")
        caption_path.write_text(generate_caption(title, summary_data), encoding="utf-8")

        log(f"✅ Готово: {output_path}")
        log(f"✅ Подпись под видео: {caption_path}")

    except KeyboardInterrupt:
        log("\n⚠️  Обработка прервана пользователем")
        sys.exit(130)
    except Exception as e:
        log(f"❌ Неожиданная ошибка: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    main()
