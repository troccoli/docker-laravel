FROM php:8.0.3-apache

MAINTAINER Giulio Troccoli-Allard

# Install system dependencies
RUN apt-get update && apt-get install -y vim git libjpeg-dev libpng-dev libzip-dev libssl-dev libffi-dev openssh-client \
 python-dev python-setuptools zip unzip gnupg2 vpnc libxml2-dev \
 libgtk2.0-0 libgtk-3-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb

# Enable rewrite mod for Apache
RUN a2enmod rewrite

# Install PHP extensions
# - gd: required by the intervention image library
# - zip: required so Composer can use packages from dist
# - pdo_mysql: required by PDO to connect to a MySQL database
RUN docker-php-ext-configure gd --enable-gd --with-jpeg
RUN docker-php-ext-install gd zip pdo_mysql calendar bcmath soap intl

# Install NodeJS 14.x
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - && apt-get install -y nodejs

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
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
