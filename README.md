# IMPORTANTE

Teste executado com sucesso. Caso você encontre algum erro na sua instalação, pesquise e procure entender como funciona cada um dos serviços, estude os erros. Não estou disponível para tirar dúvidas.  
**Autor:** Rodrigo Cirilo.

---

# docker_zabbix_grafana

Ambiente de monitoramento completo utilizando Docker e Docker Compose, com os serviços:

- Graylog
- Zabbix
- Grafana
- Portainer
- MariaDB (para Zabbix)
- MongoDB (para Graylog)
- OpenSearch (para Graylog)
- GLPI (em alguns scripts)

Este repositório contém uma stack pronta para uso em laboratório, testes e monitoramento, com persistência de dados em `/srv`.

---

## Visão geral

Este projeto foi criado para facilitar a subida de um ambiente de monitoramento completo em uma VM Linux, especialmente em laboratório com VirtualBox.

As stacks publicam os principais serviços nas seguintes portas padrão:

- Graylog: `9000`
- Zabbix: `8082`
- Grafana: `3001`
- Portainer: `9443`
- GLPI (quando presente): `8181`

Alguns scripts utilizam a rede Docker padrão, outros utilizam uma rede bridge dedicada `10.30.40.0/24`.

---

## Serviços incluídos

| Serviço   | Porta | URL de acesso                |
|----------|------:|------------------------------|
| Graylog  | 9000  | `http://IP-DA-VM:9000`       |
| Zabbix   | 8082  | `http://IP-DA-VM:8082`       |
| Grafana  | 3001  | `http://IP-DA-VM:3001`       |
| Portainer| 9443  | `https://IP-DA-VM:9443`      |
| GLPI     | 8181  | `http://IP-DA-VM:8181`       |
| OpenSearch (quando exposto) | 9200 | `http://IP-DA-VM:9200` |

---

## Ambiente validado

Este ambiente foi testado em:

- Debian Trixie
- VM no VirtualBox
- Instalação via terminal (SSH ou console)
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

Dentro de `/srv/docker` são criados subdiretórios para cada serviço (grafana, mongodb, mysql, opensearch-data, graylog-data, graylog-journal, glpi-mysql, glpi-files, etc., dependendo do script).

---

## Scripts de instalação

Atualmente este repositório possui **6 scripts**, divididos entre VMs **com AVX** e VMs **sem AVX**, e com ou sem GLPI/rede dedicada.

### Resumo dos scripts

| Script                           | AVX?        | Rede Docker          | Serviços principais                         |
|----------------------------------|------------|----------------------|---------------------------------------------|
| `install_avx.sh`                 | Com AVX    | rede padrão Docker   | Portainer, Graylog, Zabbix, Grafana         |
| `install_avx2_rede_10.sh`        | Com AVX    | `10.30.40.0/24`      | Portainer, Graylog, Zabbix, Grafana         |
| `install_avx_lan_10_glpi`        | Com AVX    | `10.30.40.0/24`      | Portainer, Graylog, Zabbix, Grafana, GLPI   |
| `install_compact_rede_10.sh`     | Sem AVX    | `10.30.40.0/24`      | Portainer, Graylog, Zabbix, Grafana         |
| `install_compact_rede_10_glpi.sh`| Sem AVX    | `10.30.40.0/24`      | Portainer, Graylog, Zabbix, Grafana, GLPI   |
| `install_docker_compat.sh`       | Sem AVX    | rede padrão Docker   | Portainer, Graylog, Zabbix, Grafana         |

Escolha o script de acordo com:

1. Se a VM expõe **AVX** ou não.
2. Se você quer ou não uma rede Docker dedicada `10.30.40.0/24`.
3. Se precisa ou não do **GLPI** na mesma stack.

---

## O que é AVX

AVX (*Advanced Vector Extensions*) é um conjunto de instruções do processador.

Alguns componentes mais novos (principalmente versões recentes de banco/engine de busca) podem se beneficiar ou exigir esse recurso. Por isso existem versões de scripts pensadas para VMs com AVX e para ambientes compatíveis sem AVX.

---

## Como verificar se a VM possui AVX

No Linux, execute:

```bash
lscpu | grep -i avx
```

ou:

```bash
grep -o 'avx[^ ]*' /proc/cpuinfo | sort -u
```

### Resultado

- Se aparecer `avx` (e/ou `avx2`) na saída, a VM/CPU possui suporte e você pode usar os scripts `install_avx*`.
- Se não aparecer nada, utilize os scripts de **compatibilidade** (`install_compact_rede_10*.sh` ou `install_docker_compat.sh`).

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

Isso permite acessar Graylog, Zabbix, Grafana, Portainer e GLPI diretamente pelo IP da VM.

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

---

## Escolhendo o script correto

### VMs **com AVX**

- Stack básica (sem rede 10.30.40.0/24, sem GLPI):

```bash
chmod +x install_avx.sh
./install_avx.sh
```

- Stack com rede Docker `10.30.40.0/24` (sem GLPI):

```bash
chmod +x install_avx2_rede_10.sh
./install_avx2_rede_10.sh
```

- Stack com rede `10.30.40.0/24` **e GLPI**:

```bash
chmod +x install_avx_lan_10_glpi
./install_avx_lan_10_glpi
```

### VMs **sem AVX** (compatibilidade)

- Stack compacta com rede Docker `10.30.40.0/24` (sem GLPI):

```bash
chmod +x install_compact_rede_10.sh
./install_compact_rede_10.sh
```

- Stack compacta com rede `10.30.40.0/24` **e GLPI**:

```bash
chmod +x install_compact_rede_10_glpi.sh
./install_compact_rede_10_glpi.sh
```

- Stack compatível básica (sem rede dedicada, sem GLPI):

```bash
chmod +x install_docker_compat.sh
./install_docker_compat.sh
```

---

## O que os scripts fazem

Os scripts realizam automaticamente:

- Instalação do Docker oficial
- Instalação do Docker Compose Plugin
- Criação das pastas em `/srv`
- Desativação do firewall local (UFW/Firewalld)
- Ajuste de `vm.max_map_count` para OpenSearch
- Criação do arquivo `.env`
- Criação do `docker-compose.yml`
- Download das imagens
- Subida dos containers

---

## Subindo manualmente com Docker Compose

Se os arquivos já estiverem prontos em `/srv/monitoring`, você também pode subir manualmente:

```bash
cd /srv/monitoring
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
- **GLPI (quando presente):** `http://IP-DA-VM:8181`

---

## Credenciais iniciais

### Graylog

- Usuário: `admin`
- Senha: `@123Mudar` (valor de `ADMIN_PASS` definido no script)

### Grafana

- Usuário: `admin` (valor de `GRAFANA_ADMIN_USER`)
- Senha: `@123Mudar` (valor de `GRAFANA_ADMIN_PASSWORD` / `ADMIN_PASS`)

### Zabbix

Login inicial padrão:

- Usuário: `Admin`
- Senha: `zabbix`

> Atenção: o usuário do Zabbix é `Admin` com **A maiúsculo**.

### GLPI (quando instalado)

Após a instalação inicial via wizard do GLPI, os logins padrão são:

- Usuário administrador: `glpi` / `glpi`
- Outros usuários padrão (técnico, normal, post-only) podem existir conforme a documentação oficial.

**Recomendado:** trocar a senha do usuário `glpi` logo após o primeiro acesso.

### Portainer

No primeiro acesso, o Portainer solicita a criação do usuário administrador.

Se você não concluir isso em até alguns minutos, a instância pode entrar em timeout por segurança. Nesse caso, reinicie o container:

```bash
docker restart portainer
# ou
cd /srv/monitoring
docker compose restart portainer
```

Depois disso, acesse novamente:

```bash
https://IP-DA-VM:9443
```

---

## Portas utilizadas

| Serviço            | Porta host | Observação          |
|--------------------|-----------:|---------------------|
| Graylog Web        | 9000       | Interface web       |
| Graylog Syslog UDP | 1514       | Entrada syslog      |
| Graylog GELF UDP   | 12201      | Entrada GELF        |
| Zabbix Web         | 8082       | Interface web       |
| Zabbix Server      | 10051      | Porta do servidor   |
| Grafana            | 3001       | Interface web       |
| Portainer          | 9443       | Interface HTTPS     |
| Portainer Edge     | 8000       | Edge Agent          |
| OpenSearch         | 9200       | API HTTP (quando exposta) |
| GLPI               | 8181       | Interface web       |

---

## Observações importantes

- O ambiente foi ajustado para uso em laboratório e testes.
- Todos os dados ficam persistidos em `/srv`.
- O Graylog depende de MongoDB e OpenSearch.
- O OpenSearch precisa de `vm.max_map_count=262144`.
- Se o Graylog reiniciar em loop, verifique as permissões dos diretórios:
  - `/srv/docker/graylog-data`
  - `/srv/docker/graylog-journal`
- Em ambientes sem AVX, utilize sempre os scripts de compatibilidade (`compat` / `compact`) para evitar problemas com imagens mais recentes.

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
docker compose restart glpi
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

No Debian Trixie, alguns pacotes usados em scripts antigos podem não estar disponíveis.

Por isso, mantenha os scripts atualizados e utilize:

- Scripts `install_avx*` em ambientes onde AVX/AVX2 está disponível.
- Scripts `install_compact_*` ou `install_docker_compat.sh` em ambientes sem AVX (ex.: VMs em laboratórios, CPUs antigas ou com flags limitados).

---

## Contribuições

Contribuições são bem-vindas.  
Sinta-se à vontade para abrir PRs com ajustes de compatibilidade, melhorias de segurança, ou novos perfis de instalação (por exemplo, apenas Zabbix + Grafana, ou apenas Graylog).
