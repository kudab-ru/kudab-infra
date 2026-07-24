import { chromium } from 'playwright';
import { config } from './config.js';

let browserPromise = null;
let browser = null; // разрешённый инстанс — для быстрой liveness-проверки в /health
let activeRenders = 0;

async function getBrowser() {
  if (!browserPromise) {
    browserPromise = chromium
      .launch({
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--disable-blink-features=AutomationControlled',
        ],
      })
      .then((b) => {
        // Самоисцеление: если браузер упал (краш/OOM/disconnect) — сбрасываем
        // кэш, чтобы СЛЕДУЮЩИЙ render перезапустил свежий Chromium. Без этого
        // browserPromise держал мёртвый объект и все рендеры вечно падали
        // «Target ... has been closed» (тихий сбой краулеров 2026-07-21: браузер
        // сдох, /health отдавал ok, healthcheck не ловил — 0 событий 3 суток).
        browser = b;
        b.on('disconnected', () => {
          browser = null;
          browserPromise = null;
        });
        return b;
      })
      .catch((e) => {
        // launch не удался — не кэшируем провал, дать следующему запросу шанс.
        browser = null;
        browserPromise = null;
        throw e;
      });
  }
  return browserPromise;
}

/**
 * Быстрая (синхронная) проверка живости для /health.
 * null  — браузер ещё не запущен (норм: поднимется по требованию);
 * true  — запущен и подключён;
 * false — есть инстанс, но disconnected (нездоров).
 */
export function browserLiveness() {
  return browser === null ? null : browser.isConnected();
}

/**
 * Активная проверка (watchdog): гарантировать, что браузер реально может
 * отдать контекст. Ловит и краш (disconnect), и ЗАВИСАНИЕ (isConnected=true,
 * но операции не отвечают) — через таймаут на launch и newContext.
 */
export async function selfCheck(timeoutMs = 8000) {
  const withTimeout = (p, msg) =>
    Promise.race([
      p,
      new Promise((_, reject) => setTimeout(() => reject(new Error(msg)), timeoutMs)),
    ]);
  const b = await withTimeout(getBrowser(), 'browser_launch_timeout');
  const ctx = await withTimeout(b.newContext(), 'browser_context_timeout');
  await ctx.close().catch(() => {});
  return true;
}

export async function shutdownBrowser() {
  if (browserPromise) {
    const b = await browserPromise;
    browserPromise = null;
    await b.close().catch(() => {});
  }
}

export function currentLoad() {
  return { active: activeRenders, max: config.maxConcurrentRenders };
}

/**
 * Render a single URL and return raw HTML.
 *
 * @param {object} req
 * @param {string} req.url
 * @param {'load'|'domcontentloaded'|'networkidle'|'selector'} [req.waitFor]
 * @param {string}  [req.waitSelector]
 * @param {number}  [req.timeoutMs]
 * @param {string}  [req.userAgent]
 * @param {{width:number,height:number}} [req.viewport]
 */
export async function render(req) {
  if (activeRenders >= config.maxConcurrentRenders) {
    const e = new Error('renderer_busy');
    e.code = 'BUSY';
    throw e;
  }

  const timeoutMs = Math.min(
    Math.max(parseInt(req.timeoutMs || config.defaultTimeoutMs, 10), 1000),
    config.maxTimeoutMs,
  );
  const waitFor = req.waitFor || 'networkidle';
  const userAgent = req.userAgent || config.defaultUserAgent;
  const viewport = req.viewport || { width: 1280, height: 800 };

  const browser = await getBrowser();
  const context = await browser.newContext({ userAgent, viewport });
  const page = await context.newPage();

  // Block heavy resources we don't need for HTML+JSON-LD extraction.
  // Keep stylesheets/scripts — many widgets need JS for price rendering.
  await page.route('**/*', (route) => {
    const t = route.request().resourceType();
    if (t === 'image' || t === 'media' || t === 'font') {
      return route.abort();
    }
    return route.continue();
  });

  activeRenders += 1;
  const startedAt = Date.now();
  try {
    // Для wait_for=selector/text стартуем с быстрого 'load' — конкретное
    // условие ниже всё равно дождётся реальной готовности страницы.
    const navWait = (waitFor === 'selector' || waitFor === 'text') ? 'load' : waitFor;
    const resp = await page.goto(req.url, {
      timeout: timeoutMs,
      waitUntil: navWait,
    });

    if (waitFor === 'selector') {
      if (!req.waitSelector) {
        const e = new Error('wait_selector_required');
        e.code = 'BAD_REQUEST';
        throw e;
      }
      await page.waitForSelector(req.waitSelector, {
        timeout: timeoutMs,
        state: 'attached',
      });
    }

    if (waitFor === 'text') {
      // SPA-кейс (widget.afisha.yandex.ru и подобные): React/Vue
      // дорисовывают DOM ПОСЛЕ networkidle, и обычный wait не помогает.
      // Ждём появления конкретной подстроки или regex'а в innerText.
      const needle = req.waitText;
      const needleRe = req.waitTextRegex;
      if (!needle && !needleRe) {
        const e = new Error('wait_text_or_regex_required');
        e.code = 'BAD_REQUEST';
        throw e;
      }
      await page.waitForFunction(
        ({ s, r }) => {
          const text = document.body ? document.body.innerText : '';
          if (s && text.includes(s)) return true;
          if (r && new RegExp(r).test(text)) return true;
          return false;
        },
        { s: needle || null, r: needleRe || null },
        { timeout: timeoutMs, polling: 250 },
      );
    }

    const html = await page.content();
    const finalUrl = page.url();
    const httpStatus = resp ? resp.status() : null;

    let outHtml = html;
    let truncated = false;
    if (html.length > config.maxHtmlBytes) {
      outHtml = html.slice(0, config.maxHtmlBytes);
      truncated = true;
    }

    return {
      status: 'ok',
      html: outHtml,
      html_bytes: html.length,
      truncated,
      final_url: finalUrl,
      http_status: httpStatus,
      took_ms: Date.now() - startedAt,
    };
  } catch (err) {
    const tookMs = Date.now() - startedAt;
    const msg = err?.message || String(err);
    if (/Timeout|timeout/.test(msg)) {
      const e = new Error(msg);
      e.code = 'TIMEOUT';
      e.took_ms = tookMs;
      throw e;
    }
    if (err.code === 'BAD_REQUEST') {
      err.took_ms = tookMs;
      throw err;
    }
    const e = new Error(msg);
    e.code = 'RENDER_FAILED';
    e.took_ms = tookMs;
    throw e;
  } finally {
    activeRenders -= 1;
    await context.close().catch(() => {});
  }
}
