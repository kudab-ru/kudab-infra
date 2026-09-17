export const config = {
  port: parseInt(process.env.PORT || '8080', 10),

  // Hard cap regardless of client request
  maxTimeoutMs: parseInt(process.env.MAX_TIMEOUT_MS || '30000', 10),
  defaultTimeoutMs: parseInt(process.env.DEFAULT_TIMEOUT_MS || '15000', 10),

  // Parallel renders in this process
  maxConcurrentRenders: parseInt(process.env.MAX_CONCURRENT_RENDERS || '3', 10),

  // Truncate HTML response above this size
  maxHtmlBytes: parseInt(process.env.MAX_HTML_BYTES || (5 * 1024 * 1024).toString(), 10),

  defaultUserAgent:
    process.env.DEFAULT_USER_AGENT ||
    'Mozilla/5.0 (compatible; KudabBot/1.0; +https://kudab.ru/bot)',

  // Domains we never render (mirror of kudab-parser ExternalLinkFetcher blocklist).
  // These either have native collectors (vk/tg) or nothing useful for pricing.
  hostBlocklist: new Set([
    't.me',
    'telegram.me',
    'telegram.org',
    'vk.com',
    'vk.ru',
    'm.vk.com',
    'youtube.com',
    'youtu.be',
    'instagram.com',
    'facebook.com',
    'twitter.com',
    'x.com',
  ]),

  // Счётчик Метрики, который мы НИКОГДА не должны вызывать из браузера.
  //
  // 17.09.2026 обход kudab.ru через headless дал 211 визитов за день при
  // обычных 30: в отчёте это выглядело как всплеск прямого трафика, и
  // удалить его из Метрики уже нельзя — она не переписывает историю.
  // Блокировка на уровне запроса дешевле любого фильтра в кабинете:
  // хит не уходит вовсе, а не чистится потом сегментом.
  //
  // Сравнение по суффиксу хоста: mc.yandex.ru, mc.yandex.com и их поддомены.
  analyticsHostSuffixes: ['mc.yandex.ru', 'mc.yandex.com'],

  // Only http/https. file://, data://, javascript:, etc. are rejected.
  allowedSchemes: new Set(['http:', 'https:']),
};
