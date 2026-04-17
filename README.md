
# TP Docker → LXD : Migration et Reverse Proxy

**Objectif** : Migrer une infrastructure Docker (Apache + MariaDB) vers LXD, tout en conservant un reverse proxy Docker pour router le trafic. Chaque projet dispose d'un dossier partagé pour le contenu web.



## **Sommaire**

1. [Partie 1 : Infrastructure initiale sous Docker]
2. [Partie 2 : Migration vers LXD]
3. [Configuration du Reverse Proxy (Docker → LXD)]
4. [Tests de validation]
5. [Structure des dossiers]
6. [Scripts d'automatisation]


## **Partie 1 : Infrastructure initiale sous Docker**

### **Schéma des dossiers**
```

company/
├── apache/
│   └── Dockerfile          # Dockerfile pour Apache
├── mariadb/
│   └── Dockerfile          # Dockerfile pour MariaDB
├── nginx/
│   ├── Dockerfile          # Dockerfile pour Nginx (reverse proxy)
│   └── nginx.conf          # Configuration Nginx
└── deploy_infra.sh         # Script d'automatisation Docker (obsolète après migration)

```

### **Dockerfiles**
#### **Apache (`compagny/apache/Dockerfile`)**
```dockerfile
FROM ubuntu:22.04
RUN apt update && apt install -y apache2
EXPOSE 80
CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### **MariaDB (`compagny/mariadb/Dockerfile`)**

```dockerfile
FROM ubuntu:22.04
RUN apt update && apt install -y mariadb-server
RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
EXPOSE 3306
CMD ["mysqld"]
```

### **Nginx (`compagny/nginx/Dockerfile`)**

```dockerfile
FROM nginx\:latest
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

### **Configuration Nginx (`compagny/nginx/nginx.conf`)**

```nginx
events {
    worker_connections1024;
}

http {
    server {
        listen80;
        server_nameprojet1.example.com;
        location / {
            proxy_passhttp://10.113.43.222:80;# IP du conteneur LXD Apache
            proxy_set_headerHost \$host;
            proxy_set_headerX-Real-IP \$remote_addr;
        }
    }
}
```



## **Partie 2 : Migration vers LXC**

### **Schéma des dossiers**

```
company_dock_lxc/  
├── projet1/  
│   ├── db_backup.sql         # Sauvegarde de la base de données  
│   ├── www/                  # Dossier partagé pour Apache  
│   │   └── index.html        # Fichier de test  
│   └── www_backup/           # Ancien contenu Docker  
└───── reverse_proxy/  
    ├── Dockerfile            # Dockerfile pour Nginx  
    └── nginx.conf            # Configuration Nginx mise à jour   
```

### **Étapes de migration**

### **1. Créer les conteneurs LXD**

```bash
lxc launch ubuntu:22.04 projet1-apache-lxd
lxc launch ubuntu:22.04 projet1-mariadb-lxd
```

### **2. Installer Apache et MariaDB**

```bash
lxc exec projet1-apache-lxd -- apt update &&apt install -y apache2
lxc exec projet1-apache-lxd -- systemctl enable --now apache2
lxc exec projet1-mariadb-lxd -- apt update &&apt install -y mariadb-server
lxc exec projet1-mariadb-lxd -- mysql_secure_installation
lxc exec projet1-mariadb-lxd -- systemctl enable --now mariadb
```

### **3. Sauvegarder et restaurer la base de données**

```bash
# Depuis Docker
docker exec projet1_mariadb mysqldump -u root -p --all-databases > ~/company_dock_lxc/projet1/db_backup.sql

# Vers LXD
lxc file push ~/company_dock_lxc/projet1/db_backup.sql projet1-mariadb-lxd/root/
lxc exec projet1-mariadb-lxd -- bash -c "mysql -u root -p < /root/db_backup.sql"
```

### **4. Configurer le dossier partagé pour Apache**

```bash
mkdir -p ~/company_dock_lxc/projet1/www
lxc config device add projet1-apache-lxd www disk source=\$HOME/company_dock_lxc/projet1/www path=/var/www/html
```

---

## **Configuration du Reverse Proxy**

### **1. Construire et lancer le conteneur Nginx**

```bash
cd ~/company_dock_lxc/reverse_proxy
docker build -t mon_nginx_reverse_proxy .
docker run -d --name reverse_proxy --network host -p 80:80 mon_nginx_reverse_proxy
```

### **2. Tester l'accès**

```bash
echo "127.0.0.1 projet1.example.com" | sudo tee -a /etc/hosts
curl http://projet1.example.com  # Doit afficher le contenu de ~/company_dock_lxc/projet1/www/index.html
```

---
<br>

## **Tests de validation**

### **1. Vérifier que les conteneurs LXD sont actifs**

```bash
lxc list
```

**Résultat attendu** :

```text

+---------------------+---------+----------------------+-----------+
|        NAME         |  STATE  |         IPV4         |   TYPE    |
+---------------------+---------+----------------------+-----------+
| projet1-apache-lxd  | RUNNING | 10.113.43.222        | CONTAINER |
| projet1-mariadb-lxd | RUNNING | 10.113.43.217        | CONTAINER |
+---------------------+---------+----------------------+-----------+
```

### **2. Vérifier le dossier partagé Apache**

```bash
lxc exec projet1-apache-lxd -- ls /var/www/html
```

**Résultat attendu** :


> index.html


### **3. Vérifier la base de données restaurée**

```bash
lxc exec projet1-mariadb-lxd -- mysql -u root -p -e "SHOW DATABASES;"
```

**Résultat attendu** :

```text
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| projet1_db         |  # Base de données du projet
+--------------------+
```

### **4. Vérifier le reverse proxy**

```bash
curl http://projet1.example.com
```

**Résultat attendu** :

Affiche le contenu du fichier `~/company_dock_lxc/projet1/www/index.html`.

---

<br>

## **Scripts d'automatisation**

### **Script pour LXD (`deploy_lxd.sh`)**

```bash
#!/bin/bash

# Créer les dossiers partagés
mkdir -p ~/company_dock_lxc/{projet1,projet2,projet3}/www

# Déploiement Projet 1
lxc launch ubuntu:22.04 projet1-apache-lxd
lxc exec projet1-apache-lxd -- apt update
lxc exec projet1-apache-lxd -- apt install -y apache2
lxc exec projet1-apache-lxd -- systemctl enable --now apache2
lxc config device add projet1-apache-lxd www disk source=\$HOME/company_dock_lxc/projet1/www path=/var/www/html

lxc launch ubuntu:22.04 projet1-mariadb-lxd
lxc exec projet1-mariadb-lxd -- apt update
lxc exec projet1-mariadb-lxd -- apt install -y mariadb-server
lxc exec projet1-mariadb-lxd -- mysql_secure_installation
lxc exec projet1-mariadb-lxd -- systemctl enable --now mariadb
echo "Infrastructure LXD déployée avec succès !"
```

### **Utilisation du script**

```bash
chmod +x deploy_lxd.sh
./deploy_lxd.sh
```
<br>

## **Sécurité des conteneurs avec iptables**

### **Script `secure_container.sh`**

```bash
#!/bin/bash

# Usage: ./secure_container.sh nom_projet port_web
if ["\$#" -ne 2 ];then
    echo "Usage:\$0 nom_projet port_web"
    exit 1
fi

NOM_PROJET="\$1"
PORT_WEB="$2"
CONTAINER_APACHE="${NOM_PROJET}-apache-lxd"

# Vérifier que le conteneur existe
if ! lxc list | grep -q "\$CONTAINER_APACHE";then
    echo "Erreur : Le conteneur\$CONTAINER_APACHE n'existe pas."
    exit 1
fi

# Configurer iptables
echo "Configuration du pare-feu pour\$CONTAINER_APACHE (port\$PORT_WEB)..."
lxc exec \$CONTAINER_APACHE -- iptables -F
lxc exec \$CONTAINER_APACHE -- iptables -X
lxc exec \$CONTAINER_APACHE -- iptables -P INPUT DROP
lxc exec \$CONTAINER_APACHE -- iptables -A INPUT -i lo -j ACCEPT
lxc exec \$CONTAINER_APACHE -- iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
lxc exec \$CONTAINER_APACHE -- iptables -A INPUT -p tcp --dport \$PORT_WEB -j ACCEPT
lxc exec \$CONTAINER_APACHE -- iptables -A INPUT -p icmp -j ACCEPT

echo "Pare-feu configuré ! Seules les connexions sur le port\$PORT_WEB et ICMP sont autorisées."
```

### **Utilisation**

```bash
chmod +x secure_container.sh
./secure_container.sh projet1 80
```

### **Règles appliquées**

| Règle | Description |
| --- | --- |
| `INPUT DROP` | Bloque tout par défaut. |
| `ACCEPT lo` | Autorise le trafic local. |
| `ACCEPT ESTABLISHED` | Autorise les connexions déjà établies. |
| `ACCEPT tcp/$PORT_WEB` | Autorise uniquement le port web. |
| `ACCEPT icmp` | Autorise le ping. |

---

## **Tests de validation**

### **1. Vérifier les conteneurs LXD**

```bash
lxc list
```

**Résultat attendu** :

```text

+---------------------+---------+----------------------+-----------+
|        NAME         |  STATE  |         IPV4         |   TYPE    |
+---------------------+---------+----------------------+-----------+
| projet1-apache-lxd  | RUNNING | 10.113.43.222        | CONTAINER |
| projet1-mariadb-lxd | RUNNING | 10.113.43.217        | CONTAINER |
+---------------------+---------+----------------------+-----------+
```

### **2. Vérifier le pare-feu**

```bash
lxc exec projet1-apache-lxd -- iptables -L -n
```

**Résultat attendu** :

```text
Chain INPUT (policy DROP)
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:80
ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0
```

### **3. Tester l’accès web**

```bash
echo "127.0.0.1 projet1.example.com" | sudo tee -a /etc/hosts
curl http://projet1.example.com
```

**Résultat attendu** : Affiche le contenu de `index.html`.

### **4. Tester le blocage des ports**

```bash
nc -zv 10.113.43.222 22   # Doit échouer (SSH bloqué)
nc -zv 10.113.43.222 3306 # Doit échouer (MariaDB bloqué)
nc -zv 10.113.43.222 80   # Doit réussir (HTTP autorisé)
```