# docker_zabbix_grafana

# containers

Ambiente de monitoramento completo utilizando Docker e Docker Compose.

Este repositório contém uma stack pronta para uso com **Zabbix**, **Grafana** e **MySQL**, totalmente integrados, incluindo o plugin oficial do **Zabbix para Grafana** já configurado.

## Requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado  
- [Docker Compose](https://docs.docker.com/compose/install/) instalado  
- Ubuntu Server 24.04 (testado e validado)

## Como usar

Clone este repositório:

```bash
git clone https://github.com/rscirilo/docker_zabbix_grafana.git
cd  docker_zabbix_grafana
```

Suba o ambiente com:

```bash
docker-compose up -d
```

Os containers serão criados e configurados automaticamente.

## Serviços incluídos

| Serviço   | Porta padrão | Observações                                        |
|-----------|--------------|----------------------------------------------------|
| Graylog   | 9000         | Interface Web de Logs                             |
| Zabbix    | 8082         | Interface Web de monitoramento                    |
| Grafana   | 3001         | Dashboard com plugin Zabbix já instalado          |
| MySQL     | 3306         | Banco de dados usado pelo Zabbix                  |
| Portainer | 9443         | Portainer                  |

> **Importante:** O plugin do Zabbix já está instalado no Grafana e configurado para conexão automática com o banco de dados.

## Acesso

- **Zabbix Web:** `http://<IP-DO-SERVIDOR>:8080`
- **Grafana Web:** `http://<IP-DO-SERVIDOR>:3000`
- **Portaine Web:** `http://<IP-DO-SERVIDOR>:9443`  
  - Usuário padrão: `admin`  
  - Senha padrão: `admin`

## Observações

- Todos os ambientes foram testados no **Ubuntu Server 24.04 LTS**.
- Use `sudo` se necessário ao executar comandos com Docker.

##SUBINDO O AMBIENTE:

## Salvar o arquivo e subir
docker compose up -d

# Verificar se os containers estão rodando
docker compose ps

# Ver logs em caso de erro
docker compose logs -f

---
# Usando o arquivo install.sh

Use assim:

```bash
chmod +x install_docker.sh
./install_docker.sh
```
Ou sem dar permissão de execução:

```bash
bash install_docker.sh
```
Para evitar erro de permissão, eu sugiro este bloco completo:

```bash
chmod +x install_docker.sh
./install_docker.sh
```

Contribuições são bem-vindas!
