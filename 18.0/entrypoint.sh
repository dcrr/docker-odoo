#!/bin/bash

set -e

ODOO_CONF=$ODOO_CONF_FILE
if [ -f "$ODOO_PATH/config/odoo.conf" ]; then
    ODOO_CONF="$ODOO_PATH/config/odoo.conf"
fi

echo -e "odoo.conf: $ODOO_CONF"

# set the postgres database host, port, user and password according to the environment
: ${HOST:=${DB_HOST:='db'}}
: ${PORT:=${DB_PORT:=5432}}
: ${USER:=${DB_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DATABASE:=${DB_NAME:='odoo'}}

# Initialize virtual environment path
VENV_PATH="${ODOO_PATH}/config/venv"
mkdir -p "${ODOO_PATH}/config" 2>/dev/null || true

# Create virtual environment if it doesn't exist or is incomplete
if [ ! -x "$VENV_PATH/bin/python3" ] || [ ! -f "$VENV_PATH/bin/activate" ]; then
    if [ -d "$VENV_PATH" ]; then
        echo "Rebuilding virtual environment at $VENV_PATH..."
        python3 -m venv --clear "$VENV_PATH"
    else
        echo "Creating virtual environment at $VENV_PATH..."
        python3 -m venv "$VENV_PATH"
    fi
    chown -R odoo:odoo "$VENV_PATH" 2>/dev/null || true
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

HASH_DIR="$ODOO_PATH/config/requirements_hashes"
mkdir -p "$HASH_DIR" 2>/dev/null || true

echo "Bootstrapping pip in venv..."
if ! python3 -m pip --version >/dev/null 2>&1; then
    python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
fi

# Verify Python is from venv
echo "Using Python from: $(which python3)"
echo "Python version: $(python3 --version)"


hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        stat -c %Y "$file" 2>/dev/null || date +%s
    fi
}

hash_text() {
    local value="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$value" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$value" | md5sum | awk '{print $1}'
    fi
}

is_python_dist_satisfied() {
    local requirement="$1"
    python3 - <<PYEOF >/dev/null 2>&1
from pkg_resources import DistributionNotFound, VersionConflict, require

try:
    require(["$requirement"])
except (DistributionNotFound, VersionConflict):
    raise SystemExit(1)
PYEOF
}

ensure_python_dist() {
    local requirement="$1"

    if is_python_dist_satisfied "$requirement"; then
        return 0
    fi

    echo "Installing Python package $requirement in $VENV_PATH"
    python3 -m pip install "$requirement"
}

ensure_python_tooling() {
    ensure_python_dist "setuptools>=65.0,<81.0"
    ensure_python_dist "wheel"
    python3 -c "from pkg_resources import iter_entry_points; print('pkg_resources available')"
}

install_requirements_file() {
    local req_file="$1"
    local marker_name="$2"
    local label="$3"
    local marker hash

    [ -f "$req_file" ] || return 0

    marker="$HASH_DIR/${marker_name}.sha256"
    hash="$(hash_file "$req_file")"

    if [ -f "$marker" ] && [ "$(cat "$marker")" = "$hash" ]; then
        echo "Requirements unchanged for $label"
        return 0
    fi

    echo "Installing python requirements for $label"
    python3 -m pip install -r "$req_file"
    printf '%s' "$hash" > "$marker"

    if [ "$(id -u)" = "0" ]; then
        chown -R odoo:odoo "$marker" "$VENV_PATH" 2>/dev/null || true
    fi
}

validate_python_distribution() {
    local dist_name="$1"
    python3 - <<PYEOF >/dev/null 2>&1
from pkg_resources import DistributionNotFound, get_distribution

try:
    get_distribution("$dist_name")
except DistributionNotFound:
    raise SystemExit(1)
PYEOF
}

repair_core_python_stack_if_needed() {
    local missing=0

    for dist_name in gevent zope.event zope.interface; do
        if ! validate_python_distribution "$dist_name"; then
            echo "Missing Python distribution metadata for $dist_name in $VENV_PATH"
            missing=1
        fi
    done

    if [ "$missing" -eq 0 ]; then
        return 0
    fi

    echo "Reinstalling core event dependencies in venv..."
    python3 -m pip install --force-reinstall \
        "gevent==22.10.2" \
        "greenlet==2.0.2" \
        "zope.event" \
        "zope.interface"
}

ensure_python_tooling
echo "Virtual environment ready at $VENV_PATH"

# Initialize DB_ARGS as a proper array
DB_ARGS=("--config=${ODOO_CONF}")

function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_CONF" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
    fi
}

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

install_addons_requirements() {
    echo "Checking requirements for addons paths..."
    addons_path=$(grep -E "^\s*addons_path\s*=" "$ODOO_CONF" | sed 's/.*=\s*//' | tr -d '\r')
    if [ -z "$addons_path" ]; then
        echo "Warning: addons_path not found in $ODOO_CONF"
        return
    fi

    IFS=',' read -ra addon_dirs <<< "$addons_path"

    echo "Addons paths found: addon_dirs= ${addon_dirs[@]}"
    for addon_path in "${addon_dirs[@]}"; do
        addon_path=$(echo "$addon_path" | xargs)

        [ -z "$addon_path" ] && continue

        if [[ "$addon_path" != /* ]]; then
            addon_path="$ODOO_SRC/$addon_path"
        fi

        [ -d "$addon_path" ] || continue

        name="$(basename "$addon_path")"
        if [ "$name" = "addons" ] || [ "$name" = "$ODOO_VERSION" ]; then
            continue
        fi

        req="$addon_path/requirements.txt"
        if [ -f "$req" ]; then
            repo_key="$(hash_text "$addon_path")"
            if ! install_requirements_file "$req" "addon_${repo_key}" "addon repo: $name"; then
                echo "Warning: pip install failed for $req" >&2
            fi
        fi
    done

    echo "End of requirements checking"
}

install_requirements_file "$ODOO_PATH/requirements.txt" "odoo_base" "Odoo base"
repair_core_python_stack_if_needed
install_addons_requirements
ensure_python_tooling

ODOO_EXEC="$ODOO_SRC/odoo/odoo-bin"

# Create a persistent wrapper script that runs Odoo with the DB args
DB_ARGS_ESC=""
for a in "${DB_ARGS[@]}"; do DB_ARGS_ESC="$DB_ARGS_ESC $(printf '%q' "$a")"; done

# Install the wrapper inside the venv so interactive shells can always find it.
TARGET_DIR="$VENV_PATH/bin"
ODOO_CMD="$TARGET_DIR/odoo_cmd"
ODOO_BIN="$TARGET_DIR/odoo"

# write wrapper with venv activation and ODOO_EXEC, ODOO_CONF and DB args
cat > "$ODOO_CMD" <<EOF
#!/bin/bash

set -e

source "$VENV_PATH/bin/activate"

if ! python3 -c "import pkg_resources" >/dev/null 2>&1; then
    python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
    python3 -m pip install --force-reinstall "setuptools>=65.0,<81.0"
fi

exec python3 "$ODOO_EXEC" --config="$ODOO_CONF" $DB_ARGS_ESC "\$@"
EOF

chmod +x "$ODOO_CMD" 2>/dev/null || true

# create a convenient 'odoo' entrypoint that delegates to odoo_cmd
cat > "$ODOO_BIN" <<'EOF'
#!/bin/bash
exec "$(dirname "$0")/odoo_cmd" "$@"
EOF

chmod +x "$ODOO_BIN" 2>/dev/null || true

# Add venv to PATH so interactive shells can use `odoo`
export PATH="$VENV_PATH/bin:$PATH"

# If no arguments provided, start odoo server
if [ $# -eq 0 ]; then
    exec python3 "$ODOO_EXEC" "${DB_ARGS[@]}"
fi

case "$1" in
    -- | odoo)
        shift
        exec python3 "$ODOO_EXEC" "$@" "${DB_ARGS[@]}"
        ;;
    -*)
        exec python3 "$ODOO_EXEC" "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
        ;;
esac
