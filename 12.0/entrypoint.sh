#!/bin/bash

set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

ODOO_CONF=$ODOO_CONF_FILE
if [ -f "$ODOO_PATH/config/odoo.conf" ]; then
    ODOO_CONF="$ODOO_PATH/config/odoo.conf"
fi

echo -e "\n-------- ODOO_CONF $ODOO_CONF --------"

# set the postgres database host, port, user and password according to the environment
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

DB_ARGS=(" --config=${ODOO_CONF}")
function check_config() {
    param="$1"
    value="$2"
    # if the given parameter is not found in the ODOO_CONF file,
    # add it to the DB_ARGS variable with the given value.
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_CONF" ; then
        DB_ARGS+=" --${param} ${value}"
    fi;
}
# pass postgres parameters as arguments to the odoo process 
# if not present in the config file
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

function check_odoo_repo() {
    if [ ! -d "$ODOO_SRC/odoo" ]; then
        usermod -u 1000 odoo
        groupmod -g 1000 odoo
        echo -e "\n-------- cloning odoo repository --------"
        cd $ODOO_SRC
        git clone https://github.com/odoo/odoo.git --depth=1 -b $ODOO_VERSION
        chown -R odoo:odoo /home/odoo
   fi;
}

check_odoo_repo
ODOO_EXEC="$ODOO_SRC/odoo/odoo-bin"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            python3 $ODOO_EXEC $@
        else
            python3 $ODOO_EXEC $@ ${DB_ARGS[@]}
        fi
        ;;
    -*)
        python3 $ODOO_EXEC $@ ${DB_ARGS[@]}
        ;;
    *)
        exec "$@"
esac

exit 1
