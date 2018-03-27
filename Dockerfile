#Build stage, useful for a better use of cache ;)
FROM composer:1.5.2 AS build

ENV NOVOSGA_VER=v2.0.0-RC2 \
    NOVOSGA_MD5=f99b6b6abe2f01a4e3d6cf8f6d567743

ENV NOVOSGA_FILE=novosga.tar.gz \
    NOVOSGA_DIR=/var/www/html \
    NOVOSGA_URL=https://github.com/novosga/novosga/archive/master.tar.gz \
    APP_ENV=prod \
    DATABASE_URL=mysql://root:123456@127.0.0.1:3306/novosga?charset=utf8mb4&serverVersion=5.7

RUN set -xe \
    && mkdir -p $NOVOSGA_DIR && cd $NOVOSGA_DIR \
    && docker-php-ext-install pcntl \
    && curl -fSL ${NOVOSGA_URL} -o ${NOVOSGA_FILE} \
    && tar -xz --strip-components=1 -f ${NOVOSGA_FILE} \
    && rm ${NOVOSGA_FILE} \
    && composer install --no-dev -o

FROM php:7.1-apache

RUN set -xe \
    && apt-get update \
    && apt-get install -y \
        libicu-dev \
        libxml2-dev \
        zlib1g-dev \
        supervisor \
    && docker-php-ext-install \
        gettext \
        intl \
        pcntl \
        pdo \
        pdo_mysql \
        xml \
        zip \
    && apt-get remove -y --purge \
        postgresql-server-dev-all \
        libicu-dev \
        libxml2-dev \
        zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && a2enmod rewrite env \
    && echo 'session.save_path = "/tmp"' > /usr/local/etc/php/conf.d/sessionsavepath.ini \
    && echo 'date.timezone = ${TZ}' > /usr/local/etc/php/conf.d/datetimezone.ini

COPY --from=build /var/www/html /var/www/html

RUN set -xe \
    && chown -R www-data:www-data . \
    && sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

#Set the default parameters
ENV APP_ENV=prod \
    LANGUAGE=pt_BR \
    NOVOSGA_ADMIN_USERNAME="admin" \
    NOVOSGA_ADMIN_PASSWORD="123456" \
    NOVOSGA_ADMIN_FIRSTNAME="Administrator" \
    NOVOSGA_ADMIN_LASTNAME="Global" \
    NOVOSGA_UNITY_NAME="My Unity" \
    NOVOSGA_UNITY_CODE="U01" \
    NOVOSGA_NOPRIORITY_NAME="Normal" \
    NOVOSGA_NOPRIORITY_DESCRIPTION="Normal service" \
    NOVOSGA_PRIORITY_NAME="Priority" \
    NOVOSGA_PRIORITY_DESCRIPTION="Priority service" \
    NOVOSGA_PLACE_NAME="Box"

COPY start.sh /usr/local/bin
COPY apache2/htaccess public/.htaccess
COPY supervisor/apache2.conf /etc/supervisor/conf.d/apache2.conf
COPY supervisor/websocket.conf /etc/supervisor/conf.d/websocket.conf

CMD ["start.sh"]
