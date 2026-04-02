# IMPORTANTE
Teste executado com sucesso, caso você encontre algum erro na sua instalação, pesquise e procure entender como funciona cada um dos serviços, estudem os erros, não estou disponivel para tirar dúvidas - Rodrigo Cirilo.
# docker_zabbix_grafana

Ambiente de monitoramento completo utilizando Docker e Docker Compose, com os serviços:

- Graylog
- Zabbix
- Grafana
- Portainer
- MariaDB
- MongoDB
- OpenSearch

Este repositório contém uma stack pronta para uso em laboratório, testes e monitoramento, com persistência de dados em `/srv`.

---

## Visão geral

Este projeto foi criado para facilitar a subida de um ambiente de monitoramento completo em uma VM Linux, especialmente em laboratório com VirtualBox.

A stack publica os principais serviços nas seguintes portas:

- Graylog: `9000`
- Zabbix: `8082`
- Grafana: `3001`
- Portainer: `9443`

---

## Serviços incluídos

| Serviço | Porta | URL de acesso |
|---|---:|---|
| Graylog | 9000 | `http://IP-DA-VM:9000` |
| Zabbix | 8082 | `http://IP-DA-VM:8082` |
| Grafana | 3001 | `http://IP-DA-VM:3001` |
| Portainer | 9443 | `https://IP-DA-VM:9443` |
| OpenSearch | 9200 | `http://IP-DA-VM:9200` |

---

## Ambiente validado

Este ambiente foi testado em:

- Debian Trixie
- VM no VirtualBox
- Instalação via terminal
- Docker Engine com Docker Compose Plugin
- Persistência de dados em `/srv`

---

## Requisitos

- VirtualBox instalado
- ISO do Debian Server
- Acesso à internet na VM
- IP estático configurado na VM

### Recomendação de recursos da VM

- 4 vCPU
- 8 GB de RAM
- 40 GB de disco ou mais

---

## Estrutura utilizada

Os dados da stack ficam nestes diretórios:

```bash
/srv/monitoring
/srv/docker
/srv/docker-data
/srv/containerd
```

---

## Scripts de instalação

Este projeto possui **dois scripts** de instalação.

### 1. `install_docker.sh`

Use este script em VMs ou servidores cuja CPU tenha suporte a **AVX**.

### 2. `install_docker2.sh`

Use este script em **qualquer VM**, inclusive ambientes mais antigos, laboratórios no VirtualBox ou CPUs sem suporte a AVX.

---

## O que é AVX

AVX (*Advanced Vector Extensions*) é um conjunto de instruções do processador.

Algumas aplicações mais novas podem depender desse recurso para funcionar corretamente. Por isso, este projeto possui dois scripts de instalação, separados por compatibilidade.

---

## Como verificar se a VM possui AVX

No Linux, execute:

```bash
grep -m1 -o avx /proc/cpuinfo
```

### Resultado

- Se aparecer `avx`, a VM/CPU possui suporte e você pode usar o `install_docker.sh`
- Se não aparecer nada, use o `install_docker2.sh`

---

## Como subir em uma VM no VirtualBox

### 1. Criar a VM

Crie uma VM Linux no VirtualBox com uma configuração próxima desta:

- Nome: `docker-monitoring`
- Tipo: `Linux`
- Versão: `Debian (64-bit)`
- Memória: `8192 MB`
- CPU: `4 vCPU`
- Disco: `40 GB` ou maior

### 2. Configurar rede no VirtualBox

Para que a VM fique acessível pela rede local, configure:

- **Adaptador 1:** Placa em modo **Bridge**

Isso permite acessar Graylog, Zabbix, Grafana e Portainer diretamente pelo IP da VM.

### 3. Instalar o Debian

Instale o Debian normalmente em modo servidor.

Se desejar, habilite SSH durante a instalação para facilitar a administração remota.

### 4. Configurar IP estático

Exemplo utilizado neste projeto:

```bash
192.168.100.2
```

Ajuste esse IP de acordo com a sua rede local.

### 5. Clonar o repositório

```bash
git clone https://github.com/rscirilo/docker_zabbix_grafana.git
cd docker_zabbix_grafana
```

### 6. Escolher o script correto

#### Para VM com AVX

```bash
chmod +x install_docker.sh
./install_docker.sh
```

#### Para qualquer VM

```bash
chmod +x install_docker2.sh
./install_docker2.sh
```

---

## O que o script faz

O script realiza automaticamente:

- Instalação do Docker oficial
- Instalação do Docker Compose Plugin
- Criação das pastas em `/srv`
- Desativação do firewall local
- Ajuste de `vm.max_map_count`
- Criação do arquivo `.env`
- Criação do `docker-compose.yml`
- Download das imagens
- Subida dos containers

---

## Subindo manualmente com Docker Compose

Se os arquivos já estiverem prontos, você também pode subir manualmente com:

```bash
docker compose up -d
```

Para verificar os containers:

```bash
docker compose ps
```

Para ver logs em caso de erro:

```bash
docker compose logs -f
```

---

## Acessos

Após a instalação, acesse:

- **Graylog:** `http://IP-DA-VM:9000`
- **Zabbix:** `http://IP-DA-VM:8082`
- **Grafana:** `http://IP-DA-VM:3001`
- **Portainer:** `https://IP-DA-VM:9443`

---

## Credenciais iniciais

### Graylog

- Usuário: `admin`
- Senha: `@123Mudar`

### Grafana

- Usuário: `admin`
- Senha: `@123Mudar`

### Zabbix

Login inicial padrão:

- Usuário: `Admin`
- Senha: `zabbix`

> Atenção: o usuário do Zabbix é `Admin` com **A maiúsculo**.

### Portainer

No primeiro acesso, o Portainer solicita a criação do usuário administrador.

Se você não concluir isso em até alguns minutos, a instância pode entrar em timeout por segurança. Nesse caso, reinicie o container:

```bash
docker restart portainer
```

ou:

```bash
cd /srv/monitoring
docker compose restart portainer
```

Depois disso, acesse novamente:

```bash
https://IP-DA-VM:9443
```

---

## Portas utilizadas

| Serviço | Porta host | Observação |
|---|---:|---|
| Graylog Web | 9000 | Interface web |
| Graylog Syslog UDP | 1514 | Entrada syslog |
| Graylog GELF UDP | 12201 | Entrada GELF |
| Zabbix Web | 8082 | Interface web |
| Zabbix Server | 10051 | Porta do servidor Zabbix |
| Grafana | 3001 | Interface web |
| Portainer | 9443 | Interface HTTPS |
| Portainer Edge | 8000 | Edge Agent |
| OpenSearch | 9200 | API HTTP |

---

## Observações importantes

- O ambiente foi ajustado para uso em laboratório e testes
- Todos os dados ficam persistidos em `/srv`
- O Graylog depende de MongoDB e OpenSearch
- O OpenSearch precisa de `vm.max_map_count=262144`
- Se o Graylog reiniciar em loop, verifique as permissões dos diretórios:
  - `/srv/docker/graylog-data`
  - `/srv/docker/graylog-journal`

---

## Comandos úteis

### Ver status dos containers

```bash
cd /srv/monitoring
docker compose ps
```

### Ver logs

```bash
cd /srv/monitoring
docker compose logs --tail 100
```

### Reiniciar um serviço específico

```bash
cd /srv/monitoring
docker compose restart graylog
docker compose restart zabbix-web
docker compose restart grafana
docker compose restart portainer
```

### Parar tudo

```bash
cd /srv/monitoring
docker compose down
```

### Subir tudo novamente

```bash
cd /srv/monitoring
docker compose up -d
```

---

## Compatibilidade

No Debian Trixie, alguns pacotes antigos usados em scripts mais velhos podem não estar disponíveis.

Por isso, mantenha os scripts atualizados e prefira o `install_docker2.sh` quando quiser maior compatibilidade entre diferentes VMs.

---

## Contribuições

Contribuições são bem-vindas.
