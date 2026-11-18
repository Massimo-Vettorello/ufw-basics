# UFW Lab demo

Based on the topics of *UFW Essentials: Common Firewall Rules and Commands* (DigitalOcean):
status/enabling, default policies, blocking IPs, per-interface rules, SSH (also from specific IPs/subnets),
HTTP/HTTPS, rsync, MySQL/PostgreSQL, outgoing SMTP, port ranges, application profiles,
deleting rules, reset.

## Topology

| Container   | IP            | Role                                                        |
|-------------|---------------|-------------------------------------------------------------|
| ufw-server  | 172.29.0.10   | Server with UFW: SSH 22, HTTP 80, HTTPS 443, rsync 873, MySQL 3306, PostgreSQL 5432, 6000-6001 |
| ufw-client1 | 172.29.0.21   | Client 1 ("good student")                                   |
| ufw-client2 | 172.29.0.22   | Client 2 ("attacker": to be blocked)                        |

Isolated network `172.29.0.0/24`, different from the iptables lab (`172.28.0.0/24`): both labs can run at the same time.
UFW works only inside the server container's network namespace: **your host is not touched**.

## Getting started

```bash
docker compose up -d --build
docker exec -it ufw-server  bash   # terminal A (server)
docker exec -it ufw-client1 bash   # terminal B (client 1)
docker exec -it ufw-client2 bash   # terminal C (client 2)
```

Handy commands:
- server: `lab-show` (UFW rules + the generated iptables chain), `lab-reset` (UFW disabled, no rules)
- client: `check` (OPEN / REFUSED / TIMEOUT table)

Shut everything down: `docker compose down`.

## Demo outline

**0. Initial state** – (server) `ufw status` → `Status: inactive`. (client1) `check` → everything OPEN.

**1. Default policies and enabling** *(lockout!)*
```bash
ufw default deny incoming
ufw default allow outgoing
ufw enable                 # confirm with y
ufw status verbose
```
`check` from client1 → everything TIMEOUT, **except ping**: by default UFW accepts ICMP in `/etc/ufw/before.rules`.
Try `ssh root@172.29.0.10` (password `student`) → it hangs: without an SSH rule, on a real server you would lock yourself out.
> Message: `ufw allow ssh` *first*, `ufw enable` *after*. Here we can get back in with `docker exec`.

**2. SSH**
```bash
ufw allow ssh              # or: ufw allow 22
```
`check` → SSH OPEN. Try the SSH login from client1.

**3. HTTP and HTTPS (by service name and multiple ports)**
```bash
ufw allow http
ufw allow 443/tcp
# multi-port alternative:  ufw allow proto tcp from any to any port 80,443
```
`curl http://172.29.0.10` from client1.

**4. SSH from a specific IP or subnet only** (we replace the generic rule)
```bash
ufw status numbered
ufw delete <number of the port 22 rule>
ufw allow from 172.29.0.21 to any port 22 proto tcp
```
client1: SSH works; client2: SSH times out. Variant: `ufw allow from 172.29.0.0/24 to any port 22 proto tcp`.

**5. MySQL and PostgreSQL from a specific IP**
```bash
ufw allow from 172.29.0.21 to any port 3306 proto tcp
ufw allow from 172.29.0.21 to any port 5432 proto tcp
```
`nc -v 172.29.0.10 3306` → banner from client1, timeout from client2.

**6. rsync (873) from an IP or subnet**
```bash
ufw allow from 172.29.0.0/24 to any port 873 proto tcp
```

**7. Port ranges**
```bash
ufw allow 6000:6007/tcp     # a range always requires the protocol
```
`check` → 6000 and 6001 OPEN.

**8. Block an IP address**
```bash
ufw deny from 172.29.0.22
```
Watch the **order**: UFW evaluates from the top, the first matching rule wins.
If client2 is already covered by an `allow from 172.29.0.0/24`, a deny at the bottom is not enough:
```bash
ufw insert 1 deny from 172.29.0.22
ufw status numbered
```

**9. Block on a specific interface**
```bash
ufw deny in on eth0 from 172.29.0.22
```
Explain that `in on <interface>` can be added to any rule (useful with multiple network cards).

**10. DENY vs REJECT**
```bash
ufw reject 5432/tcp         # first remove any allow rule on 5432
```
`check` → 5432 "REFUSED" (immediate), the other blocked ports show "TIMEOUT".

**11. Outgoing traffic: block SMTP**
```bash
# client1:   nc -l -p 25
ufw deny out 25
# server:    nc -zv -w2 172.29.0.21 25   → timeout
```
Remove it with `ufw delete deny out 25` and retry: the connection goes through.

**12. Application profiles**
```bash
ufw app list
ufw app info LabDB
ufw allow LabWeb
```
(The `LabWeb` and `LabDB` profiles are created for the demo in `/etc/ufw/applications.d/lab-apps`. On Ubuntu you will also find `OpenSSH`, `Nginx Full`, etc.)

**13. Deleting rules**
```bash
ufw status numbered
ufw delete 2                # by number
ufw delete allow 443/tcp    # by rule
```

**14. Under the hood: UFW is a front-end for iptables**
```bash
lab-show
iptables -S | head -40
ufw show added
cat /etc/ufw/user.rules
```
Direct link to the iptables lab: same `ACCEPT/DROP`, `ufw-user-input` chains, `ufw-before-input`...

**15. Disabling and resetting**
```bash
ufw disable                 # turns the firewall off, rules are kept
ufw --force reset           # deletes everything (or: lab-reset)
```

## Student exercises

1. Set up a secure web server: default deny, SSH only from `172.29.0.21`, HTTP/HTTPS from anyone.
2. Allow MySQL only from the `172.29.0.0/24` subnet, but block `172.29.0.22` (watch the order!).
3. Enable `ufw limit ssh` and find out after how many rapid connections the block kicks in (`for i in $(seq 1 8); do nc -zv -w1 172.29.0.10 22; done`).
4. Block outgoing SMTP and check that other outgoing connections still work.
5. Rebuild the same configuration with `iptables` and compare the number of commands.

## Notes and troubleshooting

- Ping works even with `deny incoming`: this is intended (ICMP rules in `before.rules`). To block it you edit that file; a `ufw deny` is not enough.
- IPv6 is disabled in the container (`IPV6=no` in `/etc/default/ufw`): on a real machine UFW applies rules to both IPv4 and IPv6 and you will see `(v6)` lines.
- **Logging**: `ufw logging on` works, but the kernel log is shared with the host and there is no `/var/log/ufw.log` in the container. On Linux: `dmesg -w | grep UFW` **on the host**.
- **Docker and UFW**: Docker writes directly to iptables and can bypass UFW rules for published ports. This does not happen here because no ports are published on the host, but it is worth mentioning to students.
- If `ufw enable` gives backend errors: `update-alternatives --set iptables /usr/sbin/iptables-legacy` on the server.
- `root` / `student` for SSH: **lab use only**, isolated network.
