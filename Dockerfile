FROM php:7.4.1-apache

MAINTAINER Giulio Troccoli-Allard

# Install system dependencies
RUN apt-get update && apt-get install -y git libpng-dev zlib1g-dev libzip-dev libssl-dev libffi-dev openssh-client \
 python-dev python-setuptools zip unzip gnupg2 vpnc libxml2-dev

# Enable rewrite mod for Apache
RUN a2enmod rewrite

# Install PHP extensions
# - gd: required by the intervention image library
# - zip: required so Composer can use packages from dist
# - pdo_mysql: required by PDO to connect to a MySQL database
RUN docker-php-ext-install gd zip pdo_mysql calendar bcmath soap

# Install NodeJS 8.x
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt-get install -y nodejs

# Install Composer
RUN php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php && \
    php composer-setup.php && php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install yarn

COPY config/composer.json /root/.composer/
COPY config/composer.lock /root/.composer/

RUN cd /root/.composer/ && php /usr/local/bin/composer install --no-interaction --no-progress && \
    php /usr/local/bin/composer clearcache

# this workaround is to let docker write logs. we could think to remove logs from the directory
RUN usermod -u 1000 www-data

# Install and configure Xdebug
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini

RUN mkdir -p /var/www/vhosts/app

# Configure Apache and PHP
COPY config/apache/vhost.conf /etc/apache2/sites-enabled/000-default.conf
COPY config/php/50-custom.ini /usr/local/etc/php/conf.d/

# Clean up
RUN rm -rf /tmp/*

WORKDIR /var/www/vhosts/app
