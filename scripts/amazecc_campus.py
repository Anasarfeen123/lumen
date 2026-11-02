#!/usr/bin/env python3
"""Public campus schedules used by AmazeCC, cached for Lumen's native UI.

No login is needed or sent to the public schedule host. Remote failures retain
cached schedules and their original freshness; bundled data is labelled offline.
"""
import argparse
import datetime as dt
import json
import os
import re
import urllib.request
from pathlib import Path
from amazecc import read_json, write_private

ROOT = Path(__file__).resolve().parent
STATE = Path(os.environ.get('XDG_STATE_HOME') or Path.home()/'.local/state')/'lumen'
HOST = 'https://kanishka-developer.github.io/unmessify/json/en/'
BLOCKS = {'Male': {'A': 'A', 'C': 'CB', 'D1': 'D1', 'D2': 'D2', 'E': 'E'}, 'Female': {'B': 'B', 'C': 'CG'}}


def profile(settings, hostel):
    gender = str(settings.get('campusGender') or hostel.get('gender') or '').strip().capitalize()
    block = str(settings.get('campusBlock') or hostel.get('blockName') or '').strip().upper().split(' ')[0]
    room = str(settings.get('campusRoom') or hostel.get('roomNo') or '').strip()
    raw = str(settings.get('campusMess') or hostel.get('messInfo') or '').strip().upper()
    mess = 'Non Veg' if raw in ('NON', 'NON VEG', 'NON-VEG') else 'Veg' if raw in ('VEG', 'VEGETARIAN') else 'Special' if raw == 'SPECIAL' else ''
    return dict(gender=gender, block=block, room=room, mess=mess)


def resource(kind, p):
    gender, block, mess = p['gender'], p['block'], p['mess']
    if kind == 'laundry' and block in BLOCKS.get(gender, {}):
        return f'VITC-{BLOCKS[gender][block]}-L.json', f'VITC-{block}-{gender[0]}-L.json'
    if kind == 'mess' and gender in BLOCKS and mess in ('Veg', 'Non Veg', 'Special'):
        suffix = {"Veg": "V", "Non Veg": "N", "Special": "S"}[mess]
        name = f"VITC-{'M' if gender == 'Male' else 'W'}-{suffix}.json"
        return name, name
    return None


def load_resource(kind, p, cache, online=False):
    pair = resource(kind, p)
    if not pair:
        return dict(rows=[], error='Choose your hostel group and ' + ('block' if kind == 'laundry' else 'mess type'), offline=False, fetchedAt=0)
    remote, bundled = pair
    key = kind + '/' + remote
    now = int(dt.datetime.now().timestamp()*1000)
    error = ''
    if online:
        try:
            req = urllib.request.Request(HOST+remote, headers={'User-Agent': 'Lumen/1.0'})
            with urllib.request.urlopen(req, timeout=8) as response:
                data = json.load(response)
            if not isinstance(data, dict) or not isinstance(data.get('list'), list) or not data['list']:
                raise ValueError('Invalid schedule')
            cache[key] = dict(rows=data['list'], fetchedAt=now)
        except (OSError, ValueError, TimeoutError):
            error = 'Could not refresh. Showing the saved schedule.'
    stored = cache.get(key)
    if not stored:
        data = read_json(str(ROOT/'amazecc-campus-data'/kind/bundled)) or {}
        stored = dict(rows=data.get('list', []), fetchedAt=0)
    rows = [row for row in stored.get('rows', []) if isinstance(row, dict)]
    return dict(rows=rows, fetchedAt=stored.get('fetchedAt', 0), offline=not online or bool(error), error=error,
                sourceUpdated=max((str(row.get('UpdatedAt') or '') for row in rows), default=''), source=HOST+remote)


def room_matches(room, ranges):
    nums = re.findall(r'\d+', str(room))
    if not nums:
        return False
    n = int(nums[-1])
    # Multiple ranges, comma-separated rooms, en dashes and a single room.
    text = str(ranges).replace('–', '-').replace('—', '-')
    pairs = re.findall(r'(\d+)\s*(?:-|to)\s*(\d+)', text, re.I)
    if any(int(a) <= n <= int(b) for a, b in pairs):
        return True
    singles = re.sub(r'\d+\s*(?:-|to)\s*\d+', '', text, flags=re.I)
    return n in [int(x) for x in re.findall(r'\d+', singles)]


def laundry_events(rows, room, today=None, months=2):
    today = today or dt.date.today()
    events = []
    for offset in range(months):
        month0 = today.year*12 + today.month-1 + offset
        year, month = divmod(month0, 12)
        for row in rows:
            if not room_matches(room, row.get('RoomNumber', '')):
                continue
            try:
                day = dt.date(year, month+1, int(str(row.get('Date', '')).strip()))
            except (ValueError, TypeError):
                continue  # e.g. day 31 in February: never silently roll to March
            if day < today:
                continue
            events.append(dict(date=day.isoformat(), day=day.day, rooms=str(row['RoomNumber'])))
    return sorted({(e['date'], e['rooms']): e for e in events}.values(), key=lambda e: e['date'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('gender', 'block', 'room', 'mess'):
        parser.add_argument('--'+field, default=None)
    parser.add_argument("--online", action="store_true", help="Opt in to provider requests disclosing hostel group/block and mess type")
    args = parser.parse_args()
    settings = read_json(str(STATE/'amazecc.json')) or {}
    for field in ('gender', 'block', 'room', 'mess'):
        value = getattr(args, field)
        if value is not None:
            settings['campus'+field.capitalize()] = value
    extra = read_json(str(STATE/'amazecc-extra.json')) or {}
    p = profile(settings, extra.get('hostel') or {})
    cache = read_json(str(STATE/'amazecc-campus-cache.json')) or {}
    laundry = load_resource('laundry', p, cache, online=args.online)
    mess = load_resource('mess', p, cache, online=args.online)
    result = dict(profile=p, laundry=laundry, mess=mess, updated=int(dt.datetime.now().timestamp()*1000))
    write_private(str(STATE/'amazecc-campus-cache.json'), cache)
    write_private(str(STATE/'amazecc-campus.json'), result)
    print(json.dumps(dict(ok=True, offline=laundry['offline'] or mess['offline'])))

if __name__ == '__main__':
    main()
