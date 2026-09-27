#!/usr/bin/env python3
"""Применяет разметку чистки комментариев: [{"file", "before", "after"}, ...].

Правка идёт, только если before встречается в файле ровно один раз, строки кода
после неё те же, служебные теги на месте и сторож не возражает против нового текста.
"""
import argparse
import collections
import importlib.util
import json
import os
import re
import sys

ROOT = '/home/maks/projects/kudab-infra/'
spec = importlib.util.spec_from_file_location('guard', os.path.join(ROOT, '.claude/hooks/comment-guard.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

# теги, от которых зависит поведение: PHPUnit, PHPStan, Swagger, линтеры
TAG_RE = re.compile(r'@(dataProvider|test|depends|group|covers\w*|before\w*|after\w*|requires|runInSeparateProcess|'
                    r'preserveGlobalState|backupGlobals|OA\\\w+|ORM\\\w+|param|return|var|throws|template\w*|'
                    r'property\w*|method|extends|implements|mixin|phpstan-[\w-]+|psalm-[\w-]+|deprecated)\b\s*(\S*)')
DIRECTIVE_RE = re.compile(r'eslint-disable|eslint-enable|prettier-ignore|@ts-ignore|@ts-expect-error|@ts-nocheck|'
                          r'phpcs:|noqa|type:\s*ignore|pragma|webpackChunkName|istanbul ignore|c8 ignore|#region|#endregion')


def code_lines(text, ext):
    items = guard.comment_lines(text, ext)
    return [line.rstrip() for line, item in zip(text.split('\n'), items) if item is None and line.strip()]


def protected(text, ext):
    tags = collections.Counter()
    for line, item in zip(text.split('\n'), guard.comment_lines(text, ext)):
        if item is None:
            continue
        for m in TAG_RE.finditer(line):
            tags[(m.group(1), m.group(2))] += 1
        if DIRECTIVE_RE.search(line):
            tags[('directive', line.strip())] += 1
    return tags


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
    n = text.count(before)
    if n == 0:
        real, adjusted = loose_match(text, before, after)
        if real is not None:
            before, after = real, adjusted
            n = 1
    if n != 1:
        return None, f'before найден {n} раз'
    if after == '' and text.count(before + '\n') == 1:
        new = text.replace(before + '\n', '', 1)
    else:
        new = text.replace(before, after, 1)
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
        for m in items:
            new, why = apply_one(text, m['before'], m.get('after', ''), ext)
            if why:
                first = m['before'].strip().split('\n')[0][:70]
                print(f'ПРОПУСК {os.path.relpath(path, ROOT)}: {why} | {first}')
                skipped += 1
                continue
            text = new
            done += 1
        if text != start:
            removed += start.count('\n') - text.count('\n')
            if not args.dry_run:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(text)
    print(f'применено {done}, пропущено {skipped}, строк меньше на {removed}' + (' (проба)' if args.dry_run else ''))


if __name__ == '__main__':
    main()
