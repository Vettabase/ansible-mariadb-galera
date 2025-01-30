# Vettabase: Ansible-Based Deployment for MariaDB Galera Cluster

This setup provides an Ansible-Based Deployment for MariaDB Galera Cluster with fully containerized local testing environment using Docker Compose. It includes a Jumphost, ProxySQL container and three Galera nodes, all running Ubuntu 24.04 LTS.

## Prerequisites

1. **Docker**: Ensure Docker is installed and running.
2. **Docker Compose**: Ensure Docker Compose is installed.

---

## Steps to Use

You can also use `local-rebuild-docker.sh` to rebuild the local Docker stack. In thie case you can skip 7 steps and start working with ansible playbooks.

### 1. Create Vault

#### Create the Vault Password File:

Create a file named local-vaultpass.txt and add your desired vault password to it:
```bash
echo 'YOUR_VAULT_PARSSWORD' > vaultpass.txt
```

Make sure to secure the file permissions so only you can access it:
```bash
chmod 600 vaultpass.txt
```

#### Create General Vaults File

Use the ansible-vault command to create `group_vars/all/vault.yml`:
```bash
ansible-vault create group_vars/all/vault.yml --vault-id default@vaultpass.txt --encrypt-vault-id default
```

Add your local secrets inside the vault. 

Example content:
```bash
vault_ansible_ssh_user: ansuser
vault_ansible_ssh_pswd: random123
```

#### Create DB Vaults File

Use the ansible-vault command to create `group_vars/group_local_db/vault.yml`:
```bash
ansible-vault create group_vars/group_local_db/vault.yml --vault-id default@vaultpass.txt --encrypt-vault-id default
```

Add your local DB secrets inside the vault. 

Example content:
```bash
# MariaDB Group - Vault Variables
var_vault_group_mariadb_user: root
var_vault_group_mariadb_password: rootDB321

# Galera Group - Vault Variables
var_vault_group_galera_user: sst
var_vault_group_galera_password: sstDB321
```

### 2. Generate SSH-Key

Run the following command to create a new key pair specifically for your Ansible setup:
```bash
ssh-keygen -t ed25519 -f id_ed25519_vettabase_ansible_mariadb -C "ansible_mariadb" -q
```

- -t ed25519: Specifies the key type.
- -f ~/.ssh/id_ed25519_vettabase_ansible_mariadb: Specifies the file to save the key to.
- -C "ansible_mariadb": Adds a comment to the key for identification.
- -q: Suppresses the output to make it silent.

You’ll be prompted to enter a passphrase. If you want to secure the key with a passphrase, you can do so. Leave it empty for no passphrase.

In my case I created it with passphrase

#### Add Key info to Vault

```bash
ansible-vault edit group_vars/all/vault.yml --vault-id default@vaultpass.txt --encrypt-vault-id default
```

Add key info `vault_ansible_ssh_key` to the end of file, for example:
```bash
vault_ansible_ssh_key:  'id_ed25519_vettabase_ansible_mariadb'
vault_ansible_ssh_key_pswd: REPLACEWITHYOURKEYPASSPHRASE
```

#### Load SSH key

```bash
ssh-add id_ed25519_vettabase_ansible_mariadb
```

### 3. Build the Docker Image

Build the custom Docker image:
```bash
docker build --tag localhost/vettabase-ansible:latest --file local-Dockerfile . --no-cache
```

There are defaults passwort here:
- root:admin321
- ansuser:random321

They will be changed by `initial` runbook

### 4. Start the Containers

Bring up the containers using Docker Compose:
```bash
docker-compose --file local-docker-compose.yml up --detach
```

### 5. Verify the Containers

Check the running containers:
```bash
docker ps
```

You should see the following containers:
- jumphost (IP: 172.10.1.2, Port: 2202)
- proxysql (IP: 172.10.1.10, Port: 2210)
- galera1 (IP: 172.10.1.21, Port: 2221)
- galera2 (IP: 172.10.1.22, Port: 2222)
- galera3 (IP: 172.10.1.23, Port: 2223)

### 6. Verify connnection to jumphost

```bash
ssh-keyscan -p 2202 127.0.0.1 >> ~/.ssh/known_hosts
ssh -i id_ed25519_vettabase_ansible_mariadb ansuser@127.0.0.1 -p 2202 hostname
```

### 7. Test Ansible Connectivity

Ensure Ansible can communicate with the containers:
```bash
ansible group_local --module-name ping
```

Expected output:
```bash
vettabase-ansible-jumphost | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
vettabase-ansible-galera1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
vettabase-ansible-proxysql | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
vettabase-ansible-galera2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
vettabase-ansible-galera3 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 8. Run Playbooks

Run your playbooks against the local inventory:
```bash
ansible-playbook -i inventory.yml playbooks/mariadb.yml --extra-vars target_hosts=group_local_db
```

Restart Only:
```bash
ansible-playbook -i inventory.yml playbooks/mariadb.yml --extra-vars target_hosts=group_local_db --start-at-task="Restarting"
```

## Destroying the Infrastructure

### 1. Stop and Remove Containers, Networks, and Volumes

Use the docker-compose down command with the custom file:
```bash
docker-compose --file local-docker-compose.yml down
docker image prune --all --force
```

This will:
- Stop all running containers.
- Remove the containers and associated networks.

### 2. Remove Unused Docker Resources (Optional)

If you want to remove unused volumes and dangling images to free up space, run:
```bash
docker system prune -f --volumes
```

This will:
- Remove all unused networks, containers, and images.
- Delete any orphaned Docker volumes.

### 3. Verify Cleanup

Check that no containers or networks are running:
```bash
docker ps -a
docker network ls
```

## Notes

- Containers are configured with static IPs to match the inventory.
- All SSH dependencies are pre-installed in the custom image (local-Dockerfile).
- Ports are exposed for testing if needed:
  - ProxySQL: 2210
  - Galera1: 2221
  - Galera2: 2222
  - Galera3: 2223

- **Data Loss:** If you’re using Docker volumes for persistent data, ensure you’ve backed up any critical data before using docker system prune --volumes.
- **Custom Cleanup:** If you’re using specific Docker resources (e.g., named volumes or external networks), ensure those are explicitly removed or preserved as needed.

---

Copyright 2025 Vettabase Ltd and contributors.

[ansible-mariadb-galera](https://github.com/Vettabase/ansible-mariadb-galera) is licensed under [CC BY-SA 4.0 license](https://creativecommons.org/licenses/by-sa/4.0/).
