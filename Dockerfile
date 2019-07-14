FROM php:7.2-apache-stretch
MAINTAINER Firespring "info.dev@firespring.com"

ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /var/run/apache2 /var/lock/apache2

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install apt-utils apt-transport-https software-properties-common gnupg

RUN apt-get update && LC_ALL=C.UTF-8 add-apt-repository 'deb https://packages.sury.org/php/ stretch main' \
    && apt-key adv --fetch-keys https://packages.sury.org/php/apt.gpg

# Use the default production configuration
# except Prioritize Sury php-gd package
RUN set -eux; \
	{ \
		echo 'Package: php*-gd'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: 1'; \
	} >> /etc/apt/preferences.d/no-debian-php \
    && mkdir -p /etc/php/7.2/apache2 && mkdir -p /etc/php/7.2/cli \
    && cp "$PHP_INI_DIR/php.ini-production" "/etc/php/7.2/apache2/php.ini" \
    && mv "$PHP_INI_DIR/php.ini-production" "/etc/php/7.2/cli/php.ini"

RUN apt-get update && apt-get install -y --force-yes \
    # Apache\PHP
    libphp-predis \
    # Build Deps
    build-essential curl make \
    # Other Deps
    pdftk zip git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -s -o phpunit-7.3.2.phar https://phar.phpunit.de/phpunit-7.3.2.phar \
    && chmod 777 phpunit-7.3.2.phar \
    && mv phpunit-7.3.2.phar /usr/local/bin/phpunit

RUN pecl config-set php_ini "$PHP_INI_DIR" \
    && pear install PHP_CodeSniffer \
    && pecl install apcu-5.1.12 \
    && pecl install redis-5.0.1 \
    && docker-php-ext-enable redis

RUN a2enmod ssl \
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
