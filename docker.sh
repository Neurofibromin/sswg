#! /bin/bash
# file for installing docker and some containers on armbian
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# table for services and ports
# portainer 9443
# uptime-kuma 3001 || is it https?
#


apt update && apt upgrade -y
apt install curl docker-compose -y
curl -fsSL https://get.docker.com | bash
docker volume create portainer_data
docker run -d -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
docker volume create uptime-kuma
docker run -d --restart=always -p 3001:3001 -v uptime-kuma:/app/data --name uptime-kuma louislam/uptime-kuma:1
