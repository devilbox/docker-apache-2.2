FROM httpd:2.2
MAINTAINER "cytopia" <cytopia@everythingcli.org>

LABEL \
	name="cytopia's apache 2.2 image" \
	image="devilbox/apache-2.2" \
	vendor="devilbox" \
	license="MIT"


###
### Build arguments
###
ARG VHOST_GEN_GIT_REF=1.0.3
ARG WATCHERD_GIT_REF=v1.0.2
ARG CERT_GEN_GIT_REF=0.7
ARG ARCH

ENV BUILD_DEPS \
	autoconf \
	gcc \
	make \
	wget

ENV RUN_DEPS \
	ca-certificates \
	python-yaml \
	supervisor


###
### Runtime arguments
###
ENV MY_USER=daemon
ENV MY_GROUP=daemon
ENV HTTPD_START="httpd-foreground"
ENV HTTPD_RELOAD="/usr/local/apache2/bin/httpd -k stop"

###
### Install required packages
###
RUN set -eux \
	&& rm -f /etc/apt/sources.list \
	&& { \
		echo "deb http://deb.debian.org/debian/ stretch main"; \
		echo "deb http://security.debian.org/debian-security stretch/updates main"; \
	} | tee /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
		${BUILD_DEPS} \
		${RUN_DEPS} \
	\
	# Required symlinks to build mod-proxy-fcgi on i386
	&& if [ "${ARCH}" = "linux/386" ]; then \
		ln -s $(which ar) /usr/bin/i586-linux-gnu-ar; \
		ln -s $(which ranlib) /usr/bin/i586-linux-gnu-ranlib ; \
	fi \
	\
	# mod-proxy-fcgi
	&& wget --no-check-certificate -O mod-proxy-fcgi.tar.gz https://github.com/devilbox/mod-proxy-fcgi/archive/master.tar.gz \
	&& tar xvfz mod-proxy-fcgi.tar.gz \
	&& cd mod-proxy-fcgi-master \
	&& autoconf \
	&& ./configure \
	&& make \
	&& make install \
	&& cd .. \
	&& rm -rf mod-proxy-fcgi* \
	\
	# Install vhost-gen
	&& wget --no-check-certificate -O vhost-gen.tar.gz "https://github.com/devilbox/vhost-gen/archive/refs/tags/${VHOST_GEN_GIT_REF}.tar.gz" \
	&& tar xvfz vhost-gen.tar.gz \
	&& cd "vhost-gen-${VHOST_GEN_GIT_REF}" \
	&& make install \
	&& cd .. \
	&& rm -rf vhost*gen* \
	\
	# Install cert-gen
	&& wget --no-check-certificate -O /usr/bin/ca-gen https://raw.githubusercontent.com/devilbox/cert-gen/${CERT_GEN_GIT_REF}/bin/ca-gen \
	&& wget --no-check-certificate -O /usr/bin/cert-gen https://raw.githubusercontent.com/devilbox/cert-gen/${CERT_GEN_GIT_REF}/bin/cert-gen \
	&& chmod +x /usr/bin/ca-gen \
	&& chmod +x /usr/bin/cert-gen \
	\
	# Install watcherd
	&& wget --no-check-certificate -O /usr/bin/watcherd https://raw.githubusercontent.com/devilbox/watcherd/${WATCHERD_GIT_REF}/watcherd \
	&& chmod +x /usr/bin/watcherd \
	\
	# Clean-up
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
		${BUILD_DEPS} \
	&& rm -rf /var/lib/apt/lists/*


###
### Configure Apache
###
RUN set -eux \
	&& ( \
		echo "ServerName localhost"; \
		echo "LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so"; \
		echo "NameVirtualHost *:80"; \
		echo "Include conf/extra/httpd-default.conf"; \
		echo "Include /etc/httpd-custom.d/*.conf"; \
		echo "Include /etc/httpd/conf.d/*.conf"; \
		echo "Include /etc/httpd/vhost.d/*.conf"; \
		\
		#echo "LoadModule ssl_module modules/mod_ssl.so"; \
		echo "Listen 443"; \
		echo "NameVirtualHost *:443"; \
		echo "SSLCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES"; \
		echo "SSLProxyCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES"; \
		echo "SSLHonorCipherOrder on"; \
		echo "SSLProtocol all -SSLv2 -SSLv3"; \
		echo "SSLProxyProtocol all -SSLv2 -SSLv3"; \
		echo "SSLPassPhraseDialog  builtin"; \
		echo "SSLSessionCache        \"shmcb:/usr/local/apache2/logs/ssl_scache(512000)\""; \
		echo "SSLSessionCacheTimeout  300"; \
		echo "SSLMutex  \"file:/usr/local/apache2/logs/ssl_mutex\""; \
		\
		echo "HTTPProtocolOptions unsafe"; \
	) >> /usr/local/apache2/conf/httpd.conf


###
### Create directories
###
RUN set -eux \
	&& mkdir -p /etc/httpd-custom.d \
	&& mkdir -p /etc/httpd/conf.d \
	&& mkdir -p /etc/httpd/vhost.d \
	&& mkdir -p /var/www/default/htdocs \
	&& mkdir -p /shared/httpd \
	&& chmod 0775 /shared/httpd \
	&& chown ${MY_USER}:${MY_GROUP} /shared/httpd


###
### Copy files
###
COPY ./data/vhost-gen/main.yml /etc/vhost-gen/main.yml
COPY ./data/vhost-gen/mass.yml /etc/vhost-gen/mass.yml
COPY ./data/create-vhost.sh /usr/local/bin/create-vhost.sh
COPY ./data/docker-entrypoint.d /docker-entrypoint.d
COPY ./data/docker-entrypoint.sh /docker-entrypoint.sh


###
### Ports
###
EXPOSE 80
EXPOSE 443


###
### Volumes
###
VOLUME /shared/httpd
VOLUME /ca


###
### Signals
###
STOPSIGNAL SIGTERM


###
### Entrypoint
###
ENTRYPOINT ["/docker-entrypoint.sh"]
