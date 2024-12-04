FROM php:7.1-apache
#RUN apt-get update && apt-get install -y ... --no-install-recommends && rm -r /var/lib/apt/lists/*
RUN apt update && apt install -y inetutils-ping 
RUN docker-php-ext-install -j$(nproc) mysqli pdo pdo_mysql

RUN a2enmod rewrite
