FROM debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ufw iptables iproute2 iputils-ping netcat-openbsd nginx openssh-server \
      tcpdump procps nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && echo 'root:student' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    # In container: niente IPv6 e niente caricamento moduli kernel
    && sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw \
    && sed -i 's/^IPT_MODULES=.*/IPT_MODULES=""/' /etc/default/ufw

# Profili applicativi personalizzati (per la demo di "ufw app list")
COPY lab-apps /etc/ufw/applications.d/lab-apps
COPY entrypoint.sh /entrypoint.sh
COPY lab-reset.sh /usr/local/bin/lab-reset
COPY lab-show.sh  /usr/local/bin/lab-show
RUN chmod +x /entrypoint.sh /usr/local/bin/lab-reset /usr/local/bin/lab-show \
    && echo '<h1>Server web del laboratorio UFW</h1>' > /var/www/html/index.html

ENTRYPOINT ["/entrypoint.sh"]
