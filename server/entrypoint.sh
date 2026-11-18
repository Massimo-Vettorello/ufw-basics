#!/bin/bash
# Avvia i servizi "bersaglio" da proteggere con UFW.
service nginx start                      # HTTP 80
/usr/sbin/sshd                           # SSH  22
# Finti servizi con banner (si vede quando la porta viene raggiunta):
# HTTPS 443, rsync 873, MySQL 3306, PostgreSQL 5432, due porte del range 6000:6007
for p in 443 873 3306 5432 6000 6001; do
  (while true; do echo "servizio-$p" | nc -l -p $p -q0 >/dev/null 2>&1; done) &
done
echo "Server pronto. IP: $(hostname -i). UFW è DISATTIVATO (stato iniziale)."
exec sleep infinity
