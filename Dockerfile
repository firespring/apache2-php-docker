FROM ubuntu:14.04
MAINTAINER Jeffery Utter "jeff.utter@firespring.com"

ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /var/run/apache2 /var/lock/apache2

# Clear out any existing postfix and re-configure
RUN apt-get remove -y --purge postfix
RUN echo "postfix postfix/main_mailer_type select  Internet with smarthost" | debconf-set-selections
RUN echo "postfix postfix/mailname string mail.example.com" | debconf-set-selections
RUN echo "postfix postfix/relayhost string [smtp.mandrillapp.com]:587" | debconf-set-selections

RUN apt-get update \
    && apt-get install -y \
    # Apache\PHP
    apache2 libapache2-mod-gnutls php5 php5-mysql php5-curl php5-xcache php-pear php5-gd php-xml-parser php5-dev \
    # Mogile
    libpcre3-dev libxml2-dev libneon27-dev \
    # Build Deps
    build-essential curl make \
    # Other Deps
    pdftk zip postfix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pecl install memcache \
    && pecl install redis-2.2.8 \
    && pecl install zip \
    && pecl install mogilefs-0.9.2

RUN a2enmod ssl \
    && a2enmod php5 \
    && a2enmod rewrite

RUN a2dissite 000-default
RUN a2dismod autoindex

RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Apache Config
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_RUN_DIR /var/run/apache2
ENV APPLICATION_ENV local

COPY apache2/apache2.conf /etc/apache2/
COPY php/conf.d/ /etc/php5/apache2/conf.d/
COPY php/conf.d/ /etc/php5/cli/conf.d/

COPY apache2-foreground /usr/local/bin/

ENV SERVER_NAME=localhost
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOG_LEVEL=warn

CMD ["apache2-foreground"]
