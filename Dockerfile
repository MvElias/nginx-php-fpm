FROM php:5.6-fpm-alpine
#MODIFIED
ENV NGINX_VERSION 1.18.0
ENV LD_LIBRARY_PATH /usr/local/instantclient
ENV ORACLE_HOME /usr/local/instantclient
ENV ORACLE_INSTANTCLIENT_VERSION 11.2.0.4.0
ENV TZ=America/Santiago
#SET NGINX
RUN \
  build_pkgs="build-base linux-headers openssl-dev pcre-dev wget zlib-dev" && \
  runtime_pkgs="ca-certificates openssl pcre zlib tzdata git" && \
  apk --no-cache add ${build_pkgs} ${runtime_pkgs}&& \
  cd /tmp && \
  wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  tar xzf nginx-${NGINX_VERSION}.tar.gz && \
  cd /tmp/nginx-${NGINX_VERSION} && \
  ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-http_slice_module \
    --with-http_v2_module && \
  make && \
  make install && \
  sed -i -e 's/#access_log  logs\/access.log  main;/access_log \/dev\/stdout;/' -e 's/#error_log  logs\/error.log  notice;/error_log stderr notice;/' /etc/nginx/nginx.conf && \
  addgroup -S nginx && \
  adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
  rm -rf /tmp/* && \
  apk del ${build_pkgs} && \
  rm -rf /var/cache/apk/*

RUN mkdir /etc/nginx/sites-available
RUN mkdir /etc/nginx/sites-enabled

#SET ORACLE INSTANTCLIENT
RUN mkdir -p /opt/oracle/
COPY files/oracle  /opt/oracle/

RUN apk --update add openjdk8-jre-base

RUN apk --no-cache add tzdata bash nano php5-pear php5-dev gcc supervisor musl-dev libaio libnsl libc6-compat curl make autoconf &&\
## Download and unzip Instant Client
  curl -o /tmp/basic.zip https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/instantclient-basic-linux.x64-${ORACLE_INSTANTCLIENT_VERSION}.zip && \
  curl -o /tmp/sdk.zip https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/instantclient-sdk-linux.x64-${ORACLE_INSTANTCLIENT_VERSION}.zip && \
  curl -o /tmp/sqlplus.zip https://raw.githubusercontent.com/bumpx/oracle-instantclient/master/instantclient-sqlplus-linux.x64-${ORACLE_INSTANTCLIENT_VERSION}.zip && \
  unzip -d /usr/local/ /tmp/basic.zip && \
  unzip -d /usr/local/ /tmp/sdk.zip && \
  unzip -d /usr/local/ /tmp/sqlplus.zip && \
## Links are required
  ln -s /usr/local/instantclient_11_2 ${ORACLE_HOME} && \
  ln -s ${ORACLE_HOME}/libclntsh.so.* ${ORACLE_HOME}/libclntsh.so && \
  ln -s ${ORACLE_HOME}/libocci.so.* ${ORACLE_HOME}/libocci.so && \
  ln -s ${ORACLE_HOME}/lib* /usr/lib && \
  ln -s ${ORACLE_HOME}/sqlplus /usr/bin/sqlplus &&\
  ln -s /usr/lib/libnsl.so.2.0.0  /usr/lib/libnsl.so.1 &&\
## Build OCI8 with PECL
  echo "instantclient,${ORACLE_HOME}" | pecl install oci8-2.0.12  &&\
  echo 'extension=oci8.so' > /usr/local/etc/php/conf.d/30-oci8.ini
## INSTALL PHP EXTENSIONS

RUN apk --no-cache add libmcrypt-dev bzip2-dev libpng libpng-dev icu-dev gettext gettext-dev libxml2-dev libxslt-dev &&\ 
docker-php-ext-install mcrypt bz2 calendar gettext intl mysqli pcntl pdo_mysql shmop soap &&\
docker-php-ext-install sockets sysvmsg sysvsem sysvshm wddx xsl zip


#COPY FILES FROM DOCKERFILE ROOT DIRECTORY
COPY files/php.ini /usr/local/etc/php/
COPY files/index.html /etc/nginx/html/
COPY files/nginx.conf /etc/nginx/nginx.conf
COPY files/supervisord.conf /etc/supervisord.conf
COPY files/info.php /etc/nginx/html/

RUN mkdir -p /var/run/php &&\
    mkdir  /var/run/nginx
RUN ln -snf /usr/share/zoneinfo/$TZ && echo $TZ > /etc/timezone
#Clean
RUN  apk del php5-pear php5-dev  musl-dev &&\
  rm -rf /tmp/*.zip /var/cache/apk/* /tmp/pea

EXPOSE 80 443


ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
