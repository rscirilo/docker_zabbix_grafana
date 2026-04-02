cat > install_docker.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="/srv/monitoring"
DATA_DIR="/srv/docker"
DOCKER_DATA_ROOT="/srv/docker-data"
CONTAINERD_ROOT="/srv/containerd"
SERVER_IP="192.168.100.2"
TIMEZONE="America/Fortaleza"

ADMIN_PASS='@123Mudar'
GRAFANA_ADMIN_USER='admin'
GRAFANA_ADMIN_PASSWORD='@123Mudar'

ZABBIX_DB_NAME='zabbix'
ZABBIX_DB_USER='zabbix'
ZABBIX_DB_PASSWORD='@123Mudar'
MYSQL_ROOT_PASSWORD='@123Mudar'

GRAYLOG_PASSWORD_SECRET='MudarParaUmaStringGrandeSeguraComNoMinimo96Caracteres_1234567890_ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdef'
GRAYLOG_ROOT_PASSWORD_SHA2="$(echo -n '@123Mudar' | sha256sum | awk '{print $1}')"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root."
  exit 1
fi

echo "[1/11] Preparando sistema"
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo "[2/11] Desativando firewall local, se existir"
systemctl stop ufw 2>/dev/null || true
systemctl disable ufw 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

echo "[3/11] Criando estrutura base em /srv"
mkdir -p "${STACK_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${DOCKER_DATA_ROOT}"
mkdir -p "${CONTAINERD_ROOT}"
mkdir -p "${DATA_DIR}"/{portainer,grafana,mysql,zabbix-alertscripts,zabbix-externalscripts,zabbix-modules,zabbix-enc,zabbix-ssh_keys,zabbix-ssl-certs,zabbix-ssl-keys,zabbix-ssl-ca,zabbix-snmptraps,zabbix-mibs,mongodb,graylog-data,graylog-journal,opensearch-data}

echo "[4/11] Instalando Docker oficial"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.sources <<EOF2
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF2

apt remove -y docker.io docker-doc podman-docker containerd runc 2>/dev/null || true
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[5/11] Configurando Docker e containerd para usar /srv"
systemctl stop docker 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true

mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF2
{
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOF2

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's#root = "/var/lib/containerd"#root = "'"${CONTAINERD_ROOT}"'"#' /etc/containerd/config.toml

echo "[6/11] Reiniciando serviços"
systemctl daemon-reload
systemctl enable containerd
systemctl enable docker
systemctl restart containerd
systemctl restart docker

echo "[7/11] Ajustando kernel para Graylog/OpenSearch"
cat >/etc/sysctl.d/99-graylog.conf <<EOF2
vm.max_map_count=262144
EOF2
sysctl --system

echo "[8/11] Gravando .env"
cat > "${STACK_DIR}/.env" <<EOF2
TZ=${TIMEZONE}
SERVER_IP=${SERVER_IP}
ADMIN_PASS=${ADMIN_PASS}
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
ZABBIX_DB_NAME=${ZABBIX_DB_NAME}
ZABBIX_DB_USER=${ZABBIX_DB_USER}
ZABBIX_DB_PASSWORD=${ZABBIX_DB_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
GRAYLOG_PASSWORD_SECRET=${GRAYLOG_PASSWORD_SECRET}
GRAYLOG_ROOT_PASSWORD_SHA2=${GRAYLOG_ROOT_PASSWORD_SHA2}
EOF2

echo "[9/11] Gravando docker-compose.yml"
cat > "${STACK_DIR}/docker-compose.yml" <<'EOF2'
services:
  portainer:
    image: portainer/portainer-ce:sts
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /srv/docker/portainer:/data

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      TZ: ${TZ}
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - /srv/docker/grafana:/var/lib/grafana

  zabbix-db:
    image: mariadb:11.4
    container_name: zabbix-db
    restart: unless-stopped
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_bin
    environment:
      TZ: ${TZ}
      MYSQL_DATABASE: ${ZABBIX_DB_NAME}
      MYSQL_USER: ${ZABBIX_DB_USER}
      MYSQL_PASSWORD: ${ZABBIX_DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - /srv/docker/mysql:/var/lib/mysql

  zabbix-server:
    image: zabbix/zabbix-server-mysql:ubuntu-latest
    container_name: zabbix-server
    restart: unless-stopped
    depends_on:
      - zabbix-db
    ports:
      - "10051:10051"
    environment:
      TZ: ${TZ}
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: ${ZABBIX_DB_NAME}
      MYSQL_USER: ${ZABBIX_DB_USER}
      MYSQL_PASSWORD: ${ZABBIX_DB_PASSWORD}
    volumes:
      - /srv/docker/zabbix-alertscripts:/usr/lib/zabbix/alertscripts
      - /srv/docker/zabbix-externalscripts:/usr/lib/zabbix/externalscripts
      - /srv/docker/zabbix-modules:/var/lib/zabbix/modules
      - /srv/docker/zabbix-enc:/var/lib/zabbix/enc
      - /srv/docker/zabbix-ssh_keys:/var/lib/zabbix/ssh_keys
      - /srv/docker/zabbix-ssl-certs:/var/lib/zabbix/ssl/certs
      - /srv/docker/zabbix-ssl-keys:/var/lib/zabbix/ssl/keys
      - /srv/docker/zabbix-ssl-ca:/var/lib/zabbix/ssl/ssl_ca
      - /srv/docker/zabbix-snmptraps:/var/lib/zabbix/snmptraps
      - /srv/docker/zabbix-mibs:/var/lib/zabbix/mibs

  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql:ubuntu-latest
    container_name: zabbix-web
    restart: unless-stopped
    depends_on:
      - zabbix-server
      - zabbix-db
    ports:
      - "8082:8080"
    environment:
      TZ: ${TZ}
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: ${ZABBIX_DB_NAME}
      MYSQL_USER: ${ZABBIX_DB_USER}
      MYSQL_PASSWORD: ${ZABBIX_DB_PASSWORD}
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: ${TZ}

  mongodb:
    image: mongo:7
    container_name: graylog-mongodb
    restart: unless-stopped
    volumes:
      - /srv/docker/mongodb:/data/db

  opensearch:
    image: opensearchproject/opensearch:2
    container_name: graylog-opensearch
    restart: unless-stopped
    environment:
      discovery.type: single-node
      plugins.security.disabled: "true"
      bootstrap.memory_lock: "true"
      OPENSEARCH_JAVA_OPTS: -Xms512m -Xmx512m
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - /srv/docker/opensearch-data:/usr/share/opensearch/data

  graylog:
    image: graylog/graylog:6.3
    container_name: graylog
    restart: unless-stopped
    depends_on:
      - mongodb
      - opensearch
    entrypoint: /usr/bin/tini -- wait-for-it opensearch:9200 -- /docker-entrypoint.sh
    environment:
      TZ: ${TZ}
      GRAYLOG_PASSWORD_SECRET: ${GRAYLOG_PASSWORD_SECRET}
      GRAYLOG_ROOT_PASSWORD_SHA2: ${GRAYLOG_ROOT_PASSWORD_SHA2}
      GRAYLOG_HTTP_BIND_ADDRESS: 0.0.0.0:9000
      GRAYLOG_HTTP_EXTERNAL_URI: http://${SERVER_IP}:9000/
      GRAYLOG_MONGODB_URI: mongodb://mongodb:27017/graylog
      GRAYLOG_ELASTICSEARCH_HOSTS: http://opensearch:9200
    ports:
      - "9000:9000/tcp"
      - "1514:1514/udp"
      - "12201:12201/udp"
    volumes:
      - /srv/docker/graylog-data:/usr/share/graylog/data/data
      - /srv/docker/graylog-journal:/usr/share/graylog/data/journal

networks:
  default:
    name: monitoring-net
EOF2

echo "[10/11] Validando compose"
cd "${STACK_DIR}"
docker compose config >/dev/null

echo "[11/11] Pronto para executar"
echo "Arquivo criado e validado."
echo "Na próxima etapa, vamos apenas dar permissão e executar."
EOF
