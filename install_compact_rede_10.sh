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
GRAYLOG_ROOT_PASSWORD_SHA2="$(printf '%s' '@123Mudar' | sha256sum | awk '{print $1}')"

# Rede interna Docker da stack
DOCKER_NET_NAME='monitoring-net'
DOCKER_NET_SUBNET='10.30.40.0/24'
DOCKER_NET_GATEWAY='10.30.40.1'

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root."
  exit 1
fi

echo "=================================================="
echo " INSTALACAO COMPLETA: Docker + Graylog + Zabbix +"
echo " Grafana + Portainer em /srv"
echo "=================================================="

echo "[1/14] Preparando sistema"
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo "[2/14] Desativando firewall local"
systemctl stop ufw 2>/dev/null || true
systemctl disable ufw 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

echo "[3/14] Criando estrutura em /srv"
mkdir -p "${STACK_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${DOCKER_DATA_ROOT}"
mkdir -p "${CONTAINERD_ROOT}"

for d in \
  portainer \
  grafana \
  mysql \
  zabbix-alertscripts \
  zabbix-externalscripts \
  zabbix-modules \
  zabbix-enc \
  zabbix-ssh_keys \
  zabbix-ssl-certs \
  zabbix-ssl-keys \
  zabbix-ssl-ca \
  zabbix-snmptraps \
  zabbix-mibs \
  mongodb \
  graylog-data \
  graylog-journal \
  opensearch-data
do
  mkdir -p "${DATA_DIR}/${d}"
done

echo "[4/14] Removendo pacotes conflitantes antigos"
apt remove -y docker.io docker-doc podman-docker containerd runc 2>/dev/null || true

echo "[5/14] Instalando Docker oficial"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[6/14] Configurando Docker para usar /srv"
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF

echo "[7/14] Configurando containerd para usar /srv"
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i "s#^root = .*#root = '${CONTAINERD_ROOT}'#" /etc/containerd/config.toml
sed -i "s#^state = .*#state = '/run/containerd'#g" /etc/containerd/config.toml

echo "[8/14] Reiniciando servicos"
systemctl daemon-reload
systemctl enable containerd
systemctl enable docker
systemctl restart containerd
systemctl restart docker

echo "[9/14] Ajustando sysctl para OpenSearch"
cat >/etc/sysctl.d/99-opensearch.conf <<EOF
vm.max_map_count=262144
EOF
sysctl --system

echo "[10/14] Ajustando permissoes dos volumes"
chown -R 472:472 /srv/docker/grafana || true
chown -R 999:999 /srv/docker/mongodb || true
chown -R 1000:1000 /srv/docker/opensearch-data || true
chown -R 1100:1100 /srv/docker/graylog-data /srv/docker/graylog-journal || true

chmod -R 775 /srv/docker/grafana || true
chmod -R 775 /srv/docker/mongodb || true
chmod -R 775 /srv/docker/opensearch-data || true
chmod -R 775 /srv/docker/graylog-data /srv/docker/graylog-journal || true

echo "[11/14] Gravando .env"
cat > "${STACK_DIR}/.env" <<EOF
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
EOF

echo "[12/14] Gravando docker-compose.yml"
cat > "${STACK_DIR}/docker-compose.yml" <<COMPOSEEOF
services:
  portainer:
    image: portainer/portainer-ce:lts
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /srv/docker/portainer:/data
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      TZ: \${TZ}
      GF_SECURITY_ADMIN_USER: \${GRAFANA_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: \${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - /srv/docker/grafana:/var/lib/grafana
    networks:
      - monitoring

  zabbix-db:
    image: mariadb:11.4
    container_name: zabbix-db
    restart: unless-stopped
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_bin
    environment:
      TZ: \${TZ}
      MYSQL_DATABASE: \${ZABBIX_DB_NAME}
      MYSQL_USER: \${ZABBIX_DB_USER}
      MYSQL_PASSWORD: \${ZABBIX_DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
    volumes:
      - /srv/docker/mysql:/var/lib/mysql
    networks:
      - monitoring

  zabbix-server:
    image: zabbix/zabbix-server-mysql:ubuntu-latest
    container_name: zabbix-server
    restart: unless-stopped
    depends_on:
      - zabbix-db
    ports:
      - "10051:10051"
    environment:
      TZ: \${TZ}
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: \${ZABBIX_DB_NAME}
      MYSQL_USER: \${ZABBIX_DB_USER}
      MYSQL_PASSWORD: \${ZABBIX_DB_PASSWORD}
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
    networks:
      - monitoring

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
      TZ: \${TZ}
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: \${ZABBIX_DB_NAME}
      MYSQL_USER: \${ZABBIX_DB_USER}
      MYSQL_PASSWORD: \${ZABBIX_DB_PASSWORD}
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: \${TZ}
    networks:
      - monitoring

  mongodb:
    image: mongo:4.4.18
    container_name: graylog-mongodb
    restart: unless-stopped
    volumes:
      - /srv/docker/mongodb:/data/db
    networks:
      - monitoring

  opensearch:
    image: opensearchproject/opensearch:1.3.4
    container_name: graylog-opensearch
    restart: unless-stopped
    environment:
      discovery.type: "single-node"
      plugins.security.disabled: "true"
      bootstrap.memory_lock: "true"
      OPENSEARCH_JAVA_OPTS: "-Xms512m -Xmx512m"
      DISABLE_INSTALL_DEMO_CONFIG: "true"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    ports:
      - "9200:9200"
    volumes:
      - /srv/docker/opensearch-data:/usr/share/opensearch/data
    networks:
      - monitoring

  graylog:
    image: graylog/graylog:4.3.15
    container_name: graylog
    user: "1100:1100"
    restart: unless-stopped
    depends_on:
      - mongodb
      - opensearch
    environment:
      TZ: \${TZ}
      GRAYLOG_PASSWORD_SECRET: \${GRAYLOG_PASSWORD_SECRET}
      GRAYLOG_ROOT_PASSWORD_SHA2: \${GRAYLOG_ROOT_PASSWORD_SHA2}
      GRAYLOG_HTTP_BIND_ADDRESS: 0.0.0.0:9000
      GRAYLOG_HTTP_EXTERNAL_URI: http://\${SERVER_IP}:9000/
      GRAYLOG_MONGODB_URI: mongodb://mongodb:27017/graylog
      GRAYLOG_ELASTICSEARCH_HOSTS: http://opensearch:9200
      GRAYLOG_SERVER_JAVA_OPTS: "-Xms512m -Xmx512m"
    ports:
      - "9000:9000/tcp"
      - "1514:1514/udp"
      - "12201:12201/udp"
    volumes:
      - /srv/docker/graylog-data:/usr/share/graylog/data/data
      - /srv/docker/graylog-journal:/usr/share/graylog/data/journal
    networks:
      - monitoring

networks:
  monitoring:
    name: ${DOCKER_NET_NAME}
    driver: bridge
    ipam:
      config:
        - subnet: ${DOCKER_NET_SUBNET}
          gateway: ${DOCKER_NET_GATEWAY}
COMPOSEEOF

echo "[13/14] Validando compose e baixando imagens"
cd "${STACK_DIR}"
docker compose config >/dev/null
docker compose pull

echo "[14/14] Subindo stack"
docker compose up -d

echo
echo "==================== ACESSOS ===================="
echo "Graylog   : http://${SERVER_IP}:9000"
echo "Zabbix    : http://${SERVER_IP}:8082"
echo "Grafana   : http://${SERVER_IP}:3001"
echo "Portainer : https://${SERVER_IP}:9443"
echo "================================================="
echo "Rede Docker  : ${DOCKER_NET_NAME} (${DOCKER_NET_SUBNET})"
echo "Gateway      : ${DOCKER_NET_GATEWAY}"
echo
echo "Credenciais iniciais:"
echo "Grafana   : ${GRAFANA_ADMIN_USER} / ${GRAFANA_ADMIN_PASSWORD}"
echo "Graylog   : admin / ${ADMIN_PASS}"
echo "Zabbix    : Admin / zabbix"
echo "Portainer : criar usuario admin no primeiro acesso"
echo
echo "IMPORTANTE: altere as senhas padrao apos o primeiro login."
echo
docker compose ps
