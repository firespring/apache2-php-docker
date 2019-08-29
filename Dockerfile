FROM php:7.2-apache-stretch
MAINTAINER Firespring "info.dev@firespring.com"

ENV DEBIAN_FRONTEND="noninteractive" \
    SERVER_NAME="localhost" \
    APACHE_RUN_USER="www-data" \
    APACHE_RUN_GROUP="www-data" \
    APACHE_PID_FILE="/var/run/apache2/apache2.pid" \
    APACHE_RUN_DIR="/var/run/apache2" \
    APACHE_LOCK_DIR="/var/lock/apache2" \
    APACHE_LOG_DIR="/var/log/apache2" \
    APACHE_LOG_LEVEL="warn" \
    APACHE_CUSTOM_LOG_FILE="/proc/self/fd/1" \
    APACHE_ERROR_LOG_FILE="/proc/self/fd/2" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="10000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"

RUN mkdir -p /var/run/apache2 /var/lock/apache2

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install apt-utils apt-transport-https software-properties-common gnupg \
    && LC_ALL=C.UTF-8 add-apt-repository 'deb https://packages.sury.org/php/ stretch main' \
    && apt-key adv --fetch-keys https://packages.sury.org/php/apt.gpg \
    # Use the default production configuration
    # except Prioritize Sury php-gd package
    && set -eux; \
	{ \
		echo 'Package: php*-gd'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: 1'; \
	} >> /etc/apt/preferences.d/no-debian-php \
    && apt-get update && apt-get install -y --force-yes \
    # Apache\PHP
    php-mysql php-dev php-gd php-redis libhiredis-dev libhiredis0.13 libphp-predis \
    libapache2-mod-gnutls php-zip php-cli \
    # Build Deps
    build-essential curl make \
    # Other Deps
    pdftk zip git libpng-dev libjpeg-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev libxpm-dev \
    # clean up packages here otherwise the files will be in every layer
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install and configure php modules
RUN pecl config-set php_ini "$PHP_INI_DIR" \
    && pear install PHP_CodeSniffer \
    && pecl install xdebug-2.6.1 \
    && pecl install apcu-5.1.12 \
    && docker-php-ext-enable apcu \
    && pecl install redis-5.0.1 \
    && docker-php-ext-enable redis \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install zip \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd

RUN curl -s -o phpunit-7.3.2.phar https://phar.phpunit.de/phpunit-7.3.2.phar \
    && chmod 777 phpunit-7.3.2.phar \
    && mv phpunit-7.3.2.phar /usr/local/bin/phpunit

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
COPY php/conf.d/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

COPY apache2-foreground /usr/local/bin/

CMD ["apache2-foreground"]
