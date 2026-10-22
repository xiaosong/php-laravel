# Base image
FROM php:8.5-fpm-alpine AS base

RUN apk update --no-cache && \
    apk upgrade --no-cache

FROM base AS build

RUN apk add --no-cache \
    $PHPIZE_DEPS \
    linux-headers
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libzip-dev

#####################################
# PHP Extensions
#####################################

# Install for arbitrary-precision arithmetic
RUN docker-php-ext-install bcmath

# Install for image manipulation
RUN docker-php-ext-install exif

# Install the PHP graphics library
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp
RUN docker-php-ext-install gd

# PHP 8.5+ builds opcache statically and always loads it, so there is no opcache.so to enable.

# Install the PHP pdo_mysql extention
RUN docker-php-ext-install pdo_mysql

# Install the PHP redis driver
RUN pecl install redis && \
    docker-php-ext-enable redis

# Install the PHP zip extention
RUN docker-php-ext-install zip

FROM base AS target

ENV UID=1000
ENV GID=1000

RUN mkdir -p /var/www/html

WORKDIR /var/www/html

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN addgroup -g ${GID} --system laravel
RUN adduser -G laravel --system -D -s /bin/sh -u ${UID} laravel

RUN sed -i "s/pm.max_children = 5/pm.max_children = 15/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 6/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/user = www-data/user = laravel/g" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/group = www-data/group = laravel/g" /usr/local/etc/php-fpm.d/www.conf && \
    echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "php_admin_value[error_log] = /var/log/fpm-php.www.log" >> /usr/local/etc/php-fpm.d/www.conf

#####################################
# Install necessary libraries
#####################################
RUN apk add --no-cache \
    freetype \
    libjpeg-turbo \
    libwebp \
    libzip

#####################################
# Copy extensions from build stage
#####################################
# Whole tree, not the "no-debug-non-zts-<apino>" subdir: that name changes with every PHP version.
COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/* /usr/local/etc/php/conf.d

#####################################
# Cleanup
#####################################
RUN rm -rf /tmp/* /var/tmp/* /usr/src/php*

USER laravel

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
