#!/bin/bash
set -euxo pipefail

apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable --now docker

# Allow GitHub Actions SSH key (pipeline deploy access)
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
echo "${gha_ssh_public_key}" >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Run your API container
docker pull "${docker_image}"
docker rm -f items-api 2>/dev/null || true
docker run -d --name items-api --restart unless-stopped -p 8000:8000 "${docker_image}"
