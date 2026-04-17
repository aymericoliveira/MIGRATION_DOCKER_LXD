FROM ubuntu:22.04
RUN apt update && apt install -y mariadb-server
RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
EXPOSE 3306
CMD ["mysqld"]
