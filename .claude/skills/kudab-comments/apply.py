#!/usr/bin/env python3
"""Применяет разметку чистки комментариев: [{"file", "before", "after"}, ...].

Правка идёт, только если before встречается в файле ровно один раз, строки кода
после неё те же, служебные теги на месте и сторож не возражает против нового текста.
"""
import argparse
import ast
import collections
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = '/home/maks/projects/kudab-infra/'
spec = importlib.util.spec_from_file_location('guard', os.path.join(ROOT, '.claude/hooks/comment-guard.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

# теги, от которых зависит поведение: PHPUnit, PHPStan, Swagger. Тип у @param/@return
# поправить можно, потерять сам тег или переименовать параметр нельзя
TAG_RE = re.compile(r'@(dataProvider|test|depends|group|covers\w*|before\w*|after\w*|requires|runInSeparateProcess|'
                    r'preserveGlobalState|backupGlobals|OA\\\w+|ORM\\\w+|param|return|var|throws|template\w*|'
                    r'property\w*|method|extends|implements|mixin|phpstan-[\w-]+|psalm-[\w-]+|deprecated)\b(.*)')
TYPE_TAGS = re.compile(r'^(return|var|throws|template\w*|property\w*|method|extends|implements|mixin|phpstan-[\w-]+|psalm-[\w-]+|deprecated)$')
DIRECTIVE_RE = re.compile(r'eslint-disable|eslint-enable|prettier-ignore|@ts-ignore|@ts-expect-error|@ts-nocheck|'
                          r'phpcs:|noqa|type:\s*ignore|pragma|webpackChunkName|istanbul ignore|c8 ignore|#region|#endregion')


PHP_TOKENS = r"""
$out = [];
foreach (token_get_all(stream_get_contents(STDIN)) as $t) {
    if (is_array($t)) {
        if (in_array($t[0], [T_COMMENT, T_DOC_COMMENT, T_WHITESPACE], true)) continue;
        $out[] = token_name($t[0]) . ':' . $t[1];
    } else {
        $out[] = $t;
    }
}
echo md5(implode("\n", $out));
"""


def php_signature(text):
    """Отпечаток PHP-токенов без комментариев: ловит правки внутри heredoc, SQL и строк."""
    if not shutil.which('php'):
        return None
    r = subprocess.run(['php', '-r', PHP_TOKENS], input=text, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else 'ошибка разбора'


JS_EXT = {'.ts', '.tsx', '.js', '.mjs', '.cjs', '.vue', '.scss', '.css'}
SIG_JS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'signature.cjs')


def node_modules_for(path):
    d = os.path.dirname(path)
    while d.startswith(ROOT.rstrip('/')):
        if os.path.isdir(os.path.join(d, 'node_modules', 'typescript')):
            return os.path.join(d, 'node_modules')
        d = os.path.dirname(d)
    return None


def js_signature(text, path, ext):
    """(отпечаток без комментариев, сколько комментариев стоят первым узлом ветки v-if)."""
    mods = node_modules_for(path)
    if not mods or not shutil.which('node'):
        return None
    r = subprocess.run(['node', SIG_JS, ext, mods], input=text, capture_output=True, text=True)
    if r.returncode != 0:
        return ('ошибка разбора', 0)
    sig, _, bfc = r.stdout.strip().rpartition(' ')
    return (sig, int(bfc or 0))


def py_signature(text):
    """AST без докстрингов: правка строки или кода меняет отпечаток."""
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return 'ошибка разбора'
    for node in ast.walk(tree):
        body = getattr(node, 'body', None)
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and body \
                and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) \
                and isinstance(body[0].value.value, str):
            node.body = body[1:] or [ast.Pass()]
    return ast.dump(tree)


def signature(text, path, ext):
    if ext == '.php':
        return php_signature(text)
    if ext == '.py':
        return py_signature(text)
    if ext in JS_EXT:
        return js_signature(text, path, ext)
    return None


def same_signature(old, new):
    if old is None:
        return True
    if isinstance(old, tuple):
        return new is not None and new[0] == old[0] and new[1] <= old[1]
    return new == old


def code_lines(text, ext):
    items = guard.comment_lines(text, ext)
    return [line.rstrip() for line, item in zip(text.split('\n'), items) if item is None and line.strip()]


def protected(text, ext):
    tags = collections.Counter()
    for line, item in zip(text.split('\n'), guard.comment_lines(text, ext)):
        if item is None:
            continue
        for m in TAG_RE.finditer(line):
            tag, rest = m.group(1), m.group(2)
            if tag == 'param':
                var = re.search(r'\$\w+', rest)
                tags[(tag, var.group(0) if var else '')] += 1
            elif TYPE_TAGS.match(tag):
                tags[(tag,)] += 1
            else:
                tags[(tag, rest.split()[0] if rest.split() else '')] += 1
        if DIRECTIVE_RE.search(line):
            tags[('directive', line.strip())] += 1
    return tags


def line_hits(text, before):
    """Вхождения before, которые начинаются с начала строки и кончаются её концом."""
    hits, i = [], text.find(before)
    while i != -1:
        end = i + len(before)
        if (i == 0 or text[i - 1] == '\n') and (end == len(text) or text[end] == '\n' or before.endswith('\n')):
            hits.append(i)
        i = text.find(before, i + 1)
    return hits


def loose_match(text, before, after):
    """Ищет before построчно без краевых пробелов; отступ after подгоняет под файл."""
    lines = text.split('\n')
    want = [l.strip() for l in before.strip('\n').split('\n')]
    hits = [i for i in range(len(lines) - len(want) + 1)
            if [l.strip() for l in lines[i:i + len(want)]] == want]
    if len(hits) != 1:
        return None, None
    i = hits[0]
    real = '\n'.join(lines[i:i + len(want)])
    file_indent = re.match(r'\s*', lines[i]).group(0)
    first = before.strip('\n').split('\n')[0]
    mark_indent = re.match(r'\s*', first).group(0)
    fixed = []
    for l in after.split('\n'):
        fixed.append(file_indent + l[len(mark_indent):] if l.startswith(mark_indent) and l.strip() else l)
    return real, '\n'.join(fixed)


def apply_one(text, before, after, ext):
    if not before.strip():
        return None, 'пустой before'
    hits = line_hits(text, before)
    if not hits:
        real, adjusted = loose_match(text, before, after)
        if real is not None:
            before, after = real, adjusted
            hits = line_hits(text, before)
    if len(hits) != 1:
        return None, f'before найден {len(hits)} раз'
    i = hits[0]
    end = i + len(before)
    if after == '' and not before.endswith('\n') and text[end:end + 1] == '\n':
        end += 1
    new = text[:i] + after + text[end:]
    if code_lines(new, ext) != code_lines(text, ext):
        return None, 'задевает код'
    if protected(new, ext) != protected(text, ext):
        return None, 'пропадает служебный тег или директива'
    complaints = guard.check(text, new, ext)
    if complaints:
        return None, 'сторож против: ' + complaints[0][1]
    return new, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('marks')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()
    marks = json.load(open(args.marks))
    by_file = collections.defaultdict(list)
    for m in marks:
        path = m['file'] if m['file'].startswith('/') else os.path.join(ROOT, m['file'])
        by_file[path].append(m)

    done = skipped = 0
    removed = 0
    for path, items in sorted(by_file.items()):
        ext = guard.ext_of(path)
        try:
            text = open(path, encoding='utf-8').read()
        except OSError as e:
            print(f'ПРОПУСК {path}: {e}')
            skipped += len(items)
            continue
        start = text
        sig = signature(text, path, ext)
        applied = 0
        for m in items:
            new, why = apply_one(text, m['before'], m.get('after', ''), ext)
            if why is None and sig is not None and not same_signature(sig, signature(new, path, ext)):
                why = 'меняет код, строку или шаблон (или ставит комментарий первым в ветку v-if)'
            if why:
                first = m['before'].strip().split('\n')[0][:70]
                print(f'ПРОПУСК {os.path.relpath(path, ROOT)}: {why} | {first}')
                skipped += 1
                continue
            text = new
            applied += 1
        done += applied
        if text != start:
            removed += start.count('\n') - text.count('\n')
            if not args.dry_run:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(text)
    print(f'применено {done}, пропущено {skipped}, строк меньше на {removed}' + (' (проба)' if args.dry_run else ''))


if __name__ == '__main__':
    main()
