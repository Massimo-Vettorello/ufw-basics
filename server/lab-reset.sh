#!/bin/bash
# Riporta tutto allo stato iniziale: UFW disattivato, nessuna regola.
ufw --force reset
ufw status
