FROM debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      iproute2 iputils-ping netcat-openbsd curl nmap openssh-client sshpass \
      procps ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY check.sh /usr/local/bin/check
RUN chmod +x /usr/local/bin/check

CMD ["sleep", "infinity"]
