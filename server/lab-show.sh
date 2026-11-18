#!/bin/bash
# Vista "doppia": cosa dice UFW e cosa c'è realmente in iptables.
echo "=== ufw status numbered ==="
ufw status numbered
echo
echo "=== iptables: catena ufw-user-input (generata da UFW) ==="
iptables -L ufw-user-input -n -v --line-numbers 2>/dev/null || echo "(UFW non attivo)"
