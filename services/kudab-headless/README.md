# kudab-headless

Headless Chromium renderer for kudab-parser. Used to fetch HTML from
JS-driven pages where `ExternalLinkFetcher` (simple HTTP + strip_tags)
returns empty content — primarily ticket-system widgets (btickets, qtickets
seat maps, Я.Афиша iframe) and future scraped sources (yandex.afisha).

Internal docker-network service. **No public port mapping.**

## API

### `GET /health`

```json
{ "status": "ok", "load": { "active": 0, "max": 3 } }
```

### `POST /render`

Request:
```json
{
  "url": "https://btickets.ru/widget/11069/scheme",
  "wait_for": "networkidle",           // load|domcontentloaded|networkidle|selector
  "wait_selector": ".price-block",     // required if wait_for=selector
  "timeout_ms": 15000,                 // default 15000, max 30000
  "user_agent": "...",                 // optional override
  "viewport": { "width": 1280, "height": 800 }
}
```

Response 200:
```json
{
  "status": "ok",
  "html": "<!DOCTYPE html>...",
  "html_bytes": 342567,
  "truncated": false,
  "final_url": "https://...",
  "http_status": 200,
  "took_ms": 4321
}
```

Error responses: `400 bad_request`, `408 timeout`, `503 busy`, `502 error`.

## Protections

- Host blocklist (vk/tg/youtube/instagram/etc.) — mirrors `ExternalLinkFetcher`.
- Schemes: http/https only.
- Hard timeout cap: 30s (env `MAX_TIMEOUT_MS`).
- Concurrent renders cap: 3 (env `MAX_CONCURRENT_RENDERS`).
- HTML truncation: 5MB (env `MAX_HTML_BYTES`).
- Image/media/font requests blocked at route level (we don't need them
  for HTML/JSON-LD extraction).
- One shared `chromium.launch()` per process, per-request `browser.newContext()`.

## Local test

```bash
docker compose exec kudab-parser curl -sS -X POST \
  http://kudab-headless:8080/render \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://btickets.ru/widget/11069/scheme","wait_for":"networkidle","timeout_ms":15000}' \
  | jq '{status, http_status, html_bytes, took_ms}'
```
