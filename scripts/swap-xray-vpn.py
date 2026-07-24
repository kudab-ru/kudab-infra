#!/usr/bin/env python3
"""
Подмена/подбор VLESS-outbound в /usr/local/etc/xray/config.json по подписке.

Режимы (нужен sudo — конфиг root + systemctl):
  # авто-подбор: перебрать все серверы подписки, оставить ПЕРВЫЙ рабочий
  sudo python3 scripts/swap-xray-vpn.py '<sub-url>' --auto

  # конкретный сервер по индексу (без интерактива)
  sudo python3 scripts/swap-xray-vpn.py '<sub-url>' --index 13

  # интерактивный выбор
  sudo python3 scripts/swap-xray-vpn.py '<sub-url>'

Что делает: забирает подписку → парсит vless://-конфиги → заменяет ТОЛЬКО
outbound protocol=vless (тег сохраняет), остальное не трогает → бэкап рядом
(config.json.bak-swap). В --auto ещё сам делает `systemctl restart xray` и
пробивает прокси через 127.0.0.1:1081 к целевому сайту (по умолчанию Яндекс.Афиша).
Секреты не логируются (только host:port).
"""
import sys, json, base64, re, urllib.parse, urllib.request, shutil, os, subprocess

CONFIG = "/usr/local/etc/xray/config.json"
PROBE_URL = "https://afisha.yandex.ru/"
SOCKS = "127.0.0.1:1081"

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
        raise ValueError("не распарсил vless-URI")
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
    user = {"id": p["id"], "encryption": "none"}
    if p["flow"]:
        user["flow"] = p["flow"]
    ss = {"network": p["network"], "security": p["security"]}
    if p["security"] == "reality":
        ss["realitySettings"] = {"serverName": p["sni"], "fingerprint": p["fp"],
                                 "publicKey": p["pbk"], "shortId": p["sid"], "spiderX": p["spx"] or "/"}
    elif p["security"] in ("tls", "xtls"):
        tls = {"serverName": p["sni"], "fingerprint": p["fp"]}
        if p["alpn"]:
            tls["alpn"] = p["alpn"].split(",")
        ss["tlsSettings"] = tls
    return {"protocol": "vless", "tag": tag,
            "settings": {"vnext": [{"address": p["address"], "port": p["port"], "users": [user]}]},
            "streamSettings": ss}

def write_config(chosen):
    cfg = json.load(open(CONFIG, encoding="utf-8"))
    obs = cfg.get("outbounds", [])
    vless_idx = next((i for i, o in enumerate(obs) if o.get("protocol") == "vless"), None)
    tag = obs[vless_idx].get("tag", "vless-reality") if vless_idx is not None else "vless-reality"
    new_ob = build_outbound(chosen, tag)
    if vless_idx is not None:
        obs[vless_idx] = new_ob
    else:
        obs.insert(0, new_ob)
    cfg["outbounds"] = obs
    tmp = CONFIG + ".new"
    json.dump(cfg, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    os.replace(tmp, CONFIG)

def probe():
    try:
        r = subprocess.run(["curl", "--socks5-hostname", SOCKS, "-m", "8", "-o", "/dev/null",
                            "-s", "-w", "%{http_code}", PROBE_URL], capture_output=True, text=True, timeout=15)
        return r.stdout.strip()
    except Exception:
        return "000"

def restart_xray():
    subprocess.run(["systemctl", "restart", "xray"], check=False)
    subprocess.run(["sleep", "1.5"], check=False)

def main():
    args = sys.argv[1:]
    if not args:
        print("usage: sudo python3 swap-xray-vpn.py <sub-url> [--auto | --index N]"); sys.exit(1)
    url = args[0]
    mode = "interactive"
    index = 0
    if "--auto" in args:
        mode = "auto"
    elif "--index" in args:
        mode = "index"; index = int(args[args.index("--index") + 1])

    uris = fetch_sub(url)
    if not uris:
        print("В подписке нет vless-конфигов."); sys.exit(2)
    parsed = []
    for u in uris:
        try:
            parsed.append(parse_vless(u))
        except Exception:
            pass
    print(f"Серверов в подписке: {len(parsed)}")
    for i, p in enumerate(parsed):
        print(f"  #{i}: {p['address']}:{p['port']} security={p['security']} flow={p['flow'] or '-'} sni={p['sni']} [{p['name']}]")

    shutil.copy(CONFIG, CONFIG + ".bak-swap")

    if mode == "auto":
        print("\n--auto: перебираю серверы (restart+probe), беру первый рабочий…")
        for i, p in enumerate(parsed):
            write_config(p); restart_xray(); code = probe()
            ok = code not in ("000", "")
            print(f"  #{i:>2} {p['address']}:{p['port']:<5} [{p['name'][:22]}] → HTTP={code} {'✅' if ok else '✗'}")
            if ok:
                print(f"\n✅ Рабочий сервер: #{i} {p['address']}:{p['port']} (HTTP={code}). Конфиг записан, xray перезапущен.")
                print("Проверь ещё раз вручную при желании:")
                print(f"  curl --socks5-hostname {SOCKS} -m10 -o/dev/null -w 'proxy=%{{http_code}}\\n' {PROBE_URL}")
                return
        print("\n❌ Ни один сервер не пробился. Возможно, проблема шире (провайдер/сеть). Восстанови бэкап: cp "
              + CONFIG + ".bak-swap " + CONFIG)
        return

    if mode == "interactive":
        try:
            index = int(input(f"Какой использовать? [0-{len(parsed)-1}, default 0]: ") or "0")
        except (EOFError, ValueError):
            index = 0
    chosen = parsed[index]
    write_config(chosen)
    print(f"\n✅ Записан outbound → {chosen['address']}:{chosen['port']} [{chosen['name']}] (бэкап: {CONFIG}.bak-swap)")
    print("Дальше:\n  sudo systemctl restart xray")
    print(f"  curl --socks5-hostname {SOCKS} -m10 -o/dev/null -w 'proxy=%{{http_code}}\\n' {PROBE_URL}")

if __name__ == "__main__":
    main()
