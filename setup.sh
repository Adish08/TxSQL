#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# TxSQL - MariaDB installer & helper commands for Termux
# Repo    : https://github.com/Adish08/TxSQL
# Install : curl -fsSL https://adish.sagarawat.in/txsql | bash
# Commands: startsql  stopsql  sqlstatus  sqlpass  sqlreset  sqluninstall
# Safe to re-run: existing databases are never touched.
# ==============================================================================
# Everything is inside one function that is called on the last line, so a
# half-downloaded script never runs and child commands cannot eat our stdin.

txsql_install_main() {
    set -u

    [ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || { echo "[ERROR] Run this inside Termux on Android."; exit 1; }
    [ "$(id -u)" -ne 0 ] || { echo "[ERROR] Do not run as root. Use your normal Termux user."; exit 1; }

    local TXSQL_FILE="$HOME/.txsql.sh"
    local BASHRC="$HOME/.bashrc"

    # ---- Helper commands: written first, then reused by this installer -------
    cat << 'EOF' > "$TXSQL_FILE"
# ~/.txsql.sh - managed by TxSQL. Re-running the installer refreshes this file.

_TX_URL="https://adish.sagarawat.in/txsql"  
_TX_R=$'\033[0;31m'; _TX_G=$'\033[0;32m'; _TX_Y=$'\033[1;33m'
_TX_C=$'\033[0;36m'; _TX_B=$'\033[1m';    _TX_N=$'\033[0m'

_tx_info() { printf '%s[INFO]%s %s\n' "$_TX_C" "$_TX_N" "$*"; }
_tx_ok()   { printf '%s✔ %s%s\n' "$_TX_G" "$*" "$_TX_N"; }
_tx_warn() { printf '%s[WARN]%s %s\n' "$_TX_Y" "$_TX_N" "$*" >&2; }
_tx_err()  { printf '%s[ERROR]%s %s\n' "$_TX_R" "$_TX_N" "$*" >&2; }
_tx_step() { printf '\n%s%s==> %s%s\n' "$_TX_G" "$_TX_B" "$*" "$_TX_N"; }

# Find the MariaDB programs (new names first, old names as fallback)
_tx_bins() {
    _TX_CLIENT=$(command -v mariadb || command -v mysql)
    _TX_ADMIN=$(command -v mariadb-admin || command -v mysqladmin)
    _TX_SAFE=$(command -v mariadbd-safe || command -v mysqld_safe)
    _TX_INIT=$(command -v mariadb-install-db || command -v mysql_install_db)
    _TX_DATADIR="$PREFIX/var/lib/mysql"
    _TX_LOG="$_TX_DATADIR/txsql-error.log"
    [ -n "$_TX_CLIENT" ] && [ -n "$_TX_ADMIN" ] && [ -n "$_TX_SAFE" ] && [ -n "$_TX_INIT" ] \
        || { _tx_err "MariaDB is not installed. Run: curl -fsSL $_TX_URL | bash"; return 1; }
}

_tx_up()      { "$_TX_ADMIN" ping --silent >/dev/null 2>&1; }
_tx_root_ok() { "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; }

# Create a fresh, empty database (root has no password)
_tx_init_db() {
    local initlog="$PREFIX/tmp/txsql-init.log"
    mkdir -p "$_TX_DATADIR" "$PREFIX/etc/my.cnf.d" "$PREFIX/var/run/mysqld"
    if "$_TX_INIT" --user="$(whoami)" --auth-root-authentication-method=normal --datadir="$_TX_DATADIR" </dev/null >"$initlog" 2>&1 \
       || "$_TX_INIT" --datadir="$_TX_DATADIR" </dev/null >>"$initlog" 2>&1; then
        return 0
    fi
    _tx_err "Database initialisation failed. Check free storage. Details: $initlog"
    return 1
}

# Start the server if it is not already running
_tx_ensure_server() {
    _tx_bins || return 1
    [ -d "$_TX_DATADIR/mysql" ] || { _tx_warn "Database missing, initialising..."; _tx_init_db || return 1; }
    mkdir -p "$PREFIX/var/run/mysqld"
    if _tx_up; then _tx_ok "MariaDB server is already running."; return 0; fi

    printf '%s➤ Starting MariaDB server...%s\n' "$_TX_C" "$_TX_N"
    command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1
    (nohup "$_TX_SAFE" --datadir="$_TX_DATADIR" >"$_TX_LOG" 2>&1 </dev/null &)

    local i=0
    until _tx_up; do
        sleep 1; i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            _tx_err "Server did not start within 30 seconds. Last log lines:"
            tail -n 10 "$_TX_LOG" >&2 2>/dev/null
            return 1
        fi
    done
    _tx_ok "MariaDB server started."
}

# Stop the server without a password prompt; returns 0 when it is down
_tx_stop_server() {
    _tx_up || return 0
    "$_TX_ADMIN" -u root shutdown >/dev/null 2>&1 || "$_TX_ADMIN" -u "$(whoami)" shutdown >/dev/null 2>&1
    local i=0
    while _tx_up && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
    if _tx_up && command -v pkill >/dev/null 2>&1; then
        pkill -TERM -x mariadbd 2>/dev/null || pkill -TERM -x mysqld 2>/dev/null
        sleep 3
        _tx_up && { pkill -KILL -x mariadbd 2>/dev/null || pkill -KILL -x mysqld 2>/dev/null; sleep 1; }
    fi
    ! _tx_up
}

# Make sure root can log in without a password if it has none (fixes old,
# socket-locked installs). Returns 0 if root works passwordless afterwards.
_tx_repair_root() {
    _tx_root_ok && return 0
    local u; u="$(whoami)"
    "$_TX_CLIENT" -u "$u" --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1 || return 1
    "$_TX_CLIENT" -u "$u" -e "SELECT 1 FROM mysql.global_priv WHERE User='root' AND Host='localhost' AND (JSON_VALUE(Priv, '\$.authentication_string') = '' OR JSON_VALUE(Priv, '\$.authentication_string') IS NULL);" 2>/dev/null | grep -q 1 || return 1
    "$_TX_CLIENT" -u "$u" -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD(''); GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" >/dev/null 2>&1
    _tx_root_ok
}

startsql() {
    _tx_ensure_server || return 1
    printf '%s➤ Connecting to MariaDB as root...%s\n' "$_TX_C" "$_TX_N"
    printf "  Tip: type %sEXIT;%s to leave SQL. Typing exit again at '~ \$' closes Termux.\n\n" "$_TX_B" "$_TX_N"
    if _tx_repair_root; then
        "$_TX_CLIENT" -u root
        return $?
    fi
    printf '%s🔒 Password required for root.%s (Typing is invisible. Forgot it? Run %ssqlreset%s)\n' "$_TX_Y" "$_TX_N" "$_TX_B" "$_TX_N"
    "$_TX_CLIENT" -u root -p
}

stopsql() {
    _tx_bins || return 1
    _tx_up || { printf '%sℹ MariaDB server is not running.%s\n' "$_TX_Y" "$_TX_N"; return 0; }
    printf '%s➤ Stopping MariaDB server...%s\n' "$_TX_C" "$_TX_N"
    if _tx_stop_server; then
        _tx_ok "MariaDB server stopped."
    else
        printf '%sRoot password needed to stop it:%s\n' "$_TX_Y" "$_TX_N"
        "$_TX_ADMIN" -u root -p shutdown
    fi
}

sqlstatus() {
    _tx_bins || return 1
    if _tx_up; then
        _tx_ok "MariaDB server is RUNNING."
        "$_TX_ADMIN" version 2>/dev/null
    else
        printf '%s✖ MariaDB server is STOPPED.%s Run %sstartsql%s to start it.\n' "$_TX_Y" "$_TX_N" "$_TX_B" "$_TX_N"
    fi
}

sqlpass() {
    _tx_ensure_server || return 1
    printf '\n%s=== Set, change or remove the MariaDB root password ===%s\n' "$_TX_C" "$_TX_N"
    echo "Classroom tip: do not use a real password on a shared screen."

    local cur="" new="" again="" esc sql
    if ! _tx_repair_root; then
        printf "Enter CURRENT root password: "; IFS= read -rs cur; printf '\n'
        if ! MYSQL_PWD="$cur" "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
            _tx_err "Current password is incorrect."
            echo "  Forgot it? 'sqlreset' wipes all databases and starts fresh."
            return 1
        fi
    fi

    printf "Enter NEW password (leave empty to remove the password): "; IFS= read -rs new; printf '\n'
    printf "Confirm NEW password: "; IFS= read -rs again; printf '\n'
    [ "$new" = "$again" ] || { _tx_err "Passwords do not match. Nothing was changed."; return 1; }

    # escape backslashes and single quotes for the SQL string
    esc=$(printf '%s' "$new" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g")
    sql="ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${esc}'); FLUSH PRIVILEGES;"

    if MYSQL_PWD="$cur" "$_TX_CLIENT" -u root -e "$sql"; then
        if [ -z "$new" ]; then _tx_ok "Password removed. startsql will log you in automatically."
        else _tx_ok "Root password updated. startsql will now ask for it."; fi
    else
        _tx_err "Failed to update the password."
        return 1
    fi
}

sqlreset() {
    _tx_bins || return 1
    printf '\n%s WARNING: this PERMANENTLY DELETES all databases and passwords in:%s\n  %s\n' "$_TX_R" "$_TX_N" "$_TX_DATADIR"
    echo "MariaDB stays installed and is re-created empty."
    local c=""
    printf 'Type %sRESET%s (capitals) to confirm, anything else cancels: ' "$_TX_B" "$_TX_N"
    IFS= read -r c
    [ "$c" = "RESET" ] || { echo "Cancelled. No data was deleted."; return 0; }

    _tx_stop_server || { _tx_err "Could not stop the server. Close Termux fully, reopen it and try again."; return 1; }
    rm -rf "${_TX_DATADIR:?}"
    _tx_init_db || return 1
    _tx_ok "Database reset complete. Run 'startsql' to open a fresh SQL shell."
}

sqluninstall() {
    _tx_bins || return 1
    printf '\n%s WARNING: COMPLETE UNINSTALL%s\n' "$_TX_R" "$_TX_N"
    echo "This stops the server, DELETES all databases in $_TX_DATADIR,"
    echo "uninstalls the MariaDB package and removes the TxSQL commands."
    local c=""
    printf 'Type %sUNINSTALL%s (capitals) to confirm, anything else cancels: ' "$_TX_B" "$_TX_N"
    IFS= read -r c
    [ "$c" = "UNINSTALL" ] || { echo "Cancelled. Nothing was removed."; return 0; }

    _tx_stop_server || { _tx_err "Could not stop the server. Close Termux fully, reopen it and try again."; return 1; }
    pkg uninstall mariadb -y </dev/null || apt-get remove --purge -y mariadb </dev/null
    rm -rf "${_TX_DATADIR:?}" "$PREFIX/var/run/mysqld" "$HOME/.txsql.sh"
    rmdir "$PREFIX/etc/my.cnf.d" 2>/dev/null
    [ -f "$HOME/.bashrc" ] && sed -i '/\.txsql\.sh/d' "$HOME/.bashrc"
    unset -f startsql stopsql sqlstatus sqlpass sqlreset sqluninstall \
        _tx_info _tx_ok _tx_warn _tx_err _tx_step _tx_bins _tx_up _tx_root_ok \
        _tx_init_db _tx_ensure_server _tx_stop_server _tx_repair_root
    printf '%s✔ TxSQL and MariaDB are completely uninstalled.%s\n' "$_TX_G" "$_TX_N"
}
EOF
    chmod 0644 "$TXSQL_FILE"
    . "$TXSQL_FILE"

    printf '%s=========================================================%s\n' "$_TX_C" "$_TX_N"
    printf '%s%s  TxSQL - MariaDB Installer for Termux%s\n' "$_TX_C" "$_TX_B" "$_TX_N"
    printf '%s=========================================================%s\n' "$_TX_C" "$_TX_N"

    # ---- 1. Storage check -----------------------------------------------------
    _tx_step "[1/4] Checking free storage..."
    local free_kb
    free_kb=$(df -k "$PREFIX" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$free_kb" ] && [ "$free_kb" -lt 256000 ] 2>/dev/null; then
        _tx_warn "Only $((free_kb / 1024)) MB free. MariaDB needs about 250 MB; install may fail."
    fi

    # ---- 2. Packages ----------------------------------------------------------
    _tx_step "[2/4] Updating packages and installing MariaDB (a few minutes)..."
    export DEBIAN_FRONTEND=noninteractive
    local APT=(-y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")

    if ! pkg update -y </dev/null; then
        _tx_err "Could not update the package lists."
        _tx_info "Check your internet, or run 'termux-change-repo' and re-run: curl -fsSL $_TX_URL | bash"
        exit 1
    fi
    apt-get upgrade "${APT[@]}" </dev/null || _tx_warn "Upgrade reported an issue; installing MariaDB anyway."
    if ! apt-get install "${APT[@]}" mariadb </dev/null; then
        _tx_err "Could not install the 'mariadb' package."
        _tx_info "Run 'termux-change-repo', then re-run: curl -fsSL $_TX_URL | bash"
        exit 1
    fi
    # pkill is needed by stopsql/sqlreset as a fallback; not fatal if missing
    command -v pkill >/dev/null 2>&1 || apt-get install "${APT[@]}" procps </dev/null >/dev/null 2>&1 \
        || _tx_warn "Could not install 'procps' (optional)."

    # ---- 3. Database ----------------------------------------------------------
    _tx_step "[3/4] Preparing the database..."
    _tx_bins || exit 1
    if [ -d "$_TX_DATADIR/mysql" ]; then
        _tx_info "Existing database found at $_TX_DATADIR (all data preserved)."
    else
        _tx_info "Creating a fresh database..."
        _tx_init_db || exit 1
        _tx_ok "Database created."
    fi

    # ---- 4. Server check, root repair, shell setup ----------------------------
    _tx_step "[4/4] Starting the server and checking root login..."
    _tx_ensure_server || exit 1
    if _tx_repair_root; then
        _tx_info "Root login is ready (no password set). Add one any time with: sqlpass"
    else
        _tx_info "Root is protected by your existing password (kept unchanged)."
    fi

    touch "$BASHRC"
    if grep -q "^startsql()" "$BASHRC" 2>/dev/null; then
        cp "$BASHRC" "${BASHRC}.txsql.bak"
        _tx_info "Old startsql() found; backup saved as ~/.bashrc.txsql.bak"
        awk '/^startsql\(\)[[:space:]]*\{/ {skip=1; next} skip && /^\}/ {skip=0; next} !skip {print}' \
            "${BASHRC}.txsql.bak" > "$BASHRC"
    fi
    grep -Fq ".txsql.sh" "$BASHRC" 2>/dev/null \
        || printf '\n# TxSQL helper commands\n[ -f "$HOME/.txsql.sh" ] && . "$HOME/.txsql.sh"\n' >> "$BASHRC"

    printf '\n%s=========================================================%s\n' "$_TX_C" "$_TX_N"
    printf '%s%s✔ TxSQL installation complete!%s\n' "$_TX_G" "$_TX_B" "$_TX_N"
    printf '%s=========================================================%s\n' "$_TX_C" "$_TX_N"
    printf '1. Activate the commands : %ssource ~/.bashrc%s  (or restart Termux)\n' "$_TX_B" "$_TX_N"
    printf '2. Open the SQL shell    : %sstartsql%s\n\n' "$_TX_B" "$_TX_N"
    printf 'Type these at the Termux prompt (~ $), not inside SQL:\n'
    printf '  %sstartsql%s     start server + open SQL shell\n' "$_TX_B" "$_TX_N"
    printf '  %ssqlpass%s      set, change or remove the root password\n' "$_TX_B" "$_TX_N"
    printf '  %sstopsql%s      stop the server\n' "$_TX_B" "$_TX_N"
    printf '  %ssqlstatus%s    is the server running?\n' "$_TX_B" "$_TX_N"
    printf '  %ssqlreset%s     delete all databases, start fresh (asks first)\n' "$_TX_B" "$_TX_N"
    printf '  %ssqluninstall%s remove MariaDB, data and TxSQL (asks first)\n' "$_TX_B" "$_TX_N"
}

txsql_install_main "$@"
