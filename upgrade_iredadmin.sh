#!/usr/bin/env bash

# Purpose: Upgrade iRedAdmin from old release.
#          Works with both iRedAdmin open souce edition or iRedAdmin-Pro.

# USAGE:
#
#   # cd /path/to/iRedAdmin-xxx/tools/
#   # bash upgrade_iredadmin.sh
#
# Notes:
#
#   * it uses sql username 'root' by default to connect to sql database. If you
#     are using a remote SQL database which you don't have root privilege,
#     please specify the sql username on command line with 'SQL_IREDADMIN_USER'
#     parameter like this:
#
#       SQL_IREDADMIN_USER='iredadmin' bash upgrade_iredadmin.sh
#
#   * it reads sql password for given sql user from /root/.my.cnf by default.
#     if you use a different file, please specify the file on command line with
#     'MY_CNF' parameter like this:
#
#       MY_CNF='/root/.my.cnf-iredadmin' SQL_IREDADMIN_USER='iredadmin' bash upgrade_iredadmin.sh

export IRA_HTTPD_USER='iredadmin'
export IRA_HTTPD_GROUP='iredadmin'

export SYS_ROOT_USER='root'

# If you don't have root privilege, use another sql user instead.
export SQL_IREDADMIN_USER="${SQL_IREDADMIN_USER:=root}"
export MY_CNF="${MY_CNF:=/root/.my.cnf}"
export CMD_MYSQL="mysql --defaults-file=${MY_CNF} -u ${SQL_IREDADMIN_USER}"

# Check OS to detect some necessary info.
export KERNEL_NAME="$(uname -s | tr '[a-z]' '[A-Z]')"
export UWSGI_RC_SCRIPT_NAME='uwsgi'

export NGINX_PID_FILE='/var/run/nginx.pid'
export NGINX_SNIPPET_CONF='/etc/nginx/templates/iredadmin.tmpl'
export NGINX_SNIPPET_CONF2='/etc/nginx/templates/iredadmin-subdomain.tmpl'
# iRedMail-0.9.7
export NGINX_SNIPPET_CONF3='/etc/nginx/conf.d/default.conf'

export USE_SYSTEMD='NO'
if which systemctl &>/dev/null; then
    export USE_SYSTEMD='YES'
    export SYSTEMD_SERVICE_DIR='/lib/systemd/system'
    export SYSTEMD_SERVICE_DIR2='/etc/systemd/system'
    export SYSTEMD_SERVICE_USER_DIR='/etc/systemd/system/multi-user.target.wants/'
fi

if [ X"${KERNEL_NAME}" == X"LINUX" ]; then
    export PYTHON_BIN='/usr/bin/python'

    if [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        export DISTRO='RHEL'
        export HTTPD_RC_SCRIPT_NAME='httpd'
        export CRON_SPOOL_DIR='/var/spool/cron'

        if [[ -d /opt/www/iredadmin ]]; then
            export HTTPD_SERVERROOT='/opt/www'
        else
            export HTTPD_SERVERROOT='/var/www'
        fi
    elif [ -f /etc/lsb-release ]; then
        # Ubuntu
        export DISTRO='UBUNTU'
        export HTTPD_RC_SCRIPT_NAME='apache2'
        export CRON_SPOOL_DIR='/var/spool/cron/crontabs'

        if [ -d /opt/www/iredadmin ]; then
            export HTTPD_SERVERROOT='/opt/www'
        else
            export HTTPD_SERVERROOT='/usr/share/apache2'
        fi
    elif [ -f /etc/debian_version ]; then
        # Debian
        export DISTRO='DEBIAN'
        export HTTPD_RC_SCRIPT_NAME='apache2'
        export CRON_SPOOL_DIR='/var/spool/cron/crontabs'

        if [ -d /opt/www/iredadmin ]; then
            export HTTPD_SERVERROOT='/opt/www'
        else
            export HTTPD_SERVERROOT='/usr/share/apache2'
        fi
    elif [ -f /etc/SuSE-release ]; then
        # openSUSE
        export DISTRO='SUSE'
        export HTTPD_SERVERROOT='/srv/www'
        export HTTPD_RC_SCRIPT_NAME='apache2'
        export CRON_SPOOL_DIR='/var/spool/cron'
    else
        echo "<<< ERROR >>> Cannot detect Linux distribution name. Exit."
        echo "Please contact support@iredmail.org to solve it."
        exit 255
    fi
elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
    export DISTRO='FREEBSD'
    export PYTHON_BIN='/usr/local/bin/python'
    export CRON_SPOOL_DIR='/var/cron/tabs'
    export NGINX_SNIPPET_CONF='/usr/local/etc/nginx/templates/iredadmin.tmpl'
    export NGINX_SNIPPET_CONF2='/usr/local/etc/nginx/templates/iredadmin-subdomain.tmpl'
    export NGINX_SNIPPET_CONF3='/usr/local/etc/nginx/conf.d/default.conf'

    if [ -d /opt/www/iredadmin ]; then
        export HTTPD_SERVERROOT='/opt/www'
    else
        export HTTPD_SERVERROOT='/usr/local/www'
    fi

    if [ -f /usr/local/etc/rc.d/apache24 ]; then
        export HTTPD_RC_SCRIPT_NAME='apache24'
    else
        export HTTPD_RC_SCRIPT_NAME='apache22'
    fi
elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
    export PYTHON_BIN='/usr/local/bin/python'
    export DISTRO='OPENBSD'
    export CRON_SPOOL_DIR='/var/cron/tabs'

    if [[ -h /opt/www/iredadmin ]]; then
        export HTTPD_SERVERROOT='/opt/www'
    else
        export HTTPD_SERVERROOT='/var/www'
    fi
else
    echo "Cannot detect Linux/BSD distribution. Exit."
    echo "Please contact author iRedMail team <support@iredmail.org> to solve it."
    exit 255
fi

export CRON_FILE_ROOT="${CRON_SPOOL_DIR}/${SYS_ROOT_USER}"

# Optional argument to set the directory which stores iRedAdmin.
if [ $# -gt 0 ]; then
    if [ -d ${1} ]; then
        export HTTPD_SERVERROOT="${1}"
    fi

    if echo ${HTTPD_SERVERROOT} | grep '/iredadmin/*$' > /dev/null; then
        export HTTPD_SERVERROOT="$(dirname ${HTTPD_SERVERROOT})"
    fi
fi

# Dependent package names
# SimpleJson
export DEP_PY_JSON='simplejson'
# dnspython
export DEP_PY_DNS='python-dns'
# pycurl
export DEP_PY_CURL='python-pycurl'
# requests
export DEP_PY_REQUESTS='python-requests'
if [ X"${DISTRO}" == X'RHEL' ]; then
    :
elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    export DEP_PY_JSON='python-simplejson'
elif [ X"${DISTRO}" == X'OPENBSD' ]; then
    export DEP_PY_JSON='py-simplejson'
    export DEP_PY_CURL='py-curl'
    export DEP_PY_DNS='py-dnspython'
    export DEP_PY_REQUESTS='py-requests'
elif [ X"${DISTRO}" == X'FREEBSD' ]; then
    export DEP_PY_JSON='devel/py-simplejson'
    export DEP_PY_CURL='ftp/py-pycurl'
    export DEP_PY_DNS='dns/py-dnspython'
    export DEP_PY_REQUESTS='www/py-requests'
fi

# iRedAdmin directory and config file.
export IRA_ROOT_DIR="${HTTPD_SERVERROOT}/iredadmin"
export IRA_CONF_PY="${IRA_ROOT_DIR}/settings.py"
export IRA_CUSTOM_CONF_PY="${IRA_ROOT_DIR}/custom_settings.py"
export IRA_CONF_INI="${IRA_ROOT_DIR}/settings.ini"

enable_service() {
    srv="$1"

    echo "* Enable service: ${srv}"
    if [ X"${DISTRO}" == X'RHEL' ]; then
        if [ X"${USE_SYSTEMD}" == X'YES' ]; then
            systemctl enable $srv
        else
            chkconfig --level 345 $srv on
        fi
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        if [ X"${USE_SYSTEMD}" == X'YES' ]; then
            systemctl enable $srv
        else
            update-rc.d $srv defaults
        fi
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        /usr/sbin/sysrc -f /etc/rc.conf.local ${srv}_enable=YES
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        rcctl enable $srv
    fi
}

restart_service() {
    srv="$1"

    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        if [ X"${USE_SYSTEMD}" == X'YES' ]; then
            systemctl restart ${srv}
        else
            service ${srv} restart
        fi
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        service ${srv} restart
    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        rcctl restart ${srv}
    fi

    if [ X"$?" != X'0' ]; then
        echo "Failed, please restart service manually and check its log file."
    fi
}

restart_web_service()
{
    export web_service="${HTTPD_RC_SCRIPT_NAME}"
    if [ -f ${NGINX_PID_FILE} ]; then
        if [ -n "$(cat ${NGINX_PID_FILE})" ]; then
            export web_service="${UWSGI_RC_SCRIPT_NAME}"
        fi
    fi

    echo "* Restarting ${web_service} service."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        # The uwsgi script on CentOS 6 has problem with 'restart'
        # action, 'stop' with few seconds sleep fixes it.
        if [ X"${DISTRO}" == X'RHEL' -a X"${web_service}" == X'uwsgi' ]; then
            service ${web_service} stop
            sleep 5
            service ${web_service} start
        else
            service ${web_service} restart
        fi
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        service ${web_service} restart
    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        rcctl restart ${web_service}
    fi

    if [ X"$?" != X'0' ]; then
        echo "Failed, please restart service ${HTTPD_RC_SCRIPT_NAME} or ${UWSGI_RC_SCRIPT_NAME} (if you're running Nginx as web server) manually."
    fi
}

check_mlmmjadmin_installation()
{
    if [ ! -e /opt/mlmmjadmin ]; then
        echo "<<< ERROR >>> No mlmmjadmin installation found (/opt/mlmmjadmin)."
        echo "<<< ERROR >>> Please follow iRedMail upgrade tutorials to the latest"
        echo "<<< ERROR >>> stable release first, then come back to upgrade iRedAdmin-Pro."
        echo "<<< ERROR >>> mlmmj and mlmmjadmin was first introduced in iRedMail-0.9.8."
        echo "<<< ERROR >>> https://docs.iredmail.org/iredmail.releases.html"
        exit 255
    fi
}

install_pkg()
{
    echo "Install package: $@"

    if [ X"${DISTRO}" == X'RHEL' ]; then
        yum -y install $@
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        apt-get install -y $@
    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        cd /usr/ports/$@ && make install clean
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        pkg_add -r $@
    else
        echo "<< ERROR >> Please install package(s) manually: $@"
    fi
}

add_missing_parameter()
{
    # Usage: add_missing_parameter VARIABLE DEFAULT_VALUE [COMMENT]
    var="${1}"
    value="${2}"
    shift 2
    comment="$@"

    if ! grep "^${var}" ${IRA_CONF_PY} &>/dev/null; then
        if [ ! -z "${comment}" ]; then
            echo "# ${comment}" >> ${IRA_CONF_PY}
        fi

        if [ X"${value}" == X'True' -o X"${value}" == X'False' ]; then
            echo "${var} = ${value}" >> ${IRA_CONF_PY}
        else
            # Value must be quoted as string.
            echo "${var} = '${value}'" >> ${IRA_CONF_PY}
        fi
    fi
}

has_python_module()
{
    mod="$1"
    python -c "import $mod" &>/dev/null
    if [ X"$?" == X'0' ]; then
        echo 'YES'
    else
        echo 'NO'
    fi
}

# Remove all single quote and double quotes in string.
strip_quotes()
{
    # Read input from stdin
    str="$(cat <&0)"
    value="$(echo ${str} | tr -d '"' | tr -d "'")"
    echo "${value}"
}

get_iredadmin_setting()
{
    var="${1}"
    value="$(grep "^${var}" ${IRA_CONF_PY} | awk '{print $NF}' | strip_quotes)"
    echo "${value}"
}

check_dot_my_cnf()
{
    if egrep '^backend.*(mysql|ldap)' ${IRA_CONF_PY} &>/dev/null; then
        if [ ! -f ${MY_CNF} ]; then
            echo "<<< ERROR >>> File ${MY_CNF} not found."
            echo "<<< ERROR >>> Please add mysql root user and password in it like below, then run this script again."
            cat <<EOF

[client]
host=127.0.0.1
port=3306
user=${SQL_IREDADMIN_USER}
password="plain_password"

EOF

            exit 255
        fi

        # Check MySQL connection
        ${CMD_MYSQL} -e "SHOW DATABASES" &>/dev/null
        if [ X"$?" != X'0' ]; then
            echo "<<< ERROR >>> MySQL user name '${SQL_IREDADMIN_USER}' or password is incorrect in ${MY_CNF}, please double check."
            exit 255
        fi
    fi
}

check_mlmmjadmin_installation
check_dot_my_cnf

echo "* Detected Linux/BSD distribution: ${DISTRO}"
echo "* HTTP server root: ${HTTPD_SERVERROOT}"

if [ -L ${IRA_ROOT_DIR} ]; then
    export IRA_ROOT_REAL_DIR="$(readlink ${IRA_ROOT_DIR})"
    echo "* Found iRedAdmin directory: ${IRA_ROOT_DIR}, symbol link of ${IRA_ROOT_REAL_DIR}"
else
    echo "<<< ERROR >>> Directory (${IRA_ROOT_DIR}) is not a symbol link created by iRedMail. Exit."
    exit 255
fi

# Copy config file
if [ -f ${IRA_CONF_PY} ]; then
    echo "* Found iRedAdmin config file: ${IRA_CONF_PY}"
elif [ -f ${IRA_CONF_INI} ]; then
    echo "* Found iRedAdmin config file: ${IRA_CONF_INI}"
    echo "* Convert config file to new file name and format (settings.py)"
    cp ${IRA_CONF_INI} .
    bash convert_ini_to_py.sh settings.ini && \
        rm -f settings.ini && \
        mv settings.py ${IRA_CONF_PY} && \
        chmod 0400 ${IRA_CONF_PY}
else
    echo "<<< ERROR >>> Cannot find a valid config file (settings.py or settings.ini)."
    exit 255
fi

# Check whether current directory is iRedAdmin
PWD="$(pwd)"
if ! echo ${PWD} | grep 'iRedAdmin-.*/tools' >/dev/null; then
    echo "<<< ERROR >>> Cannot find new version of iRedAdmin in current directory. Exit."
    exit 255
fi

# Copy current directory to Apache server root
dir_new_version="$(dirname ${PWD})"
name_new_version="$(basename ${dir_new_version})"
NEW_IRA_ROOT_DIR="${HTTPD_SERVERROOT}/${name_new_version}"
if [ -d ${NEW_IRA_ROOT_DIR} ]; then
    COPY_FILES="${dir_new_version}/*"
    COPY_DEST_DIR="${NEW_IRA_ROOT_DIR}"
    #echo "<<< ERROR >>> Directory exist: ${NEW_IRA_ROOT_DIR}. Exit."
    #exit 255
else
    COPY_FILES="${dir_new_version}"
    COPY_DEST_DIR="${HTTPD_SERVERROOT}"
fi

echo "* Copying new version to ${NEW_IRA_ROOT_DIR}"
cp -rf ${COPY_FILES} ${COPY_DEST_DIR}

# Copy old config files
echo "* Copy ${IRA_CONF_PY}."
cp -p ${IRA_CONF_PY} ${NEW_IRA_ROOT_DIR}/

if [ -f ${IRA_CUSTOM_CONF_PY} ]; then
    echo "* Copy ${IRA_CUSTOM_CONF_PY}."
    cp -p ${IRA_CUSTOM_CONF_PY} ${NEW_IRA_ROOT_DIR}
fi

# Copy hooks.py. It's ok if missing.
if [ -f ${IRA_ROOT_DIR}/hooks.py ]; then
    echo "* Copy ${IRA_ROOT_DIR}/hooks.py."
    cp -p ${IRA_ROOT_DIR}/hooks.py ${NEW_IRA_ROOT_DIR}/ &>/dev/null
fi

# Copy custom files under 'tools/'. It's ok if missing.
cp -p ${IRA_ROOT_DIR}/tools/*.custom ${NEW_IRA_ROOT_DIR}/tools/ &>/dev/null
cp -p ${IRA_ROOT_DIR}/tools/*.last-time ${NEW_IRA_ROOT_DIR}/tools/ &>/dev/null

# Template file renamed
if [ -f "${IRA_ROOT_DIR}/tools/notify_quarantined_recipients.custom.html" ]; then
    echo "* Copy ${IRA_ROOT_DIR}/tools/notify_quarantined_recipients.custom.html"
    cp -f ${IRA_ROOT_DIR}/tools/notify_quarantined_recipients.custom.html \
        ${NEW_IRA_ROOT_DIR}/tools/notify_quarantined_recipients.html.custom
fi

# Copy favicon.ico and brand logo image.
for var in 'BRAND_FAVICON' 'BRAND_LOGO'; do
    if grep "^${var}\>" ${IRA_CONF_PY} &>/dev/null; then
        _file=$(grep "^${var}\>" ${IRA_CONF_PY} | awk '{print $NF}' | tr -d '"' | tr -d "'")
        echo "* Copy file ${IRA_ROOT_DIR}/static/${_file}"
        cp -f ${IRA_ROOT_DIR}/static/${_file} ${NEW_IRA_ROOT_DIR}/static/
    fi
done

# iredadmin is now ran as a standalone uwsgi instance, we don't need uwsgi
# daemon service anymore.
_uwsgi_confs='
    /etc/uwsgi.d/iredadmin.ini
    /etc/uwsgi-available/iredadmin.ini
    /etc/uwsgi/apps-enabled/iredadmin.ini &>/dev/null
    /etc/uwsgi/apps-available/iredadmin.ini &>/dev/null
    /usr/local/etc/uwsgi/iredadmin.ini
    /etc/uwsgi-enabled/iredadmin.ini &>/dev/null
    /etc/uwsgi-available/iredadmin.ini &>/dev/null
'

for f in ${_uwsgi_confs}; do
    rm -f ${f} &>/dev/null
done

# Update Nginx template file
export _restart_nginx='NO'
for f in ${NGINX_SNIPPET_CONF} ${NGINX_SNIPPET_CONF2} ${NGINX_SNIPPET_CONF3}; do
    if [[ -f ${f} ]]; then
        if grep 'unix:.*iredadmin.socket' ${f} &>/dev/null; then
            export _restart_nginx='YES'
            perl -pi -e 's#uwsgi_pass unix:.*iredadmin.socket;#uwsgi_pass 127.0.0.1:7791;#g' ${f}
        fi
    fi
done

if [[ X"${_restart_nginx}" == X'YES' ]]; then
    restart_service nginx
fi

# Update uwsgi ini config file
if [ -d ${NEW_IRA_ROOT_DIR}/rc_scripts/uwsgi ]; then
    perl -pi -e 's#^chdir = (.*)#chdir = $ENV{HTTPD_SERVERROOT}/iredadmin#g' ${NEW_IRA_ROOT_DIR}/rc_scripts/uwsgi/*.ini
fi

# Copy rc script or systemd service file
if [ X"${USE_SYSTEMD}" == X'YES' ]; then
    echo "* Remove existing systemd service files."
    rm -f ${SYSTEMD_SERVICE_DIR}/iredadmin.service &>/dev/null
    rm -f ${SYSTEMD_SERVICE_DIR2}/iredadmin.service &>/dev/null
    rm -f ${SYSTEMD_SERVICE_USER_DIR}/iredadmin.service &>/dev/null

    echo "* Copy systemd service file: ${SYSTEMD_SERVICE_DIR}/iredadmin.service."
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp -f ${NEW_IRA_ROOT_DIR}/rc_scripts/systemd/rhel.service ${SYSTEMD_SERVICE_DIR}/iredadmin.service
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' ${SYSTEMD_SERVICE_DIR}/iredadmin.service
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        cp -f ${NEW_IRA_ROOT_DIR}/rc_scripts/systemd/debian.service ${SYSTEMD_SERVICE_DIR}/iredadmin.service
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' ${SYSTEMD_SERVICE_DIR}/iredadmin.service
    fi
    chmod -R 0644 ${SYSTEMD_SERVICE_DIR}/iredadmin.service
    systemctl daemon-reload &>/dev/null
else
    if [ X"${DISTRO}" == X'RHEL' ]; then
        cp ${NEW_IRA_ROOT_DIR}/rc_scripts/iredadmin.rhel /etc/init.d/iredadmin
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' /etc/init.d/iredadmin
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        cp ${NEW_IRA_ROOT_DIR}/rc_scripts/iredadmin.debian /etc/init.d/iredadmin
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' /etc/init.d/iredadmin
    elif [ X"${DISTRO}" == X"FREEBSD" ]; then
        cp ${NEW_IRA_ROOT_DIR}/rc_scripts/iredadmin.freebsd /usr/local/etc/rc.d/iredadmin
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' /usr/local/etc/rc.d/iredadmin

        # Remove 'uwsgi_iredadmin_flags=' in /etc/rc.conf.local
        if [ -f /etc/rc.conf.local ]; then
            perl -pi -e 's#^uwsgi_iredadminflags=.*##g' /etc/rc.conf.local
        fi
    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp ${NEW_IRA_ROOT_DIR}/rc_scripts/iredadmin.openbsd ${DIR_RC_SCRIPTS}/iredadmin
        perl -pi -e 's#/opt/www#$ENV{HTTPD_SERVERROOT}#g' /etc/rc.d/iredadmin

        cp -f ${NEW_IRA_ROOT_DIR}/rc_scripts/iredadmin.openbsd /etc/rc.d/iredadmin
        chmod 0755 /etc/rc.d/iredadmin

        # Remove 'uwsgi_flags=' in /etc/rc.conf.local
        if [ -f /etc/rc.conf.local ]; then
            perl -pi -e 's#^uwsgi_flags=.*iredadmin.*##g' /etc/rc.conf.local
        fi
    fi
fi

# Set owner and permission.
chown -R ${IRA_HTTPD_USER}:${IRA_HTTPD_GROUP} ${NEW_IRA_ROOT_DIR}
chmod -R 0555 ${NEW_IRA_ROOT_DIR}
chmod 0400 ${NEW_IRA_ROOT_DIR}/settings.py

echo "* Removing old symbol link ${IRA_ROOT_DIR}"
rm -f ${IRA_ROOT_DIR}

echo "* Creating symbol link ${IRA_ROOT_DIR} to ${NEW_IRA_ROOT_DIR}"
cd ${HTTPD_SERVERROOT}
ln -s ${name_new_version} iredadmin

# Delete all sessions to force admins to re-login.
cd ${NEW_IRA_ROOT_DIR}/tools/
python delete_sessions.py

# Add missing setting parameters.
if grep 'amavisd_enable_logging.*True.*' ${IRA_CONF_PY} &>/dev/null; then
    add_missing_parameter 'amavisd_enable_policy_lookup' True 'Enable per-recipient spam policy, white/blacklist.'
else
    add_missing_parameter 'amavisd_enable_policy_lookup' False 'Enable per-recipient spam policy, white/blacklist.'
fi

if ! grep '^iredapd_' ${IRA_CONF_PY} &>/dev/null; then
    add_missing_parameter 'iredapd_enabled' True 'Enable iRedAPD integration.'

    # Get iredapd db password from /opt/iredapd/settings.py.
    if [ -f /opt/iredapd/settings.py ]; then
        grep '^iredapd_db_' /opt/iredapd/settings.py >> ${IRA_CONF_PY}
        perl -pi -e 's#iredapd_db_server#iredapd_db_host#g' ${IRA_CONF_PY}
    else
        # Check backend.
        if egrep '^backend.*pgsql' ${IRA_CONF_PY} &>/dev/null; then
            export IREDAPD_DB_PORT='5432'
        else
            export IREDAPD_DB_PORT='3306'
        fi

        add_missing_parameter 'iredapd_db_host' '127.0.0.1'
        add_missing_parameter 'iredapd_db_port' ${IREDAPD_DB_PORT}
        add_missing_parameter 'iredapd_db_name' 'iredapd'
        add_missing_parameter 'iredapd_db_user' 'iredapd'
        add_missing_parameter 'iredapd_db_password' 'password'
    fi
fi
perl -pi -e 's#iredapd_db_server#iredapd_db_host#g' ${IRA_CONF_PY}

# FreeBSD uses /var/run/log for syslog.
if [ X"${DISTRO}" == X'FREEBSD' ]; then
    add_missing_parameter 'SYSLOG_SERVER' '/var/run/log'
fi

#
# Enable mlmmj integration
#
if [ -e /opt/mlmmjadmin ]; then
    echo "* Enable mlmmj integration."
    # Force to use backend `bk_none`.
    perl -pi -e 's#^(backend_api).*#${1} = "bk_none"#g' /opt/mlmmjadmin/settings.py

    if egrep '^backend.*(ldap)' ${IRA_CONF_PY} &>/dev/null; then
        perl -pi -e 's#^(backend_cli).*#${1} = "bk_iredmail_ldap"#g' /opt/mlmmjadmin/settings.py
    else
        perl -pi -e 's#^(backend_cli).*#${1} = "bk_iredmail_sql"#g' /opt/mlmmjadmin/settings.py
    fi

    # Add parameter `mlmmjadmin_api_auth_token` if missing
    if ! grep '^mlmmjadmin_api_auth_token' ${IRA_CONF_PY}; then
        # Get first api auth token
        token=$(grep '^api_auth_tokens' /opt/mlmmjadmin/settings.py | awk -F"[=\']" '{print $3}' | tr -d '\n')
        echo -e "\nmlmmjadmin_api_auth_token = '${token}'" >> ${IRA_CONF_PY}
    fi

    echo "* Restarting service: mlmmjadmin."
    restart_service mlmmjadmin
fi

# Change old parameter names to the new ones:
#
#   - ADDITION_USER_SERVICES -> ADDITIONAL_ENABLED_USER_SERVICES
#   - LDAP_SERVER_NAME -> LDAP_SERVER_PRODUCT_NAME
perl -pi -e 's#ADDITION_USER_SERVICES#ADDITIONAL_ENABLED_USER_SERVICES#g' ${IRA_CONF_PY}
perl -pi -e 's#LDAP_SERVER_NAME#LDAP_SERVER_PRODUCT_NAME#g' ${IRA_CONF_PY}

# Remove deprecated setting: ENABLE_SELF_SERVICE, it's now a per-domain setting.
perl -pi -e 's#^(ENABLE_SELF_SERVICE.*)##g' ${IRA_CONF_PY}

# Check dependent packages. Prompt to install missed ones manually.
echo "* Check and install dependent Python modules:"
echo "  + [required] json or simplejson"
if [ X"$(has_python_module json)" == X'NO' \
     -a X"$(has_python_module simplejson)" == X'NO' ]; then
    install_pkg ${DEP_PY_JSON}
fi

echo "  + [required] dnspython"
[ X"$(has_python_module dns)" == X'NO' ] && install_pkg ${DEP_PY_DNS}

echo "  + [required] pycurl"
[ X"$(has_python_module pycurl)" == X'NO' ] && install_pkg ${DEP_PY_CURL}

echo "  + [required] requests"
[ X"$(has_python_module requests)" == X'NO' ] && install_pkg ${DEP_PY_REQUESTS}


#------------------------------------------
# Add new SQL tables, drop deprecated ones.
#
export ira_db_host="$(get_iredadmin_setting 'iredadmin_db_host')"
export ira_db_port="$(get_iredadmin_setting 'iredadmin_db_port')"
export ira_db_name="$(get_iredadmin_setting 'iredadmin_db_name')"
export ira_db_user="$(get_iredadmin_setting 'iredadmin_db_user')"
export ira_db_password="$(get_iredadmin_setting 'iredadmin_db_password')"

#
# Update sql tables
#
psql_conn="psql -h ${ira_db_host} \
                -p ${ira_db_port} \
                -U ${ira_db_user} \
                -d ${ira_db_name}"

if egrep '^backend.*(mysql|ldap)' ${IRA_CONF_PY} &>/dev/null; then
    echo "* Check SQL tables, and add missed ones - if there's any"
    ${CMD_MYSQL} ${ira_db_name} -e "SOURCE ${IRA_ROOT_DIR}/SQL/iredadmin.mysql"
    ${CMD_MYSQL} ${ira_db_name} -e "ALTER TABLE log MODIFY COLUMN msg TEXT;"

    # Add column `tracking.id`.
    ${CMD_MYSQL} ${ira_db_name} -e "DESC tracking \G" | grep 'Field: id' &>/dev/null
    if [ X"$?" != X'0' ]; then
        ${CMD_MYSQL} ${ira_db_name} -e "ALTER TABLE tracking ADD COLUMN id BIGINT(20) UNSIGNED AUTO_INCREMENT PRIMARY KEY;"
    fi

    # Set column `id` to `PRIMARY KEY`
    _tables='deleted_mailboxes updatelog log tracking'
    for _table in ${_tables}; do
        ${CMD_MYSQL} ${ira_db_name} -e "DESC ${_table}" | grep '^id.*PRI.*auto_increment' &>/dev/null

        if [ X"$?" != X'0' ]; then
            ${CMD_MYSQL} ${ira_db_name} -e "ALTER TABLE ${_table} ADD PRIMARY KEY (id)"
        fi
    done

elif egrep '^backend.*pgsql' ${IRA_CONF_PY} &>/dev/null; then
    export PGPASSWORD="${ira_db_password}"

    # Allow log.msg to store long text.
    ${psql_conn} <<EOF
ALTER TABLE log ALTER COLUMN msg TYPE TEXT;
EOF

    # SQL table: tracking.
    ${psql_conn} -c '\d' | grep '\<tracking\>' &>/dev/null
    if [ X"$?" != X'0' ]; then
        echo "* [SQL] Add new table: iredadmin.tracking."

        ${psql_conn} <<EOF
CREATE TABLE tracking (
    id SERIAL PRIMARY KEY,
    k VARCHAR(50) NOT NULL,
    v TEXT,
    time TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_tracking_k ON tracking (k);
EOF
    fi

    # Set column `tracking.id` to `PRIMARY KEY`

    # SQL table: domain_ownership.
    ${psql_conn} -c '\d' | grep '\<domain_ownership\>' &>/dev/null
    if [ X"$?" != X'0' ]; then
        echo "* [SQL] Add new table: iredadmin.domain_ownership."

        ${psql_conn} <<EOF
CREATE TABLE domain_ownership (
    id SERIAL PRIMARY KEY,
    admin VARCHAR(255) NOT NULL DEFAULT '',
    domain VARCHAR(255) NOT NULL DEFAULT '',
    alias_domain VARCHAR(255) NOT NULL DEFAULT '',
    verify_code VARCHAR(100) NOT NULL DEFAULT '',
    verified INT2 NOT NULL DEFAULT 0,
    message TEXT,
    last_verify TIMESTAMP NULL DEFAULT NULL,
    expire INT DEFAULT 0
);
CREATE UNIQUE INDEX idx_ownership_1 ON domain_ownership (admin, domain, alias_domain);
CREATE INDEX idx_ownership_2 ON domain_ownership (verified);
EOF
    fi

    # SQL table: newsletter_subunsub_confirms.
    ${psql_conn} -c '\d' | grep '\<newsletter_subunsub_confirms\>' &>/dev/null
    if [ X"$?" != X'0' ]; then
        echo "* [SQL] Add new table: iredadmin.newsletter_subunsub_confirms."

        _sql="$(cat ${IRA_ROOT_DIR}/SQL/snippets/newsletter_subunsub_confirms.pgsql)"
        ${psql_conn} <<EOF
${_sql}
EOF
        unset _sql
    fi

    # SQL table: settings.
    ${psql_conn} -c '\d' | grep '\<settings\>' &>/dev/null
    if [ X"$?" != X'0' ]; then
        echo "* [SQL] Add new table: iredadmin.settings."

        _sql="$(cat ${IRA_ROOT_DIR}/SQL/snippets/settings.pgsql)"
        ${psql_conn} <<EOF
${_sql}
EOF
        unset _sql
    fi
fi

#------------------------------
# Cron job.
#
[[ -d ${CRON_SPOOL_DIR} ]] || mkdir -p ${CRON_SPOOL_DIR} &>/dev/null
if [[ ! -f ${CRON_FILE_ROOT} ]]; then
    touch ${CRON_FILE_ROOT} &>/dev/null
    chmod 0600 ${CRON_FILE_ROOT} &>/dev/null
fi

# cron job: clean up database.
if ! grep 'iredadmin/tools/cleanup_db.py' ${CRON_FILE_ROOT} &>/dev/null; then
    cat >> ${CRON_FILE_ROOT} <<EOF
# iRedAdmin: Clean up sql database.
1   *   *   *   *   ${PYTHON_BIN} ${IRA_ROOT_DIR}/tools/cleanup_db.py &>/dev/null
EOF
fi

# cron job: clean up database.
if ! grep 'iredadmin/tools/delete_mailboxes.py' ${CRON_FILE_ROOT} &>/dev/null; then
    cat >> ${CRON_FILE_ROOT} <<EOF
# iRedAdmin: Remove mailboxes which are scheduled to be removed.
1   3   *   *   *   ${PYTHON_BIN} ${IRA_ROOT_DIR}/tools/delete_mailboxes.py
EOF
fi

echo "* Clean up."
cd ${NEW_IRA_ROOT_DIR}/
rm -f settings.pyc settings.pyo tools/settings.py

echo "* iRedAdmin has been successfully upgraded."
restart_web_service

# Enable and restart service
enable_service iredadmin
restart_service iredadmin

echo "* Upgrading completed."

cat <<EOF
<<< NOTE >>> If iRedAdmin doesn't work as expected, please post your issue in
<<< NOTE >>> our online support forum: http://www.iredmail.org/forum/
EOF
