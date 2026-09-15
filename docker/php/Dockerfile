FROM php:8.4-fpm-alpine

RUN apk add --no-cache icu-dev postgresql-dev \
    && docker-php-ext-install intl opcache pdo_pgsql

WORKDIR /app
