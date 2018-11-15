FROM ubuntu:16.04
MAINTAINER Firespring "info.dev@firespring.com"

ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /var/run/apache2 /var/lock/apache2

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common

RUN apt-get update && LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php

RUN apt-get update && apt-get install -y --force-yes\
    # Apache\PHP
    apache2 libapache2-mod-gnutls libapache2-mod-php7.2 php7.2 php7.2-curl php7.2-common php7.2-dev php7.2-mbstring php7.2-curl php7.2-cli php7.2-mysql php7.2-gd php7.2-intl php7.2-xsl php7.2-zip php-xcache php-pear php7.2-gd php-xml-parser php-memcached libhiredis-dev libhiredis0.13 libphp-predis \
    # Mogile
    libpcre3-dev libxml2-dev libneon27-dev libzip-dev zlib1g-dev libmemcached-dev \
    # Build Deps
    build-essential curl make \
    # Other Deps
    pdftk zip git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -s -o phpunit-7.3.2.phar https://phar.phpunit.de/phpunit-7.3.2.phar \
    && chmod 777 phpunit-7.3.2.phar \
    && mv phpunit-7.3.2.phar /usr/local/bin/phpunit

RUN pecl install xdebug-2.6.1 \
    && pear install PHP_CodeSniffer \
    && pecl install apcu-5.1.12 \
    && echo no | pecl install memcached \
    && pecl install redis \
    && pecl install zip

RUN a2enmod ssl \
    && a2enmod php7.2 \
    && a2enmod rewrite \
    && a2enmod headers

RUN a2dissite 000-default
RUN a2dismod -f autoindex

RUN git clone https://github.com/nrk/phpiredis.git \
    && ls -altr \
    && cd phpiredis \
    && phpize && ./configure --enable-phpiredis \
    && make && make install \
    && cd .. && rm -rf phpiredis

RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Apache Config
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_RUN_DIR /var/run/apache2
ENV APPLICATION_ENV local

COPY apache2/apache2.conf /etc/apache2/
COPY php/conf.d/ /etc/php/7.2/apache2/conf.d/
COPY php/conf.d/ /etc/php/7.2/cli/conf.d/

COPY apache2-foreground /usr/local/bin/

ENV SERVER_NAME=localhost
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOG_LEVEL=warn
ENV APACHE_CUSTOM_LOG_FILE=/proc/self/fd/1
ENV APACHE_ERROR_LOG_FILE=/proc/self/fd/2

CMD ["apache2-foreground"]
