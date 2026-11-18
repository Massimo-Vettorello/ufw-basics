#!/bin/bash
# Uso: check [IP_SERVER]   (default 172.29.0.10)
# OPEN = risponde | REFUSED = reject/porta chiusa | TIMEOUT = deny (pacchetto ignorato)
T=${1:-172.29.0.10}
D=$(mktemp -d)
printf "Verifica da %s verso %s\n" "$(hostname -i | awk '{print $1}')" "$T"

# test in parallelo per essere veloci anche quando tutto va in timeout
( ping -c1 -W1 "$T" >/dev/null 2>&1 && echo "OPEN (ping risponde)" || echo "TIMEOUT / bloccato" ) > $D/00 &
i=1
for entry in "SSH:22" "HTTP:80" "HTTPS:443" "rsync:873" "MySQL:3306" "Postgres:5432" "range:6000" "range:6001"; do
  ( port=${entry##*:}
    out=$(nc -z -w1 -v "$T" "$port" 2>&1); rc=$?
    if [ $rc -eq 0 ]; then echo "OPEN"
    elif echo "$out" | grep -qi "refused"; then echo "REFUSED  (reject o nessun servizio)"
    else echo "TIMEOUT  (deny: il pacchetto sparisce)"; fi ) > $D/$(printf %02d $i) &
  i=$((i+1))
done
wait

printf "\n%-14s %s\n" "SERVIZIO" "ESITO"
printf "%-14s %s\n" "ICMP ping" "$(cat $D/00)"
i=1
for entry in "SSH:22" "HTTP:80" "HTTPS:443" "rsync:873" "MySQL:3306" "Postgres:5432" "range:6000" "range:6001"; do
  name=${entry%%:*}; port=${entry##*:}
  printf "%-14s %s\n" "$name/$port" "$(cat $D/$(printf %02d $i))"
  i=$((i+1))
done
rm -rf $D
