#!/usr/bin/env python3
"""
Генератор xray-конфига с авто-failover: balancer + observatory поверх ВСЕХ
рабочих серверов подписки. Переиспользует парсер vless из swap-xray-vpn.py.

Идея: вместо одного vless-outbound (единая точка отказа) — пул outbound'ов
proxy-0..proxy-N, observatory постоянно пингует их через probeUrl (Telegram),
balancer (leastPing) шлёт трафик inbound'ов на самый живой/быстрый сервер.
Смерть одного сервера → observatory видит рост пинга/недоступность → balancer
уводит трафик на следующий живой. Telegram (бот+алерты) не падает.

БЕЗ ROOT: только читает текущий конфиг (сохранить inbounds/log/direct/block) и
ПИШЕТ НОВЫЙ файл (--out). Живой конфиг не трогает. Применение — оператор (sudo).

Пул: берём только net=tcp reality/tls серверы (та же проверенная форма, что и
текущий рабочий outbound). grpc/xhttp/прочую экзотику ПРОПУСКАЕМ (нужны доп.
streamSettings — риск сломать; observatory всё равно увёл бы от них, но не хотим
малейшего шанса невалидного outbound). Дедуп по (address,port,id,pbk,sid,sni,flow).

Usage:
  python3 scripts/gen-xray-balancer.py --sub-file <file-with-url> \
      --base /usr/local/etc/xray/config.json --out /path/config.balancer.json
  # или --sub-url '<url>' (не рекомендуется — светит секрет в ps/истории)

Секреты (id/pbk) в stdout маскируются. Валидируй результат: xray -test -config <out>.
"""
import sys, json, base64, re, urllib.parse, urllib.request, argparse

PROBE_URL = "https://api.telegram.org/"
# classic `observatory` probes ALL servers immediately + CONCURRENTLY on start →
# health ready in ~1 RTT (~300ms) → CLEAN cold-start (no Telegram drop after an
# xray restart). Validated 2026-07-24 (unprivileged 2nd xray on alt ports):
#   * burstObservatory had a first-cycle transient 000 (~3s) after EVERY restart
#     — that was the operator's apply incident; classic observatory = 0 drop.
#   * fallbackTag=proxy-0 proven to route even with ZERO healthy data (covers the
#     sub-second pre-first-probe gap).
# probeInterval also bounds the failover-detection window on a real server death
# (residual ≤~interval blip is inherent to health-check LB — no per-request retry
# in xray — and is still far better than the single-outbound total-outage today).
#
# 2026-07-24 bumped 5s→60s to cut round-the-clock probe traffic THROUGH the VPN.
# Каждый пробинг = TLS+GET к api.telegram.org сквозь тоннель (~5КБ). 5s×12 серверов
# ≈ 1 ГБ/сутки — избыточно для бота (не latency-critical, есть ретраи + keep-alive).
# 60s: failover-детект ≤60с на РЕДКОЙ смерти сервера (приемлемо), трафик ~в 12 раз
# меньше. Хочешь быстрее failover — 30s (компромисс, вдвое больше трафика).
PROBE_INTERVAL = "60s"
BAL_TAG = "tg-bal"
# leastLoad(maxRTT) drops a server whose fresh probe fails (dead → no RTT).
MAX_RTT = "3s"
# Метрируемые серверы подписки (множитель трафика в имени: «(x5 трафик)»,
# «x10 traffic») — исключаем из failover-пула: их постоянно пингует observatory,
# а квота у них множится (x5/x10). Оставляем flat-rate. Точечный single-mode их
# НЕ фильтрует (оператор выбрал сервер явно, пингуется только он).
METERED_RE = re.compile(r"x\d+\s*(?:трафик|traffic)", re.IGNORECASE)


def fetch_sub(url):
    req = urllib.request.Request(url, headers={"User-Agent": "xray-swap/1.0"})
    raw = urllib.request.urlopen(req, timeout=25).read().decode("utf-8", "replace").strip()
    if "vless://" not in raw:
        try:
            raw = base64.b64decode(raw + "===").decode("utf-8", "replace")
        except Exception:
            pass
    return [l.strip() for l in re.split(r"\s+", raw) if l.strip().startswith("vless://")]


def parse_vless(uri):
    m = re.match(r"vless://([^@]+)@([^:/?#]+):(\d+)\??([^#]*)#?(.*)", uri)
    if not m:
        raise ValueError("no parse")
    uid, host, port, query, name = m.groups()
    q = dict(urllib.parse.parse_qsl(query))
    return {
        "id": uid, "address": host, "port": int(port),
        "name": urllib.parse.unquote(name),
        "security": q.get("security", "reality"),
        "network": q.get("type", "tcp"),
        "flow": q.get("flow", ""),
        "sni": q.get("sni") or q.get("peer") or "",
        "fp": q.get("fp", "chrome"),
        "pbk": q.get("pbk", ""), "sid": q.get("sid", ""),
        "spx": q.get("spx", ""), "alpn": q.get("alpn", ""),
    }


def build_outbound(p, tag):
    """Совместимо с swap-xray-vpn.py build_outbound, но с тегом proxy-N."""
    user = {"id": p["id"], "encryption": "none"}
    if p["flow"]:
        user["flow"] = p["flow"]
    ss = {"network": p["network"], "security": p["security"]}
    if p["security"] == "reality":
        ss["realitySettings"] = {"serverName": p["sni"], "fingerprint": p["fp"],
                                 "publicKey": p["pbk"], "shortId": p["sid"],
                                 "spiderX": p["spx"] or "/"}
    elif p["security"] in ("tls", "xtls"):
        tls = {"serverName": p["sni"], "fingerprint": p["fp"]}
        if p["alpn"]:
            tls["alpn"] = p["alpn"].split(",")
        ss["tlsSettings"] = tls
    return {"protocol": "vless", "tag": tag,
            "settings": {"vnext": [{"address": p["address"], "port": p["port"], "users": [user]}]},
            "streamSettings": ss}


def current_active_key(base_cfg):
    """(address,port) текущего живого vless-outbound — чтобы поставить его proxy-0
    (безопасный fallback на холодном старте до первого пробинга observatory)."""
    for o in base_cfg.get("outbounds", []):
        if o.get("protocol") == "vless":
            vn = o.get("settings", {}).get("vnext", [{}])[0]
            return (vn.get("address"), vn.get("port"))
    return None


def mask(s):
    return (s[:4] + "…" + s[-2:]) if s and len(s) > 8 else "***"


def _dedup(servers):
    """Убрать повторы по полному reality-кортежу (одинаковые сервер+ключи)."""
    seen, uniq = set(), []
    for p in servers:
        k = (p["address"], p["port"], p["id"], p["pbk"], p["sid"], p["sni"], p["flow"])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(p)
    return uniq


def build_balancer_config(sub_url, base_cfg, only_index=None):
    """Ядро генератора (переиспользуется в 2b). Возвращает (cfg_dict, meta).

    only_index (mode=single, 2b): взять РОВНО один сервер по индексу в подписке
    (в исходном порядке parse). Балансер/observatory сохраняются (пул из 1) —
    так же валидируется xray -test и переживает будущий возврат в failover."""
    uris = fetch_sub(sub_url)
    parsed = []
    for u in uris:
        try:
            parsed.append(parse_vless(u))
        except Exception:
            pass

    def supported(p):
        return p["network"] == "tcp" and p["security"] in ("reality", "tls", "xtls")

    if only_index is not None:
        if only_index < 0 or only_index >= len(parsed):
            raise SystemExit(f"only_index={only_index} вне диапазона (серверов: {len(parsed)}).")
        chosen = parsed[only_index]
        if not supported(chosen):
            raise SystemExit(f"Сервер #{only_index} не поддержан (net={chosen['network']} sec={chosen['security']}).")
        proxy_obs = [build_outbound(chosen, "proxy-0")]
        cfg = _assemble(base_cfg, proxy_obs)
        meta = {"pool": [chosen], "skipped": [], "in_tags": cfg["_in_tags"], "active_key": None}
        del cfg["_in_tags"]
        return cfg, meta

    # только проверенная форма net=tcp (reality/tls); экзотику пропускаем.
    # Метрируемые (x5/x10 трафик) откладываем — исключим из пула, если flat хватает.
    flat, metered, skipped = [], [], []
    for p in parsed:
        if not supported(p):
            skipped.append((p, f"экзотика: net={p['network']} sec={p['security']}"))
            continue
        if METERED_RE.search(p.get("name", "")):
            metered.append(p)
            continue
        flat.append(p)

    # БЕЗОПАСНОСТЬ failover: если flat-серверов (после дедупа) <2 — возвращаем
    # метрируемые в пул (лучше жечь квоту, чем остаться без резерва).
    if len(_dedup(flat)) >= 2:
        pool = _dedup(flat)
        for p in metered:
            skipped.append((p, "метрируемый (множитель трафика в имени) — вне failover-пула"))
    else:
        # flat недостаточно — оставляем метрируемые ради резерва (в пуле, не в skipped)
        pool = _dedup(flat + metered)

    # current active → proxy-0 (cold-start fallback)
    ak = current_active_key(base_cfg)
    if ak:
        pool.sort(key=lambda p: 0 if (p["address"], p["port"]) == ak else 1)

    if not pool:
        raise SystemExit("Пул пуст — подписка не дала валидных reality/tls tcp серверов.")

    proxy_obs = [build_outbound(p, f"proxy-{i}") for i, p in enumerate(pool)]
    cfg = _assemble(base_cfg, proxy_obs)
    meta = {"pool": pool, "skipped": skipped, "in_tags": cfg["_in_tags"], "active_key": ak}
    del cfg["_in_tags"]
    return cfg, meta


def _assemble(base_cfg, proxy_obs):
    """Собрать xray-конфиг: сохранить inbounds/log/geoip-правила из base,
    пересобрать outbounds (proxy-* + direct + block) + observatory + balancer.
    Идемпотентно по routing (выкидывает старые правила на наш balancer)."""
    cfg = {}
    cfg["log"] = base_cfg.get("log", {"loglevel": "warning"})
    cfg["inbounds"] = base_cfg["inbounds"]
    cfg["outbounds"] = proxy_obs + [
        {"tag": "direct", "protocol": "freedom"},
        {"tag": "block", "protocol": "blackhole"},
    ]
    cfg["observatory"] = {
        "subjectSelector": ["proxy-"],
        "probeUrl": PROBE_URL,
        "probeInterval": PROBE_INTERVAL,
        "enableConcurrency": True,
    }
    # локальный gRPC api (127.0.0.1:10085) — для applier'а 2b: `xray api bi tg-bal`
    # отдаёт активный/eligible серверы балансера (статус для админки). Только
    # localhost, наружу не торчит.
    cfg["api"] = {
        "tag": "api",
        "listen": "127.0.0.1:10085",
        "services": ["HandlerService", "StatsService", "ObservatoryService", "RoutingService"],
    }
    base_routing = base_cfg.get("routing", {})
    in_tags = [ib.get("tag") for ib in cfg["inbounds"] if ib.get("tag")]
    rules = [r for r in base_routing.get("rules", []) if r.get("balancerTag") != BAL_TAG]
    rules.append({"type": "field", "inboundTag": in_tags, "balancerTag": BAL_TAG})
    cfg["routing"] = {
        "domainStrategy": base_routing.get("domainStrategy", "AsIs"),
        "balancers": [{
            "tag": BAL_TAG,
            "selector": ["proxy-"],
            "strategy": {"type": "leastLoad", "settings": {
                "baselines": ["300ms", "600ms"],
                "expected": 1,
                "maxRTT": MAX_RTT,
            }},
            "fallbackTag": "proxy-0",
        }],
        "rules": rules,
    }
    cfg["_in_tags"] = in_tags
    return cfg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sub-url")
    ap.add_argument("--sub-file")
    ap.add_argument("--base", default="/usr/local/etc/xray/config.json")
    ap.add_argument("--out", required=True)
    ap.add_argument("--only-index", type=int, default=None,
                    help="mode=single: взять ровно один сервер по индексу в подписке")
    a = ap.parse_args()
    if not (a.sub_url or a.sub_file):
        ap.error("нужен --sub-url или --sub-file")
    sub_url = a.sub_url or open(a.sub_file).read().strip()

    base_cfg = json.load(open(a.base, encoding="utf-8"))
    cfg, meta = build_balancer_config(sub_url, base_cfg, only_index=a.only_index)

    json.dump(cfg, open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    print(f"Базовый конфиг: {a.base}")
    print(f"Inbounds сохранены: {meta['in_tags']}")
    print(f"Пул балансера ({len(meta['pool'])} серверов, proxy-0..proxy-{len(meta['pool'])-1}):")
    for i, p in enumerate(meta["pool"]):
        act = "  ⟵ current-active (proxy-0 fallback)" if (p["address"], p["port"]) == meta["active_key"] and i == 0 else ""
        print(f"  proxy-{i:<2} {p['address']}:{p['port']} sec={p['security']} flow={p['flow'] or '-'} "
              f"sni={p['sni']} pbk={mask(p['pbk'])} sid={p['sid']} id={mask(p['id'])} [{p['name'][:20]}]{act}")
    if meta["skipped"]:
        print(f"Пропущено (экзотика, вне пула): {len(meta['skipped'])}")
        for p, why in meta["skipped"]:
            print(f"  - {p['address']}:{p['port']} ({why}) [{p['name'][:20]}]")
    print(f"\nЗаписан новый конфиг → {a.out}")
    print(f"observatory.probeUrl={PROBE_URL} probeInterval={PROBE_INTERVAL} concurrent; "
          f"balancer={BAL_TAG} strategy=leastLoad(maxRTT={MAX_RTT},expected=1) fallback=proxy-0")
    print(f"ВАЛИДИРУЙ: xray -test -config {a.out}")


if __name__ == "__main__":
    main()
