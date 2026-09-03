# RU-провайдеры: GigaChat, YandexGPT

Для студентов из РФ без зарубежных карт. Оба **не** чистый OpenAI-формат — своя авторизация.

## GigaChat (Сбер)

| | |
|--|--|
| base_url | `https://gigachat.devices.sberbank.ru/api/v1` |
| Авторизация | Basic-ключ (`GIGACHAT_AUTH_KEY`) → обмен на OAuth-токен, TTL 30 мин |
| Модели | `GigaChat-2-Max`, `GigaChat-2-Pro`, `GigaChat-2` |

```bash
TOKEN=$(curl -s https://ngw.devices.sberbank.ru:9443/api/v2/oauth \
  -H "Authorization: Basic $GIGACHAT_AUTH_KEY" -H "RqUID: $(uuidgen)" \
  -d 'scope=GIGACHAT_API_PERS' | jq -r .access_token)
curl https://gigachat.devices.sberbank.ru/api/v1/chat/completions -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"model":"GigaChat-2-Pro","messages":[{"role":"user","content":"..."}]}'
```

Особенности: корневой сертификат Минцифры (в trust store или `--insecure` для теста); токен обновлять каждые 30 мин; есть генерация изображений.

## YandexGPT (Yandex Cloud)

| | |
|--|--|
| base_url | `https://llm.api.cloud.yandex.net/v1` (OpenAI-совместимый режим) |
| Ключ | `YC_API_KEY` + `YC_FOLDER_ID` |
| Модели | `gpt://<folder>/yandexgpt/latest`, `.../yandexgpt-lite/latest`, `.../llama/latest` |

```bash
curl https://llm.api.cloud.yandex.net/v1/chat/completions -H "Authorization: Bearer $YC_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt://'$YC_FOLDER_ID'/yandexgpt-lite/latest","messages":[{"role":"user","content":"..."}]}'
```

Особенности: имя модели включает `folder_id`; нужен биллинг Yandex Cloud.

## Роль

Обе годятся и как `SELF_MODEL` (RU-оркестратор), и в `CHEAP_STACK` (русскоязычная пачка: рерайт, резюме, классификация). По русскому языку — сильны.
