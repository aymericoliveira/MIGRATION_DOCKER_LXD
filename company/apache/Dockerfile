FROM ubuntu:22.04
RUN apt update && apt install -y apache2
EXPOSE 80
CMD ["apache2ctl", "-D", "FOREGROUND"]
