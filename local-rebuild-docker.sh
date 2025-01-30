#!/bin/bash

# Stop Docker Compose
docker-compose --file local-docker-compose.yml down

# Remove Image
docker rmi -f localhost/vettabase-ansible:latest

# Remove hosts:ports from known_hosts
ports="
  2202
  2210
  2221
  2222
  2223
"

for port in $ports; do
  ssh-keygen -R "[127.0.0.1]:$port"
done

# Build the custom Docker image:
docker build --tag localhost/vettabase-ansible:latest --file local-Dockerfile . --no-cache

# Start Docker Compose
docker-compose --file local-docker-compose.yml up --detach

# Check the running containers
docker ps

# Verify the SSH connection to Jump Host
ssh-keyscan -p 2202 127.0.0.1 >> ~/.ssh/known_hosts
ssh -i id_ed25519_vettabase_ansible_mariadb ansuser@127.0.0.1 -p 2202 hostname

# Test Ansible Connectivity
ansible group_local --module-name ping