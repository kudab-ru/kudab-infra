#!/usr/bin/env python3
"""Сторож комментариев kudab: не пускает в код раздутые комментарии.

Хук PreToolUse на Edit|Write|MultiEdit смотрит только на добавленные строки.
--scan <пути> ищет нарушения в уже написанном. Выключить: KUDAB_COMMENT_GUARD=off.
"""
import difflib
import json
import os
import re
import subprocess
import sys

ROOT = '/home/maks/projects/kudab-infra/'
LINE_MAX = 2        # строк у обычного комментария
DOC_MAX = 4         # строк у докблока, без @-тегов
LINE_CHARS = 220    # текста у обычного комментария
DOC_CHARS = 360     # текста у докблока

CODE_EXT = {'.php', '.ts', '.tsx', '.js', '.mjs', '.cjs', '.vue', '.scss', '.css', '.py', '.sh', '.yml', '.yaml'}
HASH_EXT = {'.py', '.sh', '.yml', '.yaml'}
SKIP_PARTS = ('/vendor/', '/node_modules/', '/.nuxt/', '/.output/', '/dist/', '/storage/',
              '/resources/views/', '/tests/Fixtures/', '/tmp/', '/notes/', '/docs/', '/.claude/', '/.git/')

TAG_RE = re.compile(
    r'^@(param|return|var|throws|template|property|method|phpstan|psalm|extends|implements|mixin|'
    r'use|type|typedef|OA\\|noinspection|deprecated|internal|see|link|covers|dataProvider|test|group)\b'
    r'|^(eslint|prettier|@ts-|phpcs|noqa|type:|pylint|fmt:|istanbul|c8 )'
)
BANNER_RE = re.compile(r'[-=*#/~_|─━═ ]+')

OPERATORS = {'НЕ', 'НИ', 'ДО', 'ПОСЛЕ', 'ТОЛЬКО', 'БЕЗ', 'ИЛИ', 'И'}
ABBR = {'ФИАС', 'КЛАДР', 'ОКТМО', 'СНИЛС', 'ОГРН', 'ЕГРЮЛ', 'ЕГРИП', 'ГИБДД', 'ТАСС', 'ВДНХ', 'ГОСТ',
        'СССР', 'ФГУП', 'РАН', 'ЦУМ', 'ГУМ', 'ОДИ', 'УФАС'}
VOWELS = set('АЕЁИОУЫЭЮЯ')
QUOTED_RE = re.compile(r'«[^»]*»|"[^"]*"|`[^`]*`|“[^”]*”|\'[^\']*\'')

MARKERS = [
    (re.compile(r'(?<![\d.])(?:[0-2]?\d|3[01])\.(?:0[1-9]|1[0-2])\.(?:20)?\d\d(?![\d.])|\b20[12]\d-[01]\d-[0-3]\d\b'),
     'дата'),
    (re.compile(r'\[\[[^\]\n]+\]\]'), 'вики-ссылка [[…]]'),
    (re.compile(r'замер(?!з)|\b\d+\s+из\s+\d+\b', re.I), 'замер'),
    (re.compile(r'решени\w* владельц|просьб\w* владельц|владел\w+ (?:решил|захотел|попросил|сказал|одобрил|'
                r'подтвердил|просил|выбрал|хочет|против)', re.I), 'кто решил'),
    (re.compile(r'\bPR-?\d|§\s?\d|\bTASKS\.md|\bNEXT\.md|\b[Сс]есси[яи] \d\b|\bфаз[аеыу] \d'), 'метка задачи или сессии'),
    (re.compile(r'(?:^|[.!?]\s+)Раньше\b(?!,? чем)|\b(?:[Зз]десь|[Тт]ут) (?:стоял|был|жил|лежал)|\b[Дд]о (?:этой )?правки\b|\b[Ии]сторически\b'),
     'история правки'),
    (re.compile(r'\bчестн\w*|\bнамеренно\b|\bосознанно\b|\bсознательно\b|\bпринципиально\b|\bровно\b|\bименно\b', re.I),
     'слово-нажим'),
    (re.compile(r'углами\b|адверсари|ревью наш', re.I), 'след процесса'),
    (re.compile(r'[─━═]{3,}'), 'рамка из псевдографики'),
]


def caps_hit(body):
    text = QUOTED_RE.sub(' ', body)
    words = re.findall(r'(?<![\w-])[А-ЯЁ]{2,}(?![\w-])', text)
    if not words:
        return None

    def abbr_like(w):
        if w in ABBR:
            return True
        vow = sum(ch in VOWELS for ch in w)
        return len(w) <= 5 and vow / len(w) < 0.4

    for m in re.finditer(r'(?<![\w-])[А-ЯЁ]{2,}(?:\s+[А-ЯЁ]{2,})+(?![\w-])', text):
        ws = m.group(0).split()
        if not all(abbr_like(w) or w in OPERATORS for w in ws):
            return m.group(0)
    for w in words:
        if w in OPERATORS or abbr_like(w):
            continue
        if len(w) >= 4:
            return w
    return None


def comment_lines(text, ext):
    """На каждую строку: (вид, текст) для комментария или None для кода. Вид: line | doc."""
    out = []
    state = None  # block | doc | html | pydoc
    prev_code = ''
    for raw in text.split('\n'):
        s = raw.strip()
        item = None
        if state in ('block', 'doc'):
            body = s
            if '*/' in s:
                body = s.split('*/')[0]
                kind = state
                state = None
            else:
                kind = state
            item = (kind, re.sub(r'^\*+\s?', '', body).strip())
        elif state == 'html':
            body = s
            if '-->' in s:
                body = s.split('-->')[0]
                state = None
            item = ('doc', body.strip())
        elif state == 'pydoc':
            body = s
            if '"""' in s or "'''" in s:
                body = re.split(r'"""|\'\'\'', s)[0]
                state = None
            item = ('doc', body.strip())
        elif ext in HASH_EXT:
            if s.startswith('#') and not s.startswith('#!'):
                item = ('line', s.lstrip('#').strip())
            elif ext == '.py' and s[:3] in ('"""', "'''") and (
                    re.match(r'(async\s+)?(def|class)\b.*:$', prev_code) or prev_code == ''):
                q, rest = s[:3], s[3:]
                if q in rest:
                    item = ('doc', rest.split(q)[0].strip())
                else:
                    state = 'pydoc'
                    item = ('doc', rest.strip())
        else:
            if s.startswith('//'):
                item = ('line', s.lstrip('/').strip())
            elif s.startswith('/*'):
                kind = 'doc' if s.startswith('/**') else 'block'
                rest = s[2:].lstrip('*')
                if '*/' in rest:
                    item = (kind, rest.split('*/')[0].strip())
                else:
                    state = kind
                    item = (kind, rest.strip())
            elif s.startswith('<!--'):
                rest = s[4:]
                if '-->' in rest:
                    item = ('doc', rest.split('-->')[0].strip())
                else:
                    state = 'html'
                    item = ('doc', rest.strip())
            elif ext == '.php' and s.startswith('#') and not s.startswith('#['):
                item = ('line', s.lstrip('#').strip())
        if item is None and s:
            prev_code = s
        out.append(item)
    return out


def is_text(body):
    return bool(body) and not body.startswith('|') and not TAG_RE.match(body) and not BANNER_RE.fullmatch(body)


def added_mask(old, new):
    new_lines = new.split('\n')
    if not old:
        return [True] * len(new_lines)
    sm = difflib.SequenceMatcher(None, [l.strip() for l in old.split('\n')], [l.strip() for l in new_lines],
                                 autojunk=False)
    mask = [False] * len(new_lines)
    for op, _, _, j1, j2 in sm.get_opcodes():
        if op in ('insert', 'replace'):
            for j in range(j1, j2):
                mask[j] = True
    return mask


def check(old, new, ext, line_offset=0):
    """Список (номер строки в new, текст замечания)."""
    items = comment_lines(new, ext)
    mask = added_mask(old, new)
    problems = []
    run = []  # (lineno, kind, body, added)

    def flush():
        if not run:
            return
        texts = [(n, b) for n, k, b, a in run if is_text(b)]
        fresh = [b for n, k, b, a in run if a and is_text(b)]
        if not fresh:
            return
        is_doc = any(k in ('doc', 'block') for _, k, _, _ in run)
        lim, chars = (DOC_MAX, DOC_CHARS) if is_doc else (LINE_MAX, LINE_CHARS)
        total = sum(len(b) for _, b in texts)
        if len(texts) > lim or total > chars:
            what = 'докблок' if is_doc else 'комментарий'
            size = f'{len(texts)} строк' if len(texts) > lim else f'{total} знаков'
            problems.append((texts[0][0], f'{what} на {size} (предел {lim} строк / {chars} знаков): «{texts[0][1][:60]}…»'))

    in_oa = False
    for i, (item, is_added) in enumerate(zip(items, mask)):
        n = i + 1 + line_offset
        if item is None:
            flush()
            run = []
            in_oa = False
            continue
        kind, body = item
        if '@OA\\' in body:
            in_oa = True
        if in_oa:
            continue
        run.append((n, kind, body, is_added))
        if not (is_added and is_text(body)):
            continue
        for rx, why in MARKERS:
            m = rx.search(body)
            if m:
                problems.append((n, f'{why}: «{body[:70]}»'))
        c = caps_hit(body)
        if c:
            problems.append((n, f'капс для нажима «{c}»: «{body[:70]}»'))
    flush()
    return problems


def ext_of(path):
    name = os.path.basename(path)
    if name == 'Makefile' or name.startswith('Dockerfile'):
        return '.sh'
    if name.endswith('.blade.php'):
        return ''
    return os.path.splitext(name)[1].lower()


def watched(path):
    return path.startswith(ROOT) and not any(p in path for p in SKIP_PARTS) and ext_of(path) in CODE_EXT


RULE = ('Комментарий пишется, только если без него следующий правщик ошибётся: неочевидная причина '
        'или ловушка. Обычный до двух строк, докблок до четырёх. Замеры, даты, историю правки, кто решил '
        'и как нашли — в сообщение коммита, в коде их нет. Пересказ кода удали. Капс, «ровно», «именно», '
        '«честно», «намеренно» не нужны. Перепиши и повтори правку. Подробно — скилл kudab-comments.')


def hook():
    if os.environ.get('KUDAB_COMMENT_GUARD') == 'off':
        return 0
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    tool = data.get('tool_name', '')
    inp = data.get('tool_input') or {}
    path = inp.get('file_path') or ''
    if not watched(path):
        return 0
    ext = ext_of(path)

    pairs = []
    if tool == 'Edit':
        pairs.append((inp.get('old_string') or '', inp.get('new_string') or ''))
    elif tool == 'MultiEdit':
        for e in inp.get('edits') or []:
            pairs.append((e.get('old_string') or '', e.get('new_string') or ''))
    elif tool == 'Write':
        try:
            with open(path, encoding='utf-8') as f:
                old = f.read()
        except OSError:
            old = ''
        pairs.append((old, inp.get('content') or ''))
    else:
        return 0

    problems = []
    for old, new in pairs:
        problems += [p for _, p in check(old, new, ext)]
    if not problems:
        return 0
    uniq = list(dict.fromkeys(problems))
    msg = [f'Правка в {os.path.relpath(path, ROOT)} не прошла проверку комментариев:']
    msg += [f'- {p}' for p in uniq[:8]]
    if len(uniq) > 8:
        msg.append(f'- и ещё {len(uniq) - 8}')
    msg.append(RULE)
    print('\n'.join(msg), file=sys.stderr)
    return 2


def scan(paths):
    files = []
    for p in paths:
        p = os.path.abspath(p)
        if os.path.isdir(p):
            listed = subprocess.run(['git', '-C', p, 'ls-files', '--recurse-submodules', '.'],
                                    capture_output=True, text=True)
            files += [os.path.join(p, n) for n in listed.stdout.splitlines()]
        else:
            files.append(p)
    total = 0
    for f in sorted(files):
        if not watched(f):
            continue
        try:
            text = open(f, encoding='utf-8').read()
        except (OSError, UnicodeDecodeError):
            continue
        for n, p in check('', text, ext_of(f)):
            print(f'{os.path.relpath(f, ROOT)}:{n}: {p}')
            total += 1
    print(f'итого замечаний: {total}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--scan':
        sys.exit(scan(sys.argv[2:] or ['.']))
    sys.exit(hook())
