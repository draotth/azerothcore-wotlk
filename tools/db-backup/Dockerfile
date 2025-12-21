FROM mysql:8.4

RUN set -eux; \
    if command -v microdnf >/dev/null 2>&1; then \
      microdnf install -y cronie tzdata && microdnf clean all; \
    elif command -v dnf >/dev/null 2>&1; then \
      dnf install -y cronie tzdata && dnf clean all; \
    elif command -v yum >/dev/null 2>&1; then \
      yum install -y cronie tzdata && yum clean all; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update -qq; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cron tzdata; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache mysql-client tzdata; \
    else \
      echo "No supported package manager found to install cron/tzdata" >&2; \
      exit 1; \
    fi

WORKDIR /opt/db-backup
COPY entrypoint.sh db-backup.sh ./
RUN chmod +x /opt/db-backup/entrypoint.sh /opt/db-backup/db-backup.sh

ENTRYPOINT ["/opt/db-backup/entrypoint.sh"]

