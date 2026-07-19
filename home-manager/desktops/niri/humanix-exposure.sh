#!/usr/bin/env bash
# humanix-exposure — bloc "exposition publique" pour conky (${execi}).
# IP publique + géoloc (ifconfig.co/json, cache fichier 5 min) + statut VPN + Tor
# + IP locale. Conscience OPSEC « ce que je montre vu de l'extérieur ».
# Argument "plain" => aperçu terminal sans codes couleur conky.
export LC_ALL=C
PUBCACHE=/tmp/humanix-pubip.json
PUBTTL=300
plain=0; [ "$1" = "plain" ] && plain=1

# ── IP publique + géoloc (HTTPS, cache 5 min ; ne remplace le cache que si le
#    JSON est valide -> une panne réseau garde la dernière valeur connue). ──
age=$(( $(date +%s) - $(stat -c %Y "$PUBCACHE" 2>/dev/null || echo 0) ))
if [ ! -f "$PUBCACHE" ] || [ "$age" -ge "$PUBTTL" ]; then
  # IPv4 d'abord (court, tient dans le cadre + « IP publique » attendue) ; repli
  # IPv6 si l'IPv4 échoue (lien IPv6-only). On ne remplace le cache que si JSON OK.
  for opt in -4 ""; do
    if curl -s $opt --max-time 6 https://ifconfig.co/json -o "$PUBCACHE.tmp" 2>/dev/null \
       && jq -e .ip "$PUBCACHE.tmp" >/dev/null 2>&1; then
      mv -f "$PUBCACHE.tmp" "$PUBCACHE"; break
    fi
  done
  rm -f "$PUBCACHE.tmp"
fi
pubip=$(jq -r '.ip // empty'            "$PUBCACHE" 2>/dev/null)
country=$(jq -r '.country_iso // empty' "$PUBCACHE" 2>/dev/null)
city=$(jq -r '.city // empty'       "$PUBCACHE" 2>/dev/null)
isp=$(jq -r '.asn_org // empty'     "$PUBCACHE" 2>/dev/null)
[ -z "$pubip" ] && pubip="hors-ligne"
geo="$country"; [ -n "$city" ] && geo="$country · $city"; [ -n "$isp" ] && geo="$geo · $isp"
[ -z "$country" ] && geo="?"
geo=$(printf '%.26s' "$geo")

# ── IP locale (source de la route par défaut) ──
lan=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
[ -z "$lan" ] && lan="—"

# ── VPN : 1re interface VPN montée (wg/tun/tailscale/proton/nordlynx/mullvad) ──
vpnif=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 \
        | grep -m1 -E '^(wg|tun|tailscale|proton|nordlynx|mullvad)')
if [ -n "$vpnif" ]; then
  vpnip=$(ip -4 -o addr show dev "$vpnif" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
  vpn="$vpnif UP · ${vpnip:-?}"; vpnup=1
else
  vpn="down (clair)"; vpnup=0
fi

# ── Tor : SOCKS 9050 en écoute ? ──
if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE ':9050$'; then
  tor="9050 open"; torup=1
else
  tor="off"; torup=0
fi

emit() {  # emit LABEL VALUE STATE(ok|bad|neutral)
  if [ "$plain" = 1 ]; then printf ' %-4s [ %s ]\n' "$1" "$2"; return; fi
  local cval
  case "$3" in
    ok)  cval='${color1}';;
    bad) cval='${color2}';;
    *)   cval='${color}';;
  esac
  printf ' ${color3}%-4s${color} ${color2}[${color} %s%s${color} ${color2}]${color}\n' "$1" "$cval" "$2"
}

emit pub "$pubip" neutral
emit geo "$geo"    neutral
if [ "$vpnup" = 1 ]; then emit vpn "$vpn" ok; else emit vpn "$vpn" bad; fi
if [ "$torup" = 1 ]; then emit tor "$tor" ok; else emit tor "$tor" neutral; fi
emit lan "$lan"    neutral
