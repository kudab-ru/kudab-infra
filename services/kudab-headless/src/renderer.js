import { chromium } from 'playwright';
import { config } from './config.js';

let browserPromise = null;
let activeRenders = 0;

async function getBrowser() {
  if (!browserPromise) {
    browserPromise = chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-blink-features=AutomationControlled',
      ],
    });
  }
  return browserPromise;
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
    const navWait = waitFor === 'selector' ? 'load' : waitFor;
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
