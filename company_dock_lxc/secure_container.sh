#!/bin/bash

# Vérifier les arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 nom_projet port_web"
    exit 1
fi

NOM_PROJET="$1"
PORT_WEB="$2"
CONTAINER_APACHE="${NOM_PROJET}-apache-lxd"

# Vérifier que le conteneur existe
if ! lxc list | grep -q "$CONTAINER_APACHE"; then
    echo "Erreur : Le conteneur $CONTAINER_APACHE n'existe pas."
    exit 1
fi

# Appliquer les règles iptables dans le conteneur
echo "Configuration du pare-feu pour $CONTAINER_APACHE (port $PORT_WEB)..."

# Vider les règles existantes
lxc exec $CONTAINER_APACHE -- iptables -F
lxc exec $CONTAINER_APACHE -- iptables -X
lxc exec $CONTAINER_APACHE -- iptables -t nat -F
lxc exec $CONTAINER_APACHE -- iptables -t nat -X
lxc exec $CONTAINER_APACHE -- iptables -t mangle -F
lxc exec $CONTAINER_APACHE -- iptables -t mangle -X

# Politique par défaut : DROP tout
lxc exec $CONTAINER_APACHE -- iptables -P INPUT DROP # bloque tout par defaut
lxc exec $CONTAINER_APACHE -- iptables -P FORWARD DROP
lxc exec $CONTAINER_APACHE -- iptables -P OUTPUT ACCEPT

# Autoriser les connexions locales (loopback)
lxc exec $CONTAINER_APACHE -- iptables -A INPUT -i lo -j ACCEPT
lxc exec $CONTAINER_APACHE -- iptables -A OUTPUT -o lo -j ACCEPT

# Autoriser le trafic établi/relié
lxc exec $CONTAINER_APACHE -- iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser SSH (optionnel, si besoin)
# lxc exec $CONTAINER_APACHE -- iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Autoriser le port web spécifié
lxc exec $CONTAINER_APACHE -- iptables -A INPUT -p tcp --dport $PORT_WEB -j ACCEPT

# Autoriser ICMP (ping)
lxc exec $CONTAINER_APACHE -- iptables -A INPUT -p icmp -j ACCEPT

# Sauvegarder les règles (optionnel, si iptables-persistent est installé)
# lxc exec $CONTAINER_APACHE -- apt install -y iptables-persistent
# lxc exec $CONTAINER_APACHE -- netfilter-persistent save

echo "Pare-feu configuré pour $CONTAINER_APACHE ! Seules les connexions sur le port $PORT_WEB sont autorisées."
