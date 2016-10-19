##
## Apache 2.2
##
FROM centos:6
MAINTAINER "cytopia" <cytopia@everythingcli.org>


##
## Labels
##
LABEL \
	name="cytopia's Apache 2.2 Image" \
	image="apache-2.2" \
	vendor="cytopia" \
	license="MIT" \
	build-date="2016-10-19"


# Copy scripts
COPY ./scripts/docker-install.sh /
COPY ./scripts/docker-entrypoint.sh /


# Install
RUN /docker-install.sh


##
## Ports
##
EXPOSE 80


##
## Volumes
##
VOLUME /var/log/httpd


##
## Become apache in order to have mounted files
## with apache user rights
##
User apache


##
## Entrypoint
##
ENTRYPOINT ["/docker-entrypoint.sh"]
