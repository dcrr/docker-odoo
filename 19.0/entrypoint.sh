#!/bin/bash

set -e

ODOO_CONF=$ODOO_CONF_FILE
if [ -f "$ODOO_PATH/config/odoo.conf" ]; then
    ODOO_CONF="$ODOO_PATH/config/odoo.conf"
fi

echo -e "\n-------- ODOO_CONF $ODOO_CONF --------"

# set the postgres database host, port, user and password according to the environment
: ${HOST:=${DB_HOST:='db'}}
: ${PORT:=${DB_PORT:=5432}}
: ${USER:=${DB_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DATABASE:=${DB_NAME:='odoo'}}

# Initialize DB_ARGS as a proper array
DB_ARGS=("--config=${ODOO_CONF}")

function check_config() {
    param="$1"
    value="$2"
    # if the given parameter is not found in the ODOO_CONF file,
    # add it to the DB_ARGS array with the given value.
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_CONF" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
    fi
}

# pass postgres parameters as arguments to the odoo process 
# if not present in the config file
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"
check_config "database" "$DATABASE"

function check_odoo_repo() {
    if [ ! -d "$ODOO_SRC/odoo" ]; then
        echo -e "\n-------- cloning odoo repository --------"
        cd "$ODOO_SRC"
        git clone https://github.com/odoo/odoo.git --depth=1 -b $ODOO_VERSION
   fi
}

check_odoo_repo

# To install $ODOO_SRC/extra_addons/* requirements.txt
install_addons_requirements() {
    echo "Checking addon requirements in $ODOO_SRC ..."
    # dir to store hashes inside container (not on user bind-mount)
    HASH_DIR="/home/odoo"
    mkdir -p "$HASH_DIR" 2>/dev/null || true

    for d in "$ODOO_SRC/extra_addons"/*; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        # skip core odoo repo
        [ "$name" = "odoo" ] && continue
        req="$d/requirements.txt"
        marker="$HASH_DIR/${name}.sha256"
        if [ -f "$req" ]; then
            # compute hash (fallback to mtime if sha256sum not available)
            if command -v sha256sum >/dev/null 2>&1; then
                hash="$(sha256sum "$req" | awk '{print $1}')"
            else
                hash="$(stat -c %Y "$req" 2>/dev/null || date +%s)"
            fi

            if [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$hash" ]; then
                echo "Installing python requirements for addon repo: $name"
                if command -v pip3 >/dev/null 2>&1; then
                    if pip3 install --no-cache-dir -r "$req"; then
                        printf '%s' "$hash" > "$marker"
                        echo "Requirements installed for $name"
                    else
                        echo "Warning: pip install failed for $req" >&2
                    fi
                else
                    echo "Error: pip3 not found, cannot install $req" >&2
                fi

                if [ "$(id -u)" = "0" ]; then
                    chown -R odoo:odoo "$d" "$marker" 2>/dev/null || true
                fi
            else
                echo "Requirements up-to-date for $name"
            fi
        fi
    done
}

install_addons_requirements

ODOO_EXEC="$ODOO_SRC/odoo/odoo-bin"


# Create a persistent wrapper script that runs Odoo with the DB args
DB_ARGS_ESC=""
for a in "${DB_ARGS[@]}"; do DB_ARGS_ESC="$DB_ARGS_ESC $(printf '%q' "$a")"; done

# prefer /usr/local/bin, fallback to a user-writable bin in /home/odoo
TARGET_DIR="/usr/local/bin"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="/home/odoo/.local/bin"
    mkdir -p "$TARGET_DIR" 2>/dev/null || true
fi
ODOO_CMD="$TARGET_DIR/odoo_cmd"
ODOO_BIN="$TARGET_DIR/odoo"

# write wrapper with expanded ODOO_EXEC and DB args; keep "$@" literal
cat > "$ODOO_CMD" <<EOF
#!/bin/bash
exec python3 "$ODOO_EXEC" $DB_ARGS_ESC "\$@"
EOF

chmod +x "$ODOO_CMD" 2>/dev/null || true

# create a convenient 'odoo' entrypoint that delegates to odoo_cmd
cat > "$ODOO_BIN" <<'EOF'
#!/bin/bash
exec "$(dirname "$0")/odoo_cmd" "$@"
EOF

chmod +x "$ODOO_BIN" 2>/dev/null || true

# if running as root try to chown the wrapper and related files, ignore failures
if [ "$(id -u)" = "0" ]; then
    chown odoo:odoo "$ODOO_CMD" "$ODOO_BIN" 2>/dev/null || true
fi

# ensure interactive shells include the fallback bin in PATH and that login shells source .bashrc
if [ "$TARGET_DIR" != "/usr/local/bin" ]; then
    mkdir -p /home/odoo 2>/dev/null || true
    if ! grep -q 'export PATH=.*\.local\/bin' /home/odoo/.bashrc 2>/dev/null; then
        cat >> /home/odoo/.bashrc <<'BASHRC'
# add local user bin to PATH
export PATH="$HOME/.local/bin:$PATH"
BASHRC
        if [ "$(id -u)" = "0" ]; then
            chown odoo:odoo /home/odoo/.bashrc 2>/dev/null || true
        fi
    fi
    # ensure login shells source .bashrc
    if [ ! -f /home/odoo/.bash_profile ]; then
        cat > /home/odoo/.bash_profile <<'BASH_PROFILE'
# Source .bashrc for login shells so PATH and helpers are available
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
BASH_PROFILE
        if [ "$(id -u)" = "0" ]; then
            chown odoo:odoo /home/odoo/.bash_profile 2>/dev/null || true
        fi
    fi
fi

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec python3 "$ODOO_EXEC" "$@"
        else
            exec python3 "$ODOO_EXEC" "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        exec python3 "$ODOO_EXEC" "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac
