# Base image
FROM php:7-fpm-alpine AS base

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

# Install for image manipulation
RUN docker-php-ext-install exif

# Install the PHP graphics library
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp
RUN docker-php-ext-install gd

# Install the PHP opcache extention
RUN docker-php-ext-enable opcache

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

RUN sed -i "s/user = www-data/user = laravel/g" /usr/local/etc/php-fpm.d/www.conf
RUN sed -i "s/group = www-data/group = laravel/g" /usr/local/etc/php-fpm.d/www.conf
RUN echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf

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
COPY --from=build /usr/local/lib/php/extensions/no-debug-non-zts-20190902/* /usr/local/lib/php/extensions/no-debug-non-zts-20190902
COPY --from=build /usr/local/etc/php/conf.d/* /usr/local/etc/php/conf.d

#####################################
# Cleanup
#####################################
RUN rm -rf /tmp/* /var/tmp/* /usr/src/php*

USER laravel

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
