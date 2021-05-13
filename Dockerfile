ARG ARG_CUDA_TAG="10.2-cudnn7-devel-ubuntu18.04"

FROM nvidia/cuda:${ARG_CUDA_TAG}
#FROM node:12.21.0-buster-slim

ARG ARG_NODEJS_VERSION="12"

# Image version
ARG ARG_IMAGE_VERSION="0.1.1"

# Shinobi's version information
ARG ARG_APP_VERSION

# The channel or branch triggering the build.
ARG ARG_APP_CHANNEL

# The commit sha triggering the build.
ARG ARG_APP_COMMIT

# Update Shinobi on every container start?
#   manual:     Update Shinobi manually. New Docker images will always retrieve the latest version.
#   auto:       Update Shinobi on every container start.
ARG ARG_APP_UPDATE=manual

# Build data
ARG ARG_BUILD_DATE

# ShinobiPro branch, defaults to dev
ARG ARG_APP_BRANCH=dev

# Additional Node JS packages for Shinobi plugins, addons, etc.
ARG ARG_ADD_NODEJS_PACKAGES="mqtt"

# Define Node.js version to use (Issue #20: Ubuntu based images fail build caused by sqlite3 `node-pre-gyp`)
ARG ARG_NODEJS_VERSION_FULL="12.14.1"

ENV APP_VERSION=$ARG_APP_VERSION \
    APP_CHANNEL=$ARG_APP_CHANNEL \
    APP_COMMIT=$ARG_APP_COMMIT \
    APP_UPDATE=$ARG_APP_UPDATE \
    APP_BRANCH=${ARG_APP_BRANCH} \
    APP_IMAGE_VERSION=${ARG_IMAGE_VERSION} \
    DB_USER=majesticflame \
    DB_PASSWORD='' \
    DB_HOST='localhost' \
    DB_DATABASE=ccio \
    DB_PORT=3306 \
    SUBSCRIPTION_ID=sub_XXXXXXXXXXXX \
    PLUGIN_KEYS='{}' \
    SSL_ENABLED='false' \
    SSL_COUNTRY='CA' \
    SSL_STATE='BC' \
    SSL_LOCATION='Vancouver' \
    SSL_ORGANIZATION='Shinobi Systems' \
    SSL_ORGANIZATION_UNIT='IT Department' \
    SSL_COMMON_NAME='nvr.ninja' \
    DB_DISABLE_INCLUDED=false \
    ADMIN_USER=admin@shinobi.video \
    ADMIN_PASSWORD=admin \
    GPU=1

ARG DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /home/Shinobi
RUN mkdir -p /var/lib/mysql
RUN mkdir /config

RUN apt update -y
RUN apt install wget curl net-tools -y
RUN curl -sL https://deb.nodesource.com/setup_${ARG_NODEJS_VERSION}.x | bash -

# Install MariaDB server... the debian way
RUN if [ "$DB_DISABLE_INCLUDED" = "false" ] ; then set -ex; \
	{ \
		echo "mariadb-server" mysql-server/root_password password '${DB_ROOT_PASSWORD}'; \
		echo "mariadb-server" mysql-server/root_password_again password '${DB_ROOT_PASSWORD}'; \
	} | debconf-set-selections; \
	apt-get update; \
	apt-get install -y \
		"mariadb-server" \
        socat \
	; \
    find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/'; fi

RUN if [ "$DB_DISABLE_INCLUDED" = "false" ] ; then sed -ie "s/^bind-address\s*=\s*127\.0\.0\.1$/#bind-address = 0.0.0.0/" /etc/mysql/my.cnf; fi

# Install FFmpeg

RUN apt update --fix-missing

RUN apt install -y \
        software-properties-common \
        build-essential \
        nodejs \
        yasm \
        bzip2 \
        coreutils \
        procps \
        gnutls-bin \
        nasm \
        tar \
        yasm \
        git \
        libsqlite3-dev \
        make \
        mariadb-client \
        g++ \
        gcc \
        pkg-config \
        python3 \
        sqlite \
        wget \
        tzdata \
        xz-utils \
        tar \
        sudo \
        xz-utils \
        imagemagick

RUN apt install -y  \
        libfreetype6-dev \
        libgnutls28-dev \
        libmp3lame-dev \
        libass-dev \
        libogg-dev \
        libtheora-dev \
        libvorbis-dev \
        libvpx-dev \
        libwebp-dev \
        libssh2-1-dev \
        libopus-dev \
        librtmp-dev \
        libx264-dev \
        libx265-dev \
        x264 \
        ffmpeg

RUN npm install -g npm@latest pm2

# Issue #20: Ubuntu based images fail build caused by sqlite3 `node-pre-gyp`
RUN npm install -g n \
    && n ${ARG_NODEJS_VERSION_FULL}


WORKDIR /home/Shinobi

# Install Shinobi app including NodeJS dependencies
RUN git clone -b ${ARG_APP_BRANCH} https://gitlab.com/Shinobi-Systems/Shinobi.git /home/Shinobi/
RUN npm install sqlite3 --unsafe-perm
RUN npm install jsonfile edit-json-file ${ARG_ADD_NODEJS_PACKAGES}
RUN npm install --unsafe-perm
RUN npm audit fix --force

WORKDIR /home/Shinobi

#RUN rm -rf /home/Shinobi/plugins
RUN chmod -R 777 /home/Shinobi/plugins
RUN npm install --unsafe-perm

#COPY /home/Shinobi/Docker/pm2.yml /home/Shinobi/pm2.yml

# Copy default configuration files
# COPY /home/Shinobi/config/conf.json /home/Shinobi/config/super.json /home/Shinobi/
RUN chmod -f +x /home/Shinobi/Docker/init.sh

VOLUME ["/home/Shinobi/videos"]
VOLUME ["/home/Shinobi/plugins"]
VOLUME ["/config"]
VOLUME ["/customAutoLoad"]
VOLUME ["/var/lib/mysql"]

EXPOSE 8080

ENTRYPOINT ["/home/Shinobi/Docker/init.sh"]

CMD [ "pm2-docker", "/home/Shinobi/Docker/pm2.yml" ]