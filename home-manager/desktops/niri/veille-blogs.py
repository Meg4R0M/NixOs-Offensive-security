import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone

# Veille blogs/presse cybersécurité FR (agrégateur).
FEEDS = [
    ("UN", "https://www.undernews.fr/feed/"),
    ("JDH", "https://www.journalduhacker.net/rss"),
    ("CS", "https://www.cyber-securite.fr/feed/"),
    ("DSB", "https://www.datasecuritybreach.fr/feed/"),
    ("OST", "https://blog.ostraca.fr/index.xml"),
]
# breach/fuites = accent rouge
RED = {"DSB"}
MAXLEN = 90
MAXITEMS = 11
NOW = datetime.now(timezone.utc)


def fetch(tag, url):
    out = []
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "conky-cyberveille"})
        data = urllib.request.urlopen(req, timeout=8).read()
        root = ET.fromstring(data)
        for it in root.iter("item"):
            title = (it.findtext("title") or "").strip()
            if not title:
                continue
            dt = None
            pd = it.findtext("pubDate")
            if pd:
                try:
                    dt = parsedate_to_datetime(pd)
                except Exception:
                    dt = None
            out.append((tag, title, dt))
    except Exception:
        pass
    return out


items = []
for tag, url in FEEDS:
    items += fetch(tag, url)


def clip(t):
    return t if len(t) <= MAXLEN else t[: MAXLEN - 1] + "…"


def fmt_date(dt):
    return dt.astimezone().strftime("%d/%m") if dt else ""


if not items:
    print("${color2}(veille blogs indisponible - hors ligne ?)${color}")
else:
    items.sort(key=lambda x: (x[2] is not None, x[2] or NOW), reverse=True)
    seen = set()
    shown = 0
    for tag, title, dt in items:
        if (tag, title) in seen:
            continue
        seen.add((tag, title))
        col = "${color2}" if tag in RED else "${color1}"
        line = col + "[" + tag + "]${color} " + clip(title)
        d = fmt_date(dt)
        if d:
            line += " ${color3}" + d + "${color}"
        print(line)
        shown += 1
        if shown >= MAXITEMS:
            break
