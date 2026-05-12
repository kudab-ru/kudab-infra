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

  // Only http/https. file://, data://, javascript:, etc. are rejected.
  allowedSchemes: new Set(['http:', 'https:']),
};
