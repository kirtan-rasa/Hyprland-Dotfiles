#!/usr/bin/env python3
import calendar, json, time
from datetime import datetime

ACCENT, DIM, WEEKEND, BG = "#7aa2f7", "#565f89", "#f7768e", "#1a1b26"
calendar.setfirstweekday(calendar.MONDAY)

def tooltip(now):
    title = now.strftime("%B %Y").center(20)
    rows = [
        f'<span color="{ACCENT}" weight="bold">{title}</span>',
        f'<span color="{DIM}">Mo Tu We Th Fr Sa Su</span>',
    ]
    weeks = calendar.monthcalendar(now.year, now.month)
    weeks += [[0] * 7] * (6 - len(weeks))  # всегда 6 строк, чтобы окно не прыгало
    for week in weeks:
        cells = []
        for i, d in enumerate(week):
            if not d:
                cells.append("  ")
            elif d == now.day:
                cells.append(f'<span color="{BG}" background="{ACCENT}" weight="bold">{d:2d}</span>')
            elif i >= 5:
                cells.append(f'<span color="{WEEKEND}">{d:2d}</span>')
            else:
                cells.append(f"{d:2d}")
        rows.append(" ".join(cells))
    return "\n".join(rows)

last = None
while True:
    now = datetime.now()
    minute = now.replace(second=0, microsecond=0)
    if minute != last:
        last = minute
        print(json.dumps({
            "text": f"\uf017 {now:%H:%M}",
            "tooltip": tooltip(now),
        }), flush=True)
    time.sleep(1)
