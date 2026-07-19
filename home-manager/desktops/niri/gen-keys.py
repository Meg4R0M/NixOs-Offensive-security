#!/usr/bin/env python3
# Génère haxos-keys.conf (même dossier) : tableau propre (3 colonnes, bordures
# box-drawing), padding au codepoint pour aligner malgré les accents. Sortie
# STATIQUE. Régénérer après un changement de binds : `python3 gen-keys.py`.
import re, io, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "haxos-keys.conf")
KEYW, DESCW = 13, 14
CELLW = KEYW + 1 + DESCW           # 28
INNER = 1 + CELLW + 1 + 1 + 1 + CELLW + 1 + 1 + 1 + CELLW + 1  # 92
BAR1, BAR2 = 30, 61                # positions des séparateurs │ dans l'inner

cols = [
    ("FENÊTRES", [
        ("Mod+↵", "terminal"), ("Mod+D", "menu (rofi)"), ("Mod+Q", "fermer"),
        ("Mod+F", "plein écran"), ("Mod+Shift+F", "maximiser"), ("Mod+V", "flottant"),
        ("Mod+T", "onglets"), ("Mod+C", "centrer"), ("Mod+R", "largeur"),
    ]),
    ("NAVIGATION", [
        ("Mod+←→", "focus colonne"), ("Mod+↑↓", "focus fenêtre"),
        ("Mod+Shift+←→", "déplacer col."), ("Mod+Shift+↑↓", "déplacer fen."),
        ("Mod+Ctrl+←→", "aspirer/éject"), ("Mod+W", "vue d'ensemble"),
        ("Mod+Tab", "dernier WS"), ("Mod+1-9", "aller au WS"),
        ("Mod+Shift+1-5", "envoyer au WS"),
    ]),
    ("SYSTÈME", [
        ("Impr", "capture écran"), ("Mod+Impr", "capture fen."),
        ("Mod+Shift+V", "presse-papier"), ("Super+Shift+L", "verrouiller"),
        ("Mod+Shift+/", "aide niri"), ("Mod+K", "clavier écran"),
        ("Mod+Shift+R", "rotation"), ("Mod+Shift+E", "quitter niri"),
        ("média", "Vol/Muet/Lum"),
    ]),
]

def vis(s):  # longueur VISIBLE (hors tokens ${...})
    return len(re.sub(r'\$\{[^}]*\}', '', s))
def pad(s, w):
    return s + " " * (w - vis(s))

def cell(key, desc):
    return pad("${color1}" + key + "${color}", KEYW) + " " + pad("${color}" + desc, DESCW)
EMPTY = " " * CELLW

# Séparation des colonnes par ESPACEMENT (pas de trait vertical : conky rend les
# box-drawing verticaux empilés en pointillés à cause de l'interligne). Structure
# = règles HORIZONTALES (elles se raccordent) + colonnes alignées.
LM  = "  "                                   # marge gauche
GAP = "    "                                 # espace inter-colonnes
WIDTH = len(LM) + CELLW * 3 + len(GAP) * 2   # 2 + 84 + 8 = 94

def datarow(c1, c2, c3):
    return LM + c1 + GAP + c2 + GAP + c3

# Barres = ${hr} (règle horizontale NATIVE conky) : tracée sur toute la largeur de
# la fenêtre, donc les 3 font PILE la même longueur (celle du tableau), sans souci
# de chasse des box-drawing (═ est plus étroit qu'un caractère normal dans cette
# police). Titre sur sa propre ligne. Séparateur du milieu en VERT (bloc cyber).
HR_RED   = "${color2}${hr 2}${color}"
HR_GREEN = "${color 00ff41}${hr 2}${color}"

ttxt = "${color2}[ ${color1}RACCOURCIS NIRI${color2} ]${color}"
padL = (WIDTH - vis(ttxt)) // 2
padR = WIDTH - vis(ttxt) - padL
titleline = " " * padL + ttxt + " " * padR
hdr = datarow(*[pad("${color1}" + c[0] + "${color}", CELLW) for c in cols])
data = []
for r in range(max(len(c[1]) for c in cols)):
    cells = [cell(*c[1][r]) if r < len(c[1]) else EMPTY for c in cols]
    data.append(datarow(*cells))

# vérif largeur sur les lignes de TEXTE (les ${hr} sont des règles pleine largeur
# tracées par conky -> pas de largeur en caractères à contrôler).
textlines = [titleline, hdr] + data
widths = {vis(l) for l in textlines}
assert widths == {WIDTH}, f"largeurs incohérentes: {sorted(widths)} (attendu {WIDTH})"

lines = [titleline, HR_RED, hdr, HR_GREEN] + data + [HR_RED]

conf = """-- haxOS — cheatsheet des raccourcis niri (tableau, fenêtre bas-centre). Contenu
-- STATIQUE généré par gen-keys.py (même dossier ; padding au codepoint) : miroir
-- de la section binds de home-manager/desktops/niri/default.nix — régénérer via
-- `python3 gen-keys.py` si tu changes les binds. Colonnes alignées + barres via
-- hr natif conky (pleine largeur ; verticaux évités = pointillés dans conky).
conky.config = {
    out_to_wayland = true,
    out_to_x = false,
    own_window = true,
    own_window_type = 'desktop',
    own_window_argb_visual = true,
    own_window_argb_value = 0,

    background = true,
    double_buffer = true,
    update_interval = 3600.0,   -- contenu statique -> refresh minimal
    total_run_times = 0,

    use_xft = true,
    -- JetBrains Mono (pas Victor Mono) : ses box-drawing ═║│╔╣ se RACCORDENT
    -- (traits continus) ; Victor Mono les rend en pointillés. Reste monospace
    -- strict -> l'alignement au codepoint tient.
    font = 'JetBrainsMono Nerd Font Mono:pixelsize=12',
    override_utf8_locale = true,
    draw_shades = false,
    draw_outline = false,

    -- bottom_middle : la fenêtre s'auto-dimensionne au tableau -> centrée. Pas de
    -- alignc (les colonnes s'alignent car chaque ligne part du bord gauche).
    alignment = 'bottom_middle',
    gap_x = 0,
    gap_y = 124,                -- descendu de 50px (174 -> 124)

    default_color = '00b32d',   -- descriptions (vert moyen)
    color1 = '39ff14',          -- touches (vert néon)
    color2 = 'ff2b2b',          -- bordures / séparateurs (rouge fsociety)
}

conky.text = [[
""" + "\n".join(lines) + "\n]]\n"

with io.open(OUT, "w", encoding="utf-8") as f:
    f.write(conf)
print("écrit:", OUT, "| largeur:", INNER + 2, "chars | lignes:", len(lines))
