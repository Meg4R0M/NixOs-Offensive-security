import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone

# Veille cybersécurité FR : CERT-FR (ANSSI) officiel + ZATAZ (actu).
FEEDS = [
    ("ALE", "https://www.cert.ssi.gouv.fr/alerte/feed/"),
    ("AVI", "https://www.cert.ssi.gouv.fr/avis/feed/"),
    ("ACT", "https://www.cert.ssi.gouv.fr/actualite/feed/"),
    ("ZAT", "https://www.zataz.com/feed/"),
]
MAXLEN = 90
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
    print("${color2}(veille indisponible - hors ligne ?)${color}")
else:
    items.sort(key=lambda x: (x[2] is not None, x[2] or NOW), reverse=True)

    # Menace du jour : l'alerte la plus récente (sinon l'item le plus récent).
    featured = next((i for i in items if i[0] == "ALE"), items[0])
    print("${color2}▚ MENACE DU JOUR ▚${color}")
    print("${color1}" + clip(featured[1]) + "${color}")
    print("${color3}" + ("─" * 100) + "${color}")

    colmap = {"ALE": "${color2}"}
    seen = {(featured[0], featured[1])}
    shown = 0
    for tag, title, dt in items:
        if (tag, title) in seen:
            continue
        seen.add((tag, title))
        col = colmap.get(tag, "${color1}")
        line = col + "[" + tag + "]${color} " + clip(title)
        d = fmt_date(dt)
        if d:
            line += " ${color3}" + d + "${color}"
        print(line)
        shown += 1
        if shown >= 11:
            break
