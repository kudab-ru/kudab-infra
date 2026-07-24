import express from 'express';
import { config } from './config.js';
import { render, shutdownBrowser, currentLoad, browserLiveness, selfCheck } from './renderer.js';

const app = express();
app.use(express.json({ limit: '64kb' }));

function validateUrl(rawUrl) {
  if (typeof rawUrl !== 'string' || rawUrl.length === 0) {
    return { ok: false, error: 'url_required' };
  }
  let u;
  try {
    u = new URL(rawUrl);
  } catch {
    return { ok: false, error: 'url_malformed' };
  }
  if (!config.allowedSchemes.has(u.protocol)) {
    return { ok: false, error: `scheme_not_allowed:${u.protocol}` };
  }
  const host = u.hostname.toLowerCase();
  if (config.hostBlocklist.has(host)) {
    return { ok: false, error: `host_blocked:${host}` };
  }
  return { ok: true, url: u };
}

app.get('/health', (_req, res) => {
  // Проверяем РЕАЛЬНУЮ живость браузера, а не только то, что HTTP-сервер отвечает.
  // browserLiveness(): null = ещё не запущен (норм, поднимется по требованию);
  // true = подключён; false = есть инстанс, но disconnected (нездоров).
  // Раньше /health всегда отдавал ok → мёртвый браузер не ловился healthcheck'ом.
  const live = browserLiveness();
  const healthy = live !== false;
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'browser_disconnected',
    browser: live === null ? 'idle' : live ? 'connected' : 'disconnected',
    load: currentLoad(),
  });
});

app.post('/render', async (req, res) => {
  const startedAt = Date.now();
  const body = req.body || {};

  const v = validateUrl(body.url);
  if (!v.ok) {
    return res.status(400).json({
      status: 'bad_request',
      error: v.error,
      took_ms: Date.now() - startedAt,
    });
  }

  try {
    const result = await render({
      url: body.url,
      waitFor: body.wait_for,
      waitSelector: body.wait_selector,
      waitText: body.wait_text,
      waitTextRegex: body.wait_text_regex,
      timeoutMs: body.timeout_ms,
      userAgent: body.user_agent,
      viewport: body.viewport,
    });
    return res.json(result);
  } catch (err) {
    const tookMs = err.took_ms || Date.now() - startedAt;
    if (err.code === 'TIMEOUT') {
      return res.status(408).json({
        status: 'timeout',
        error: err.message,
        took_ms: tookMs,
      });
    }
    if (err.code === 'BUSY') {
      return res.status(503).json({
        status: 'busy',
        error: 'too_many_concurrent_renders',
        took_ms: tookMs,
      });
    }
    if (err.code === 'BAD_REQUEST') {
      return res.status(400).json({
        status: 'bad_request',
        error: err.message,
        took_ms: tookMs,
      });
    }
    return res.status(502).json({
      status: 'error',
      error: err.message || 'render_failed',
      took_ms: tookMs,
    });
  }
});

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(`[kudab-headless] listening on :${config.port}`);
});

// Watchdog: раз в минуту активно проверяем, что браузер реально отдаёт контекст
// (selfCheck ловит и краш-disconnect, и ЗАВИСАНИЕ через таймаут). Самоисцеление в
// renderer поднимает браузер по требованию; это — последний рубеж: если браузер
// неисцелим N раз подряд, выходим из процесса → Docker (restart: unless-stopped)
// поднимает свежий контейнер. Чтобы «тихая смерть» браузера больше не застревала.
const WATCHDOG_INTERVAL_MS = 60000;
const WATCHDOG_MAX_FAILS = 3;
let watchdogFails = 0;
const watchdog = setInterval(async () => {
  try {
    await selfCheck(8000);
    watchdogFails = 0;
  } catch (err) {
    watchdogFails += 1;
    console.error(`[watchdog] браузер нездоров (${watchdogFails}/${WATCHDOG_MAX_FAILS}): ${err.message}`);
    if (watchdogFails >= WATCHDOG_MAX_FAILS) {
      console.error('[watchdog] браузер неисцелим → process.exit(1) для рестарта контейнера');
      clearInterval(watchdog);
      process.exit(1);
    }
  }
}, WATCHDOG_INTERVAL_MS);

async function shutdown(signal) {
  console.log(`[kudab-headless] ${signal} received, shutting down`);
  clearInterval(watchdog);
  server.close();
  await shutdownBrowser();
  process.exit(0);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
