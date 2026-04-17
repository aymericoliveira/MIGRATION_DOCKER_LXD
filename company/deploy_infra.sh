#!/bin/bash

# Création des réseaux
docker network create projet1_net
docker network create projet2_net
docker network create projet3_net

# Déploiement Projet 1
docker run -d --name projet1_mariadb --network projet1_net -e MYSQL_ROOT_PASSWORD=maria img_mariadb:latest
docker run -d --name projet1_apache --network projet1_net -p 8081:80 img_apache:latest

# Déploiement Projet 2
docker run -d --name projet2_mariadb --network projet2_net -e MYSQL_ROOT_PASSWORD=maria img_mariadb:latest
docker run -d --name projet2_apache --network projet2_net -p 8082:80 img_apache:latest

# Déploiement Projet 3
docker run -d --name projet3_mariadb --network projet3_net -e MYSQL_ROOT_PASSWORD=maria img_mariadb:latest
docker run -d --name projet3_apache --network projet3_net -p 8083:80 img_apache:latest

# Déploiement Reverse Proxy
docker run -d --name reverse_proxy \
  --network projet1_net \
  --network projet2_net \
  --network projet3_net \
  -p 80:80 \
  img_nginx:latest

echo "Infrastructure déployée avec succès !"

