#!/usr/bin/env bash
# humanix-netmon — dashboard réseau style haxOS (pour conky ${execpi}).
# Argument "plain" => aperçu terminal sans codes couleur conky.
export LC_ALL=C
OUI="${HUMANIX_OUI:-/nix/store/wy8k9y1j2gdifz7mi2y8zy324i29f28h-arp-scan-1.10.0/share/arp-scan/ieee-oui.txt}"
ARPSCAN="${HUMANIX_ARPSCAN:-arp-scan}"
MAXCONN=16
LANMAX=16
AWKTR='function tr(s,n){return length(s)>n?substr(s,1,n-1)"~":s}'

if [ "$1" = "plain" ]; then
  colorize() { cat; }
else
  colorize() {
    sed -e 's/\[/${color2}[${color}/g' \
        -e 's/\]/${color2}]${color}/g' \
        -e 's/\(├\|└\|│\|─\|::\)/${color2}&${color}/g'
  }
fi

lan_scan() {
  cache=/tmp/humanix-lan.cache
  if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) )) -lt 60 ]; then
    cat "$cache"; return
  fi
  {
    if "$ARPSCAN" --localnet --retry=1 2>/dev/null | grep -qE '^[0-9]+\.[0-9]'; then
      "$ARPSCAN" --localnet --retry=1 2>/dev/null | grep -E '^[0-9]+\.[0-9]' \
        | awk -F'\t' '{print $1"\t"$2"\t"$3}'
    else
      # repli sans root : cache ARP (ip neigh) + vendor via base OUI d'arp-scan
      ip neigh show 2>/dev/null | awk '/lladdr/ && $1 ~ /^[0-9]+\./ {ip=$1; for(i=1;i<=NF;i++) if($i=="lladdr") mac=$(i+1); print ip"\t"mac}' \
      | while IFS=$'\t' read -r ip mac; do
          oui=$(echo "$mac" | awk -F: '{print toupper($1$2$3)}')
          vendor=$(grep -im1 "^$oui" "$OUI" 2>/dev/null | cut -f2-)
          [ -z "$vendor" ] && vendor="(unknown)"
          printf '%s\t%s\t%s\n' "$ip" "$mac" "$vendor"
        done
    fi
  } | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -$LANMAX > "$cache" 2>/dev/null
  cat "$cache"
}

{
  # ── STATISTICS ──
  echo "[STATISTICS]"
  est=$(ss -tan state established 2>/dev/null | tail -n +2 | wc -l)
  tw=$(ss -tan state time-wait 2>/dev/null | tail -n +2 | wc -l)
  lis=$(ss -tln 2>/dev/null | tail -n +2 | wc -l)
  udp=$(ss -uan 2>/dev/null | tail -n +2 | wc -l)
  echo "├─ established:[$est] time_wait:[$tw] listening:[$lis] udp_total:[$udp]"
  echo

  # ── ROUTING ──
  echo "[ROUTING]"
  ip -4 route 2>/dev/null | awk '{
    d=$1; if(d!="default") sub(/\/.*/,"",d);
    gw="0.0.0.0"; dev="?";
    for(i=1;i<=NF;i++){ if($i=="via") gw=$(i+1); if($i=="dev") dev=$(i+1); }
    printf "├─ [%-15s] [%-15s] [%s]\n", d, gw, dev
  }'
  echo

  # ── ACTIVE_CONNECTIONS (connexions réelles, pas les LISTEN) ──
  echo "[ACTIVE_CONNECTIONS]"
  printf "   Proto R-Q S-Q %-24s %-24s %s\n" "Local Address" "Foreign Address" "State"
  ss -tanr state connected 2>/dev/null | tail -n +2 | head -$MAXCONN | awk "$AWKTR"'{
    st=$1; if(st=="ESTAB")st="ESTABLISHED"; gsub("-","_",st);
    printf "├─ [tcp ] [%3s] [%3s] [%-22s] [%-22s] [%s]\n", $2, $3, tr($4,22), tr($5,22), st
  }'
  echo

  # ── UDP_CONNECTIONS (IPv4) ──
  echo "[UDP_CONNECTIONS]"
  printf "   Proto R-Q S-Q %-24s %-24s %s\n" "Local Address" "Foreign Address" "State"
  ss -4 -uanr state established 2>/dev/null | tail -n +2 | grep -v '%' | head -6 | awk "$AWKTR"'{
    printf "├─ [udp ] [%3s] [%3s] [%-22s] [%-22s] [ESTABLISHED]\n", $1, $2, tr($3,22), tr($4,22)
  }'
  echo

  # ── LISTENING_PORTS ──
  echo "[LISTENING_PORTS]"
  printf "   Proto %-6s %-15s %s\n" "Port" "Address" "Program"
  ss -tlnp 2>/dev/null | tail -n +2 | awk '{
    addr=$4; n=split(addr,a,":"); port=a[n]; sub(/:[^:]*$/,"",addr);
    prog="-"; if (match($0,/"[^"]+"/)) prog=substr($0,RSTART+1,RLENGTH-2);
    printf "├─ [tcp ] [%5s] [%-15s] [%s]\n", port, addr, prog
  }'
  echo

  # ── LAN_DISCOVERY ──
  dev=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
  cidr=$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | head -1)
  echo "[LAN_DISCOVERY] :: [$dev] [$cidr]"
  printf "   %-15s %-17s %s\n" "IP Address" "MAC Address" "Vendor"
  lan_scan | awk -F'\t' '{ printf "├─ [%-15s] [%-17s] [%s]\n", $1, $2, $3 }'
} | colorize
