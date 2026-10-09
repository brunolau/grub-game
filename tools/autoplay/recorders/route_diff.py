"""Where two recordings of a route part (tools/autoplay/recorders, wf12; world-B).

    python tools/autoplay/recorders/route_diff.py <route a> <route b>

Both files are route files (`# ...` comment lines, then `ticks:KEYS|KEYS,...` lines; one stream per player). Prints the
ticks of each, the first tick on which the keys differ (with the keys of both around it) and how many ticks differ -
so a re-recording that is DIFFERENT (record.sh) can be read: a bot that drifted late by a tick or two, or another
route altogether.
"""
import io
import sys


def expand(path):
    ticks = []
    for line in io.open(path, encoding='utf-8').read().replace('\r', '').split('\n'):
        if not line or line.startswith('#'):
            continue
        for part in line.split(','):
            part = part.strip()
            if ':' not in part:
                continue
            count, keys = part.split(':', 1)
            if count.isdigit():
                ticks.extend([keys] * int(count))
    return ticks


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    a, b = expand(sys.argv[1]), expand(sys.argv[2])
    shared = min(len(a), len(b))
    differing = [i for i in range(shared) if a[i] != b[i]]
    print('%s: %d ticks; %s: %d ticks' % (sys.argv[1], len(a), sys.argv[2], len(b)))
    if not differing and len(a) == len(b):
        print('identical, tick for tick')
        return 0
    if not differing:
        print('the same keys for %d ticks; one is %d ticks longer' % (shared, abs(len(a) - len(b))))
        return 1
    first = differing[0]
    print('first difference at tick %d of %d; %d of the %d shared ticks differ' % (first, shared, len(differing), shared))
    for i in range(max(first - 2, 0), min(first + 4, shared)):
        print('  tick %5d   %-12s %-12s %s' % (i, a[i], b[i], '' if a[i] == b[i] else '<'))
    return 1


if __name__ == '__main__':
    sys.exit(main())
