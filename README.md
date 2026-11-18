# Laboratorio UFW (demo per studenti)

Basato sui temi di *UFW Essentials: Common Firewall Rules and Commands* (DigitalOcean):
stato/abilitazione, policy di default, blocco IP, regole per interfaccia, SSH (anche da IP/subnet),
HTTP/HTTPS, rsync, MySQL/PostgreSQL, SMTP in uscita, range di porte, profili applicativi,
eliminazione regole, reset.

## Topologia

| Container   | IP            | Ruolo                                                       |
|-------------|---------------|-------------------------------------------------------------|
| ufw-server  | 172.29.0.10   | Server con UFW: SSH 22, HTTP 80, HTTPS 443, rsync 873, MySQL 3306, PostgreSQL 5432, 6000-6001 |
| ufw-client1 | 172.29.0.21   | Client 1 ("studente buono")                                 |
| ufw-client2 | 172.29.0.22   | Client 2 ("attaccante": da bloccare)                        |

Rete isolata `172.29.0.0/24`, diversa dal lab iptables (`172.28.0.0/24`): i due laboratori possono girare insieme.
UFW lavora solo nel network namespace del container server: **il tuo host non viene toccato**.

## Avvio

```bash
docker compose up -d --build
docker exec -it ufw-server  bash   # terminale A (server)
docker exec -it ufw-client1 bash   # terminale B (client 1)
docker exec -it ufw-client2 bash   # terminale C (client 2)
```

Comandi utili:
- server: `lab-show` (regole UFW + catena iptables generata), `lab-reset` (UFW disattivato, nessuna regola)
- client: `check` (tabella OPEN / REFUSED / TIMEOUT)

Spegnere tutto: `docker compose down`.

## Scaletta della demo

**0. Stato iniziale** – (server) `ufw status` → `Status: inactive`. (client1) `check` → tutto OPEN.

**1. Policy di default e abilitazione** *(lockout!)*
```bash
ufw default deny incoming
ufw default allow outgoing
ufw enable                 # confermare con y
ufw status verbose
```
`check` da client1 → tutto TIMEOUT, **tranne il ping**: UFW per default accetta ICMP in `/etc/ufw/before.rules`.
Provare `ssh root@172.29.0.10` (password `student`) → si blocca: senza regola SSH, in un server reale ci si chiude fuori.
> Messaggio: *prima* `ufw allow ssh`, *poi* `ufw enable`. Qui possiamo rientrare con `docker exec`.

**2. SSH**
```bash
ufw allow ssh              # oppure: ufw allow 22
```
`check` → SSH OPEN. Provare il login SSH da client1.

**3. HTTP e HTTPS (anche per nome servizio e porte multiple)**
```bash
ufw allow http
ufw allow 443/tcp
# alternativa multi-porta:  ufw allow proto tcp from any to any port 80,443
```
`curl http://172.29.0.10` da client1.

**4. SSH solo da IP o subnet** (sostituiamo la regola generica)
```bash
ufw status numbered
ufw delete <numero della regola 22>
ufw allow from 172.29.0.21 to any port 22 proto tcp
```
client1: SSH ok; client2: SSH in timeout. Variante: `ufw allow from 172.29.0.0/24 to any port 22 proto tcp`.

**5. MySQL e PostgreSQL da un IP specifico**
```bash
ufw allow from 172.29.0.21 to any port 3306 proto tcp
ufw allow from 172.29.0.21 to any port 5432 proto tcp
```
`nc -v 172.29.0.10 3306` → banner da client1, timeout da client2.

**6. rsync (873) da un IP o una subnet**
```bash
ufw allow from 172.29.0.0/24 to any port 873 proto tcp
```

**7. Range di porte**
```bash
ufw allow 6000:6007/tcp     # il range richiede sempre il protocollo
```
`check` → 6000 e 6001 OPEN.

**8. Bloccare un indirizzo IP**
```bash
ufw deny from 172.29.0.22
```
Attenzione all'**ordine**: UFW valuta dall'alto, vince la prima regola che combacia.
Se client2 è già coperto da una `allow from 172.29.0.0/24`, il deny in fondo non basta:
```bash
ufw insert 1 deny from 172.29.0.22
ufw status numbered
```

**9. Bloccare su una specifica interfaccia**
```bash
ufw deny in on eth0 from 172.29.0.22
```
Spiegare che `in on <interfaccia>` si può aggiungere a qualsiasi regola (utile con più schede di rete).

**10. DENY vs REJECT**
```bash
ufw reject 5432/tcp         # prima eliminare l'eventuale allow su 5432
```
`check` → 5432 "REFUSED" (immediato), le altre bloccate in "TIMEOUT".

**11. Traffico in uscita: bloccare SMTP**
```bash
# client1:   nc -l -p 25
ufw deny out 25
# server:    nc -zv -w2 172.29.0.21 25   → timeout
```
Eliminare con `ufw delete deny out 25` e riprovare: la connessione passa.

**12. Profili applicativi**
```bash
ufw app list
ufw app info LabDB
ufw allow LabWeb
```
(I profili `LabWeb` e `LabDB` sono creati per la demo in `/etc/ufw/applications.d/lab-apps`. Su Ubuntu trovate anche `OpenSSH`, `Nginx Full`, ecc.)

**13. Eliminare regole**
```bash
ufw status numbered
ufw delete 2                # per numero
ufw delete allow 443/tcp    # per regola
```

**14. Sotto il cofano: UFW è un front-end di iptables**
```bash
lab-show
iptables -S | head -40
ufw show added
cat /etc/ufw/user.rules
```
Collegamento diretto col laboratorio iptables: stessi `ACCEPT/DROP`, catene `ufw-user-input`, `ufw-before-input`...

**15. Disabilitare e resettare**
```bash
ufw disable                 # spegne il firewall, le regole restano
ufw --force reset           # cancella tutto (o: lab-reset)
```

## Esercizi per gli studenti

1. Configura un server web sicuro: default deny, SSH solo da `172.29.0.21`, HTTP/HTTPS da chiunque.
2. Consenti MySQL solo dalla subnet `172.29.0.0/24`, ma blocca `172.29.0.22` (attenzione all'ordine!).
3. Metti `ufw limit ssh` e scopri dopo quante connessioni ravvicinate scatta il blocco (`for i in $(seq 1 8); do nc -zv -w1 172.29.0.10 22; done`).
4. Blocca l'SMTP in uscita e verifica che le altre connessioni in uscita funzionino ancora.
5. Ricostruisci la stessa configurazione con `iptables` e confronta il numero di comandi.

## Note e troubleshooting

- Il ping funziona anche con `deny incoming`: è voluto (regole ICMP in `before.rules`). Per bloccarlo si modifica quel file, non basta una `ufw deny`.
- IPv6 è disattivato nel container (`IPV6=no` in `/etc/default/ufw`): in una macchina reale UFW applica le regole sia a IPv4 che a IPv6 e vedrai le righe `(v6)`.
- **Logging**: `ufw logging on` funziona, ma il log del kernel è condiviso con l'host e non c'è `/var/log/ufw.log` nel container. Su Linux: `dmesg -w | grep UFW` **sull'host**.
- **Docker e UFW**: Docker scrive direttamente in iptables e può aggirare le regole UFW per le porte pubblicate. Qui non succede perché nessuna porta è pubblicata sull'host, ma vale la pena citarlo agli studenti.
- Se `ufw enable` dà errori sul backend: `update-alternatives --set iptables /usr/sbin/iptables-legacy` nel server.
- `root` / `student` per SSH: **solo per il laboratorio**, rete isolata.
