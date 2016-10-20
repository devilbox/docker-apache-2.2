#!/bin/sh -eu

###
### Variables
###
DEBUG_COMMANDS=0

HTTPD_CONF="/etc/httpd/conf/httpd.conf"



###
### Functions
###
runsu() {
	_cmd="${1}"
	_debug="0"

	_red="\033[0;31m"
	_green="\033[0;32m"
	_reset="\033[0m"
	_user="$(whoami)"

	# If 2nd argument is set and enabled, allow debug command
	if [ "${#}" = "2" ]; then
		if [ "${2}" = "1" ]; then
			_debug="1"
		fi
	fi


	if [ "${DEBUG_COMMANDS}" = "1" ] || [ "${_debug}" = "1" ]; then
		printf "${_red}%s \$ ${_green}sudo ${_cmd}${_reset}\n" "${_user}"
	fi

	/usr/local/bin/gosu root sh -c "LANG=C LC_ALL=C ${_cmd}"
}


log() {
	_lvl="${1}"
	_msg="${2}"

	_clr_ok="\033[0;32m"
	_clr_info="\033[0;34m"
	_clr_warn="\033[0;33m"
	_clr_err="\033[0;31m"
	_clr_rst="\033[0m"

	if [ "${_lvl}" = "ok" ]; then
		printf "${_clr_ok}[OK]   %s${_clr_rst}\n" "${_msg}"
	elif [ "${_lvl}" = "info" ]; then
		printf "${_clr_info}[INFO] %s${_clr_rst}\n" "${_msg}"
	elif [ "${_lvl}" = "warn" ]; then
		printf "${_clr_warn}[WARN] %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	elif [ "${_lvl}" = "err" ]; then
		printf "${_clr_err}[ERR]  %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	else
		printf "${_clr_err}[???]  %s${_clr_rst}\n" "${_msg}" 1>&2	# stdout -> stderr
	fi
}



################################################################################
# BOOTSTRAP
################################################################################

if set | grep '^DEBUG_COMPOSE_ENTRYPOINT='  >/dev/null 2>&1; then
	if [ "${DEBUG_COMPOSE_ENTRYPOINT}" = "1" ]; then
		DEBUG_COMMANDS=1
	fi
fi


################################################################################
# MAIN ENTRY POINT
################################################################################

###
### Adjust timezone
###

if ! set | grep '^TIMEZONE='  >/dev/null 2>&1; then
	log "warn" "\$TIMEZONE not set."
else
	if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
		# Unix Time
		log "info" "Setting docker timezone to: ${TIMEZONE}"
		runsu "rm /etc/localtime"
		runsu "ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"
	else
		log "err" "Invalid timezone for \$TIMEZONE."
		log "err" "\$TIMEZONE: '${TIMEZONE}' does not exist."
		exit 1
	fi
fi
log "info" "Docker date set to: $(date)"



###
### Prepare PHP-FPM
###
if ! set | grep '^PHP_FPM_ENABLE=' >/dev/null 2>&1; then
	log "info" "\$PHP_FPM_ENABLE not set. PHP-FPM support disabled."
else
	if [ "${PHP_FPM_ENABLE}" = "1" ]; then

		# PHP-FPM address
		if ! set | grep '^PHP_FPM_SERVER_ADDR=' >/dev/null 2>&1; then
			log "err" "PHP-FPM enabled, but \$PHP_FPM_SERVER_ADDR not set."
			exit 1
		fi
		if [ "${PHP_FPM_SERVER_ADDR}" = "" ]; then
			log "err" "PHP-FPM enabled, but \$PHP_FPM_SERVER_ADDR is empty."
			exit 1
		fi

		# PHP-FPM port
		if ! set | grep '^PHP_FPM_SERVER_PORT=' >/dev/null 2>&1; then
			log "info" "PHP-FPM enabled, but \$PHP_FPM_SERVER_PORT not set."
			lgo "info" "Defaulting PHP-FPM port to 9000"
			PHP_FPM_SERVER_PORT="9000"
		elif [ "${PHP_FPM_SERVER_PORT}" = "" ]; then
			log "info" "PHP-FPM enabled, but \$PHP_FPM_SERVER_PORT is empty."
			lgo "info" "Defaulting PHP-FPM port to 9000"
			PHP_FPM_SERVER_PORT="9000"
		fi

		PHP_FPM_CONFIG="/etc/httpd/conf.d/php-fpm.conf"
		PHP_FPM_HANDLER="/usr/local/bin/php-fcgi"

		# Enable
		log "info" "Enabling PHP-FPM at: ${PHP_FPM_SERVER_ADDR}:${PHP_FPM_SERVER_PORT}"
		runsu "echo '#### PHP-FPM config ####' > ${PHP_FPM_CONFIG}"
		runsu "echo '' >> ${PHP_FPM_CONFIG}"
		runsu "echo 'AddType application/x-httpd-fastphp5 .php' >> ${PHP_FPM_CONFIG}"
		runsu "echo 'Action application/x-httpd-fastphp5 /php5-fcgi' >> ${PHP_FPM_CONFIG}"
		runsu "echo 'Alias /php5-fcgi ${PHP_FPM_HANDLER}' >> ${PHP_FPM_CONFIG}"
		runsu "echo 'FastCgiExternalServer ${PHP_FPM_HANDLER} -host ${PHP_FPM_SERVER_ADDR}:${PHP_FPM_SERVER_PORT} -pass-header Authorization' >> ${PHP_FPM_CONFIG}"


		PHP_FPM_HANDLER_DIR="$( dirname "${PHP_FPM_HANDLER}" )"
		if [ ! -d "${PHP_FPM_HANDLER_DIR}" ]; then
			runsu "mkdir -p ${PHP_FPM_HANDLER_DIR} )"
		fi
		runsu "echo '#!/bin/sh' > ${PHP_FPM_HANDLER}"
		runsu "echo '' >> ${PHP_FPM_HANDLER}"
		runsu "echo 'PHPRC=/etc/' >> ${PHP_FPM_HANDLER}"
		runsu "echo '#PHPRC=\"/etc/php.ini\"' >> ${PHP_FPM_HANDLER}"
		runsu "echo 'export PHPRC' >> ${PHP_FPM_HANDLER}"
		runsu "echo 'export PHP_FCGI_MAX_REQUESTS=5000' >> ${PHP_FPM_HANDLER}"
		runsu "echo 'export PHP_FCGI_CHILDREN=8' >> ${PHP_FPM_HANDLER}"
		runsu "echo 'exec /usr/bin/php-cgi' >> ${PHP_FPM_HANDLER}"
	fi
fi



###
### Add new Apache configuration dir
###
if ! set | grep '^CUSTOM_HTTPD_CONF_DIR='  >/dev/null 2>&1; then
	log "info" "\$CUSTOM_HTTPD_CONF_DIR not set. No custom include directory added."
else
	# Tell apache to also look into this custom dir for configuratoin
	log "info" "Adding custom include directory: ${CUSTOM_HTTPD_CONF_DIR}"
	runsu "sed -i'' 's|^Include[[:space:]]*conf\.d/.*$|Include ${CUSTOM_HTTPD_CONF_DIR}/*.conf|g' ${HTTPD_CONF}"
fi



###
### Start
###
log "info" "Starting $(/usr/sbin/httpd -v 2>&1 | head -1)"
runsu "/usr/sbin/httpd -DFOREGROUND" "1"
