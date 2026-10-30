#!/usr/bin/env python3
"""Охват афиши: какие события ближайшей недели есть у чужих афиш Воронежа, а на kudab.ru нет.

Чужие афиши — Яндекс Афиша, Афиша.ру, МТС Live, NearBee. Кино и квесты не считаем: их сеансы
мы не собираем. Запуск: python3 scripts/coverage_audit.py [--days 7] [--out notes/coverage]
"""
import argparse
import datetime as dt
import html
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36')
MSK = dt.timezone(dt.timedelta(hours=3))
KUDAB_API = 'https://kudab.ru/api/web/events'

YANDEX_RUBRICS = ['concert', 'theatre', 'theatre_show', 'art', 'kids', 'standup', 'show',
                  'festival', 'excursions', 'sport']
MTS_COLLECTIONS = ['concerts', 'theater', 'standup', 'show', 'children', 'exhibitions',
                   'musicals', 'spectacle', 'cultural']
YANDEX_SKIP = {'cinema', 'quest'}
AFISHA_RU_SKIP = {'movie', 'quest', 'cinema'}
NEARBEE_SKIP = {'cinema'}

# Слова, которые есть в названиях почти всех событий своего вида: по ним события не различить.
STOP = set('''
концерт концерта концертная концертный сольный большой большая спектакль спектакля шоу выставка
выставки фестиваль фестиваля программа премьера в во на и с со для по от до из к у о а the
воронеж воронеже воронежа г группа группы театр театра stand up standup стендап стендапа
мастер класс лекция экскурсия тур туре new год года вечер вечеринка 0 1 2 3 4 5 6 7 8 9 12 16 18
'''.split())

_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def get(url, timeout=40, tries=3):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ru'})
            with _opener.open(req, timeout=timeout) as r:
                return r.read().decode('utf-8', errors='replace')
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
            if e.code == 429:
                time.sleep(30)
        except Exception as e:  # noqa: BLE001 — сеть: повторяем, потом сдаёмся
            last = e
        time.sleep(2 + 3 * i)
    print(f'  ! не открылось: {url}: {last}', file=sys.stderr)
    return None


def tokens(title):
    t = html.unescape(title or '').lower().replace('ё', 'е')
    words = re.sub(r'[^\w\s]', ' ', t).split()
    keep = {w[:5] for w in words if w not in STOP and len(w) > 1 and not w.isdigit()}
    # «Стендап» или «22'07» целиком из общих слов и цифр — тогда сравниваем их как есть
    return keep or {w[:5] for w in words}


def similar(a, b):
    inter = a & b
    if not inter:
        return False
    return len(inter) / len(a | b) >= 0.5 or len(inter) == min(len(a), len(b))


def days_of(d0, n):
    return [d0 + dt.timedelta(days=i) for i in range(n)]


def link_key(u):
    u = re.sub(r'^https?://(www\.)?', '', (u or '').strip().lower())
    return u.split('?')[0].split('#')[0].rstrip('/')


def item(src, title, dates, venue='', url='', kind='', ticket=''):
    return {'src': src, 'title': html.unescape(title).strip(), 'dates': sorted(dates),
            'venue': html.unescape(venue or '').strip(), 'url': url, 'kind': kind,
            'links': [k for k in (link_key(url), link_key(ticket)) if k]}


# ---------- чужие афиши ----------

def yandex(days):
    """Карточки раздела по дням: на странице дня лежат события этого дня."""
    out = {}
    for rubric in YANDEX_RUBRICS:
        for d in days:
            iso = d.isoformat()
            page = get(f'https://afisha.yandex.ru/voronezh/{rubric}?date={iso}&period=1')
            time.sleep(1.5)
            if not page:
                continue
            for card in re.split(r'data-test-id="eventCard\.root"', page)[1:]:
                href = re.search(r'href="(/voronezh/([a-z_]+)/[a-z0-9-]+)', card)
                title = re.search(r'data-test-id="eventCard\.eventInfoTitle">([^<]+)<', card)
                # в детском разделе лежат и мультфильмы, и квесты — их рубрика видна по адресу
                if not href or not title or href.group(2) in YANDEX_SKIP:
                    continue
                details = re.search(r'data-test-id="eventCard\.eventInfoDetails">(.*?)</ul>', card, re.S)
                venue = ''
                if details:
                    v = re.findall(r'title="([^"]+)"', details.group(1))
                    venue = v[0] if v else ''
                url = 'https://afisha.yandex.ru' + href.group(1)
                rec = out.setdefault(url, item('yandex', title.group(1), [], venue, url, rubric))
                if iso not in rec['dates']:
                    rec['dates'] = sorted(rec['dates'] + [iso])
    return list(out.values())


def afisha_ru(days):
    """Отдельные дни Афиша.ру отдаёт только на сегодня и завтра, дальше уводит на общую страницу города,
    где спектакли других городов и других месяцев. Поэтому берём сегодня, завтра и выходные, прочие дни пропускаем."""
    today = dt.datetime.now(MSK).date()
    sat = today + dt.timedelta(days=(5 - today.weekday()) % 7)
    slugs = {sat: 'na-vyhodnye', sat + dt.timedelta(days=1): 'na-vyhodnye',
             today: 'na-segodnya', today + dt.timedelta(days=1): 'na-zavtra'}
    pages, out = {}, {}
    for d in days:
        slug = slugs.get(d)
        if not slug:
            continue
        if slug not in pages:
            pages[slug] = get(f'https://www.afisha.ru/voronezh/events/{slug}/')
            time.sleep(1.5)
        page = pages[slug]
        if not page or f'/voronezh/events/{slug}/"' not in (re.search(r'rel="canonical"[^>]*>', page) or [''])[0]:
            continue
        for m in re.finditer(r'<a\b[^>]*href="(/([a-z_]+)/[a-z0-9-]+-\d+/)(?:\?[^"]*)?"[^>]*>(.*?)</a>', page, re.S):
            path, kind, inner = m.group(1), m.group(2), m.group(3)
            if kind in AFISHA_RU_SKIP or kind in ('selection', 'restaurant', 'concerthall', 'club', 'museum'):
                continue
            text = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', inner))).strip()
            if not text or text.startswith('От ') or text in ('Билеты', 'Купить билет'):
                continue
            url = 'https://www.afisha.ru' + path
            rec = out.setdefault(url, item('afisha_ru', text, [], '', url, kind))
            if d.isoformat() not in rec['dates']:
                rec['dates'] = sorted(rec['dates'] + [d.isoformat()])
    return list(out.values())


def mts_live(days):
    want = {d.isoformat() for d in days}
    out = {}
    for c in MTS_COLLECTIONS:
        page = get(f'https://live.mts.ru/voronezh/collections/{c}')
        time.sleep(1.5)
        if not page:
            continue
        s = page.replace('\\"', '"')
        for m in re.finditer(r'\{"id":(\d+),"title":"([^"]+)","alias":"([^"]+)","url":"([^"]+)"', s):
            seg = s[m.end():m.end() + 1500]
            when = re.search(r'"eventClosestDateTime":"(\d{4}-\d\d-\d\d)', seg)
            venue = re.search(r'"venue":\{[^}]*?"title":"([^"]+)"', seg)
            if not when or when.group(1) not in want:
                continue
            url = 'https://live.mts.ru' + m.group(4).split('?')[0]
            key = url + '#' + when.group(1)
            out.setdefault(key, item('mts', m.group(2), [when.group(1)],
                                     venue.group(1) if venue else '', url, c))
    return list(out.values())


def nearbee(days):
    raw = get('https://api.nearbee.ru/events', timeout=90)
    if not raw:
        return []
    w0 = dt.datetime.combine(days[0], dt.time(0), MSK)
    w1 = dt.datetime.combine(days[-1] + dt.timedelta(days=1), dt.time(0), MSK)
    out = []
    for e in json.loads(raw):
        cats = {c.get('slug') for c in e.get('categories') or []}
        addr = e.get('address') or ''
        if cats & NEARBEE_SKIP or 'Москва' in addr:
            continue
        dates, times = set(), {}
        for s in e.get('sessions') or []:
            a = dt.datetime.fromisoformat(s['startDate'].replace('Z', '+00:00'))
            b = dt.datetime.fromisoformat((s.get('endDate') or s['startDate']).replace('Z', '+00:00'))
            # день без часа NearBee отдаёт до следующей полуночи, а она уже завтрашний день
            if b > a and b.astimezone(MSK).time() == dt.time(0):
                b -= dt.timedelta(seconds=1)
            if a >= w1 or b < w0:
                continue
            if a.astimezone(MSK).time() != dt.time(0) and b - a < dt.timedelta(days=1):
                times[a.astimezone(MSK).date().isoformat()] = a.astimezone(MSK).strftime('%H:%M')
            day = max(a, w0).astimezone(MSK).date()
            last = min(b, w1 - dt.timedelta(seconds=1)).astimezone(MSK).date()
            while day <= last:
                dates.add(day.isoformat())
                day += dt.timedelta(days=1)
        if dates:
            out.append(item('nearbee', e['title'], dates, addr, f"https://nearbee.ru/events/{e.get('slug', '')}",
                            ','.join(sorted(c for c in cats if c)), e.get('ticketUrl') or '') | {'times': times})
    return out


# ---------- kudab ----------

def kudab_week(days):
    """Все события недели с прода. Детское общая лента прячет, поэтому второй проход с kids=1."""
    seen = {}
    for kids in (None, '1'):
        page = 1
        while True:
            q = {'city': 'voronezh', 'date_from': days[0].isoformat(),
                 'date_to': days[-1].isoformat() + ' 23:59:59', 'per_page': 50, 'page': page}
            if kids:
                q['kids'] = kids
            raw = get(KUDAB_API + '?' + urllib.parse.urlencode(q))
            if not raw:
                break
            data = json.loads(raw)
            for e in data.get('data', []):
                seen[e['id']] = e
            if page >= (data.get('meta') or {}).get('last_page', 1):
                break
            page += 1
            time.sleep(0.3)
    return list(seen.values())


def kudab_day(e):
    return (e.get('start_date') or (e.get('start_at') or '')[:10]) or None


def kudab_search(ext):
    """Запасная проверка поиском сайта: названия у афиш пишут по-разному."""
    q = {'city': 'voronezh', 'q': ext['title'][:80], 'date_from': ext['dates'][0],
         'date_to': ext['dates'][-1] + ' 23:59:59', 'per_page': 20}
    found = []
    for kids in (None, '1'):
        if kids:
            q['kids'] = kids
        raw = get(KUDAB_API + '?' + urllib.parse.urlencode(q))
        time.sleep(1)
        if raw:
            found += json.loads(raw).get('data', [])
    want = tokens(ext['title'])
    for e in found:
        # одного общего слова мало: у концерта «Рок — это жизнь» и выставки «Дорога в вечную жизнь» оно есть
        if kudab_day(e) in ext['dates'] and similar(want, tokens(e.get('title'))):
            return e
    return None


STREET = r'(?:ул|пл|пр-кт|пр-д|пер|б-р|наб|ш|мкр|туп)'
SERVICE = {'для', 'или', 'как', 'это', 'что', 'при', 'под', 'про', 'без', 'над', 'the'}
STOP4 = {w[:4] for w in STOP}


STREET_WORDS = {'проспект': 'пр-кт', 'просп': 'пр-кт', 'улица': 'ул', 'площадь': 'пл', 'переулок': 'пер',
                'бульвар': 'б-р', 'набережная': 'наб', 'шоссе': 'ш', 'проезд': 'пр-д', 'микрорайон': 'мкр'}


def place_key(addr):
    """Улица и номер дома без буквы: «г Воронеж, ул Карла Маркса, д 67Б» → ('маркса', '67'). У нас бывает
    «Ленинский проспект, 174П», у NearBee «Ленинский пр-кт, д 174» — это один дом. None — адреса в строке нет."""
    a = (addr or '').lower().replace('ё', 'е')
    a = re.sub(r'\b(' + '|'.join(STREET_WORDS) + r')\b\.?', lambda m: STREET_WORDS[m.group(1)], a)
    m = re.search(rf'(?:^|,)\s*(?:{STREET}\.?\s+([^,]+?)|([^,]+?)\s+{STREET}\.?),\s*(?:(?:д|уч|зд|влд)\.?\s*)?'
                  r'(\d+)[а-я]?(?:/\d+[а-я]?)?\b', a)
    return ((m.group(1) or m.group(2)).split()[-1], m.group(3)) if m else None


def title_stems(title):
    """Слова названия по четырём первым буквам: «мафия» и «мафию» — одно слово. Общие слова вроде «стендап»
    не выбрасываются, см. `place_match`."""
    t = html.unescape(title or '').lower().replace('ё', 'е')
    return {w[:4] for w in re.sub(r'[^\w\s]', ' ', t).split()
            if len(w) >= 3 and not w.isdigit() and w not in SERVICE and not w.startswith('воронеж')}


def same_hour(x, e, day):
    """Начало расходится не больше чем на час. Если час не знает хоть одна сторона — не мешает."""
    t, at = (x.get('times') or {}).get(day), e.get('start_at') or ''
    if not t or e.get('time_precision') != 'datetime' or len(at) < 16:
        return True
    return abs(int(t[:2]) * 60 + int(t[3:5]) - int(at[11:13]) * 60 - int(at[14:16])) <= 60


def place_match(x, e, day):
    """Событие в том же доме в тот же день. Общего слова вроде «концерт» мало: в библиотеке бывает три концерта
    за день, тогда сверяется и час. Особому слову, как «Ваш Бэнд», час не нужен: афиши пишут то сбор, то начало."""
    common = title_stems(x['title']) & title_stems(e.get('title'))
    return bool(common - STOP4) or (bool(common) and same_hour(x, e, day))


def match_all(ext_items, kudab):
    by_day, by_link, by_place = {}, {}, {}
    for e in kudab:
        by_day.setdefault(kudab_day(e), []).append((tokens(e.get('title')), e))
        for u in (e.get('external_url'), e.get('price_url')):
            if link_key(u):
                by_link[link_key(u)] = e
        if place_key(e.get('address')):
            by_place.setdefault((place_key(e.get('address')), kudab_day(e)), []).append(e)
    for x in ext_items:
        want = tokens(x['title'])
        x['match'] = None
        # одна и та же страница кассы надёжнее названия: афиши называют концерт по-разному
        e = next((by_link[k] for k in x.get('links', [link_key(x['url'])]) if k in by_link), None)
        if e:
            x['match'] = {'id': e['id'], 'title': e.get('title'), 'how': 'ссылка'}
            continue
        for d in x['dates']:
            for tok, e in by_day.get(d, []):
                if want and similar(want, tok):
                    x['match'] = {'id': e['id'], 'title': e.get('title'), 'how': 'название'}
                    break
            if x['match']:
                break
        place = place_key(x['venue'])
        if not x['match'] and place:
            # «Стендап-шоу в кафе «ПАРНАС 2.0»» и наш «Большой стендап-концерт» там же — одно событие
            e = next((e for d in x['dates'] for e in by_place.get((place, d), []) if place_match(x, e, d)), None)
            if e:
                x['match'] = {'id': e['id'], 'title': e.get('title'), 'how': 'место'}
        if not x['match']:
            e = kudab_search(x)
            if e:
                x['match'] = {'id': e['id'], 'title': e.get('title'), 'how': 'поиск'}


def union(items):
    """Одно событие у нескольких афиш считаем один раз."""
    groups = []
    for x in items:
        tok = tokens(x['title'])
        for g in groups:
            if set(g['dates']) & set(x['dates']) and tok and similar(tok, g['tok']):
                g['srcs'].add(x['src'])
                g['items'].append(x)
                break
        else:
            groups.append({'tok': tok, 'dates': list(x['dates']), 'srcs': {x['src']}, 'items': [x]})
    return groups


def report(days, ext_items, groups, kudab, out_dir):
    names = {'yandex': 'Яндекс Афиша', 'afisha_ru': 'Афиша.ру', 'mts': 'МТС Live', 'nearbee': 'NearBee'}
    covered = [g for g in groups if any(i['match'] for i in g['items'])]
    pct = lambda a, b: f'{(100 * a / b):.0f}%' if b else '—'
    lines = [f'# Охват афиши {days[0]:%d.%m}–{days[-1]:%d.%m.%Y}', '',
             f'Событий у чужих афиш: {len(groups)}, на kudab есть {len(covered)} — {pct(len(covered), len(groups))}.',
             f'Событий на kudab за эти дни всего: {len(kudab)}.',
             'Найдены по ссылке на кассу, по названию в тот же день, по дому и общему слову или поиском сайта; '
             'пропуски стоит проверить глазами — афиши называют одно событие по-разному.',
             '', '## По источникам', '']
    for src in names:
        mine = [i for i in ext_items if i['src'] == src]
        hit = [i for i in mine if i['match']]
        lines.append(f'- {names[src]}: {len(hit)} из {len(mine)} ({pct(len(hit), len(mine))})')
    misses = [g for g in groups if not any(i['match'] for i in g['items'])]
    by_venue = {}
    for g in misses:
        v = next((i['venue'] for i in g['items'] if i['venue']), '') or '(площадка не указана)'
        by_venue.setdefault(v, []).append(g)
    lines += ['', f'## Нет на kudab: {len(misses)}', '']
    for v, gs in sorted(by_venue.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        lines.append(f'**{v}** — {len(gs)}')
        for g in gs:
            i = g['items'][0]
            ds = ', '.join(dt.date.fromisoformat(d).strftime('%d.%m') for d in g['dates'][:3])
            more = '…' if len(g['dates']) > 3 else ''
            lines.append(f"- {i['title']} — {ds}{more} — {', '.join(names[s] for s in sorted(g['srcs']))} — {i['url']}")
        lines.append('')
    text = '\n'.join(lines)
    os.makedirs(out_dir, exist_ok=True)
    stem = os.path.join(out_dir, days[0].isoformat())
    with open(stem + '.md', 'w', encoding='utf-8') as f:
        f.write(text + '\n')
    with open(stem + '.json', 'w', encoding='utf-8') as f:
        json.dump({'days': [d.isoformat() for d in days], 'items': ext_items, 'kudab_total': len(kudab),
                   'groups': len(groups), 'covered': len(covered)}, f, ensure_ascii=False, indent=1)
    return text, stem


def counts(x):
    """Экскурсии по записи — не событие с датой, их на сайте и не должно быть."""
    return 'индивидуальн' not in x['title'].lower()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--days', type=int, default=7)
    ap.add_argument('--start', help='первый день, ГГГГ-ММ-ДД; по умолчанию сегодня по Москве')
    ap.add_argument('--out', default='notes/coverage')
    ap.add_argument('--from-json', help='взять чужие афиши из прошлого отчёта и только пересверить')
    args = ap.parse_args()
    d0 = dt.date.fromisoformat(args.start) if args.start else dt.datetime.now(MSK).date()
    days = days_of(d0, args.days)
    print('kudab…', file=sys.stderr)
    kudab = kudab_week(days)
    ext = []
    if args.from_json:
        with open(args.from_json, encoding='utf-8') as f:
            ext = json.load(f)['items']
        ext = [x for x in ext if not (x['src'] == 'yandex' and x['url'].split('/')[4] in YANDEX_SKIP)]
    else:
        for name, fn in (('Яндекс Афиша', yandex), ('Афиша.ру', afisha_ru), ('МТС Live', mts_live), ('NearBee', nearbee)):
            print(f'{name}…', file=sys.stderr)
            got = fn(days)
            print(f'  {len(got)}', file=sys.stderr)
            ext += got
    ext = [x for x in ext if counts(x)]
    print('сверка…', file=sys.stderr)
    match_all(ext, kudab)
    groups = union(ext)
    text, stem = report(days, ext, groups, kudab, args.out)
    print(text)
    print(f'\nотчёт: {stem}.md', file=sys.stderr)


if __name__ == '__main__':
    main()
