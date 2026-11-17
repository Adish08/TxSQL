#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# TxSQL - MariaDB Auto-Installer & Helper Suite for Termux
# Repository : https://github.com/Adish08/TxSQL
# Short Link : https://adish.sagarawat.in/txsql
# Maintainer : Adish08
# ==============================================================================
# Wrapped in a main function so `curl -fsSL https://adish.sagarawat.in/txsql | bash`
# never executes a partially downloaded script and never has stdin consumed
# by child processes like apt/dpkg.

txsql_install_main() {
    set -u

    # --- Colours ---
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local CYAN='\033[0;36m'
    local BOLD='\033[1m'
    local NC='\033[0m'

    # --- Helper Print Functions ---
    info()  { printf "${CYAN}[INFO]${NC} %s\n" "$*"; }
    step()  { printf "\n${GREEN}${BOLD}==> %s${NC}\n" "$*"; }
    warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
    err()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
    die()   { err "$*"; exit 1; }

    printf "${CYAN}=========================================================${NC}\n"
    printf "${CYAN}${BOLD}  TxSQL (Adish08) - MariaDB Installer for Termux     ${NC}\n"
    printf "${CYAN}=========================================================${NC}\n"

    # --- 1. Environment & Pre-flight Checks ---
    step "[1/5] Checking Termux environment..."

    if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-}" ]; then
        die "This script must be run inside Termux on Android (\$PREFIX is missing)."
    fi

    if [ "$(id -u)" -eq 0 ]; then
        die "Do NOT run TxSQL as root (su/sudo/tsu). Run it as your normal Termux user."
    fi

    # Check free storage space (require at least 250 MB free in $PREFIX)
    local free_kb=0
    free_kb=$(df -k "$PREFIX" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$free_kb" ] && [ "$free_kb" -lt 256000 ] 2>/dev/null; then
        warn "Low free storage detected ($((free_kb / 1024)) MB available)."
        warn "MariaDB requires around 250 MB of free space. Installation may fail."
    fi

    # --- 2. Package Update & MariaDB Installation ---
    step "[2/5] Updating repositories and installing MariaDB..."
    info "This may take a few minutes depending on your internet speed."

    export DEBIAN_FRONTEND=noninteractive
    local APT_FLAGS=(
        -y
        -o Dpkg::Options::="--force-confdef"
        -o Dpkg::Options::="--force-confold"
    )

    if ! pkg update -y </dev/null; then
        err "Failed to update Termux package lists."
        info "Tip 1: Check your internet connection."
        info "Tip 2: Run 'termux-change-repo' to switch to a working mirror, then try again."
        exit 1
    fi

    if ! apt-get upgrade "${APT_FLAGS[@]}" </dev/null; then
        warn "Package upgrade reported an issue; attempting MariaDB install directly..."
    fi

    if ! apt-get install "${APT_FLAGS[@]}" mariadb </dev/null; then
        err "Failed to install the 'mariadb' package."
        info "Try running: termux-change-repo"
        info "Then re-run: curl -fsSL https://adish.sagarawat.in/txsql | bash"
        exit 1
    fi

    # --- 3. Resolve MariaDB Binary Names & Directories ---
    step "[3/5] Configuring directories and database data..."

    local DATADIR="$PREFIX/var/lib/mysql"
    local RUNDIR="$PREFIX/var/run/mysqld"
    local LOGFILE="$DATADIR/txsql-error.log"

    mkdir -p "$PREFIX/etc/my.cnf.d" "$RUNDIR"

    local INSTALL_DB_BIN=""
    if command -v mariadb-install-db >/dev/null 2>&1; then
        INSTALL_DB_BIN="mariadb-install-db"
    elif command -v mysql_install_db >/dev/null 2>&1; then
        INSTALL_DB_BIN="mysql_install_db"
    else
        die "Could not find 'mariadb-install-db' or 'mysql_install_db' after installation."
    fi

    local CLIENT_BIN=""
    if command -v mariadb >/dev/null 2>&1; then
        CLIENT_BIN="mariadb"
    elif command -v mysql >/dev/null 2>&1; then
        CLIENT_BIN="mysql"
    else
        die "Could not find 'mariadb' or 'mysql' client binary."
    fi

    local ADMIN_BIN=""
    if command -v mariadb-admin >/dev/null 2>&1; then
        ADMIN_BIN="mariadb-admin"
    elif command -v mysqladmin >/dev/null 2>&1; then
        ADMIN_BIN="mysqladmin"
    else
        die "Could not find 'mariadb-admin' or 'mysqladmin' binary."
    fi

    local SAFE_BIN=""
    if command -v mariadbd-safe >/dev/null 2>&1; then
        SAFE_BIN="mariadbd-safe"
    elif command -v mysqld_safe >/dev/null 2>&1; then
        SAFE_BIN="mysqld_safe"
    else
        die "Could not find 'mariadbd-safe' or 'mysqld_safe' binary."
    fi

    # Initialise system tables only if not already present (never overwrite user data)
    if [ ! -d "$DATADIR/mysql" ]; then
        info "Initialising fresh MariaDB data directory at $DATADIR..."
        mkdir -p "$DATADIR"
        if ! "$INSTALL_DB_BIN" --user="$(whoami)" --auth-root-authentication-method=normal --datadir="$DATADIR" </dev/null >/dev/null 2>&1; then
            warn "Standard init flag failed; retrying fallback initialisation..."
            if ! "$INSTALL_DB_BIN" --datadir="$DATADIR" </dev/null; then
                die "Database initialisation failed. Check storage space or run 'sqlreset' later."
            fi
        fi
        info "Fresh database initialised successfully."
    else
        info "Existing database directory found at $DATADIR (preserving all user data)."
    fi

    # --- 4. Verify Server Startup & Repair Legacy Socket-Locked 'root' Accounts ---
    step "[4/5] Verifying MariaDB server and root login compatibility..."

    # Start server if not currently responding
    if ! "$ADMIN_BIN" ping --silent >/dev/null 2>&1; then
        info "Starting MariaDB server for verification..."
        (nohup "$SAFE_BIN" --datadir="$DATADIR" >"$LOGFILE" 2>&1 </dev/null &)
        local waited=0
        while ! "$ADMIN_BIN" ping --silent >/dev/null 2>&1; do
            sleep 1
            waited=$((waited + 1))
            if [ "$waited" -ge 30 ]; then
                err "MariaDB server did not start within 30 seconds."
                [ -f "$LOGFILE" ] && tail -n 15 "$LOGFILE" >&2
                die "Check the log above or at: $LOGFILE"
            fi
        done
    fi

    # Check if root can log in without password.
    # If not, check if this is an older install where $(whoami) has passwordless socket access,
    # and repair 'root'@'localhost' so beginners don't get 'Access denied' on fresh/legacy installs.
    if "$CLIENT_BIN" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
        info "Account 'root'@'localhost' is ready (no password currently set)."
    else
        local os_user
        os_user="$(whoami)"
        if "$CLIENT_BIN" -u "$os_user" --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
            info "Detected legacy socket authentication via '$os_user'. Checking if root needs repair..."
            # Only repair if root currently has no password string set (e.g. unix_socket lock)
            local root_repair_sql="
                ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');
                GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
                FLUSH PRIVILEGES;
            "
            if "$CLIENT_BIN" -u "$os_user" -e "SELECT 1 FROM mysql.global_priv WHERE User='root' AND Host='localhost' AND (JSON_VALUE(Priv, '$.authentication_string') = '' OR JSON_VALUE(Priv, '$.authentication_string') IS NULL);" 2>/dev/null | grep -q 1; then
                if "$CLIENT_BIN" -u "$os_user" -e "$root_repair_sql" >/dev/null 2>&1; then
                    info "Repaired legacy 'root'@'localhost' login automatically."
                fi
            else
                info "Account 'root'@'localhost' is protected by your existing password."
            fi
        else
            info "Account 'root'@'localhost' is already password-protected (keeping existing password)."
        fi
    fi

    # --- 5. Install Helper Commands (`~/.txsql.sh`) & Update Shell RC ---
    step "[5/5] Installing TxSQL commands (startsql, stopsql, sqlpass, sqlstatus, sqlreset, sqluninstall)..."

    local TXSQL_FILE="$HOME/.txsql.sh"
    local BASHRC="$HOME/.bashrc"

    cat << 'EOF' > "$TXSQL_FILE"
# ==============================================================================
# ~/.txsql.sh - Managed by TxSQL (https://github.com/Adish08/TxSQL)
# Do not edit manually; re-running the installer refreshes this file.
# ==============================================================================

_txsql_bins() {
    if command -v mariadb >/dev/null 2>&1; then _TX_CLIENT="mariadb"; else _TX_CLIENT="mysql"; fi
    if command -v mariadb-admin >/dev/null 2>&1; then _TX_ADMIN="mariadb-admin"; else _TX_ADMIN="mysqladmin"; fi
    if command -v mariadbd-safe >/dev/null 2>&1; then _TX_SAFE="mariadbd-safe"; else _TX_SAFE="mysqld_safe"; fi
    if command -v mariadb-install-db >/dev/null 2>&1; then _TX_INIT="mariadb-install-db"; else _TX_INIT="mysql_install_db"; fi
    _TX_DATADIR="${PREFIX}/var/lib/mysql"
    _TX_LOG="${_TX_DATADIR}/txsql-error.log"
}

_txsql_is_running() {
    _txsql_bins
    "$_TX_ADMIN" ping --silent >/dev/null 2>&1
}

_txsql_ensure_server() {
    _txsql_bins
    mkdir -p "${PREFIX}/etc/my.cnf.d" "${PREFIX}/var/run/mysqld"

    if [ ! -d "${_TX_DATADIR}/mysql" ]; then
        printf "\033[1;33m[WARN]\033[0m Database directory missing. Initialising now...\n"
        mkdir -p "$_TX_DATADIR"
        "$_TX_INIT" --user="$(whoami)" --auth-root-authentication-method=normal --datadir="$_TX_DATADIR" >/dev/null 2>&1 || \
            "$_TX_INIT" --datadir="$_TX_DATADIR" >/dev/null 2>&1
    fi

    if _txsql_is_running; then
        printf "\033[0;32m✔ MariaDB server is already running.\033[0m\n"
        return 0
    fi

    printf "\033[0;36m➤ Starting MariaDB server...\033[0m\n"
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock >/dev/null 2>&1 || true
    fi

    (nohup "$_TX_SAFE" --datadir="$_TX_DATADIR" >"$_TX_LOG" 2>&1 </dev/null &)

    local i=0
    while ! _txsql_is_running; do
        sleep 1
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            printf "\033[0;31m✖ Error: MariaDB server failed to start within 30 seconds.\033[0m\n" >&2
            if [ -f "$_TX_LOG" ]; then
                printf "Last lines of error log (%s):\n" "$_TX_LOG" >&2
                tail -n 10 "$_TX_LOG" >&2
            fi
            return 1
        fi
    done
    printf "\033[0;32m✔ MariaDB server started.\033[0m\n"
    return 0
}

startsql() {
    _txsql_ensure_server || return 1

    printf "\033[0;36m➤ Connecting to MariaDB as 'root'...\033[0m\n"
    printf "  (Tip: Type \033[1mEXIT;\033[0m to leave SQL. Do not type EXIT again at '\033[1m~ $\033[0m' or Termux will close.)\n\n"

    # Try passwordless root login first so fresh installs never stall on an empty password prompt
    if "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
        "$_TX_CLIENT" -u root
        return $?
    fi

    # Fallback: check if legacy OS user can auto-repair an empty/socket-locked root account
    local os_user
    os_user="$(whoami)"
    if "$_TX_CLIENT" -u "$os_user" --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
        if "$_TX_CLIENT" -u "$os_user" -e "SELECT 1 FROM mysql.global_priv WHERE User='root' AND Host='localhost' AND (JSON_VALUE(Priv, '$.authentication_string') = '' OR JSON_VALUE(Priv, '$.authentication_string') IS NULL);" 2>/dev/null | grep -q 1; then
            "$_TX_CLIENT" -u "$os_user" -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD(''); GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" >/dev/null 2>&1
            if "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
                "$_TX_CLIENT" -u root
                return $?
            fi
        fi
    fi

    # Password is set on root
    printf "\033[1;33m🔒 Password required for 'root'@'localhost'.\033[0m\n"
    printf "   (Characters will not appear while typing. Forgot it? Run \033[1msqlreset\033[0m to wipe and start fresh.)\n"
    "$_TX_CLIENT" -u root -p
}

stopsql() {
    _txsql_bins
    if ! _txsql_is_running; then
        printf "\033[1;33mℹ MariaDB server is not running.\033[0m\n"
        return 0
    fi
    printf "\033[0;36m➤ Stopping MariaDB server...\033[0m\n"
    if "$_TX_ADMIN" -u root shutdown >/dev/null 2>&1; then
        printf "\033[0;32m✔ MariaDB server stopped cleanly.\033[0m\n"
        return 0
    fi
    # If root requires a password, try clean SIGTERM on mariadbd/mysqld
    pkill -TERM -x mariadbd 2>/dev/null || pkill -TERM -x mysqld 2>/dev/null || true
    local i=0
    while _txsql_is_running && [ "$i" -lt 10 ]; do
        sleep 1
        i=$((i + 1))
    done
    if _txsql_is_running; then
        printf "\033[1;33mRoot password required to shut down cleanly:\033[0m\n"
        "$_TX_ADMIN" -u root -p shutdown
    else
        printf "\033[0;32m✔ MariaDB server stopped.\033[0m\n"
    fi
}

sqlstatus() {
    _txsql_bins
    if _txsql_is_running; then
        printf "\033[0;32m✔ MariaDB server is RUNNING.\033[0m\n"
        "$_TX_ADMIN" version 2>/dev/null || true
    else
        printf "\033[1;33m✖ MariaDB server is STOPPED.\033[0m (Run \033[1mstartsql\033[0m to start it)\n"
    fi
}

sqlpass() {
    _txsql_ensure_server || return 1
    printf "\n\033[0;36m=== Set or Change MariaDB 'root' Password ===\033[0m\n"
    printf "Note: In a classroom or on a projector, do NOT use your personal password.\n\n"

    local auth_args=(-u root)
    local cur_pass=""
    if ! "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
        printf "Enter CURRENT root password: "
        IFS= read -rs cur_pass
        printf "\n"
        if ! MYSQL_PWD="$cur_pass" "$_TX_CLIENT" -u root --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
            printf "\033[0;31m✖ Error: Current password is incorrect.\033[0m\n" >&2
            printf "  (If you forgot your password and want to wipe all databases, run: \033[1msqlreset\033[0m)\n" >&2
            return 1
        fi
    fi

    local new_pass=""
    local confirm_pass=""
    printf "Enter NEW root password (leave empty and press Enter to remove password): "
    IFS= read -rs new_pass
    printf "\n"
    printf "Confirm NEW root password: "
    IFS= read -rs confirm_pass
    printf "\n"

    if [ "$new_pass" != "$confirm_pass" ]; then
        printf "\033[0;31m✖ Error: Passwords do not match. Nothing was changed.\033[0m\n" >&2
        return 1
    fi

    # Escape single quotes and backslashes safely for SQL literal
    local escaped_pass
    escaped_pass=$(printf "%s" "$new_pass" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g")

    local sql_cmd="ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${escaped_pass}'); FLUSH PRIVILEGES;"
    if [ -n "$cur_pass" ]; then
        MYSQL_PWD="$cur_pass" "$_TX_CLIENT" "${auth_args[@]}" -e "$sql_cmd"
    else
        "$_TX_CLIENT" "${auth_args[@]}" -e "$sql_cmd"
    fi

    if [ $? -eq 0 ]; then
        if [ -z "$new_pass" ]; then
            printf "\033[0;32m✔ Password removed! 'startsql' will now log you in automatically.\033[0m\n"
        else
            printf "\033[0;32m✔ Root password updated! Next time you run 'startsql', enter this password.\033[0m\n"
        fi
    else
        printf "\033[0;31m✖ Failed to update password.\033[0m\n" >&2
        return 1
    fi
}

sqlreset() {
    _txsql_bins
    printf "\n\033[0;31m=========================================================\033[0m\n"
    printf "\033[0;31m WARNING: RESET ALL MARIADB DATABASES & PASSWORDS\033[0m\n"
    printf "\033[0;31m=========================================================\033[0m\n"
    printf "This will PERMANENTLY DELETE all your databases and tables in:\n"
    printf "  %s\n" "$_TX_DATADIR"
    printf "MariaDB itself will remain installed and will be re-initialised empty.\n\n"
    printf "Type \033[1mRESET\033[0m (in ALL CAPS) to confirm, or anything else to cancel: "

    local confirm=""
    IFS= read -r confirm
    if [ "$confirm" != "RESET" ]; then
        printf "Cancelled. No data was deleted.\n"
        return 0
    fi

    printf "\033[0;36m➤ Stopping running MariaDB processes...\033[0m\n"
    pkill -TERM -x mariadbd 2>/dev/null || pkill -TERM -x mysqld 2>/dev/null || true
    sleep 2
    pkill -KILL -x mariadbd 2>/dev/null || pkill -KILL -x mysqld 2>/dev/null || true

    printf "\033[0;36m➤ Removing old database directory...\033[0m\n"
    rm -rf "$_TX_DATADIR"
    mkdir -p "$_TX_DATADIR"

    printf "\033[0;36m➤ Re-initialising fresh database...\033[0m\n"
    if "$_TX_INIT" --user="$(whoami)" --auth-root-authentication-method=normal --datadir="$_TX_DATADIR" >/dev/null 2>&1 || \
       "$_TX_INIT" --datadir="$_TX_DATADIR" >/dev/null 2>&1; then
        printf "\033[0;32m✔ Database reset complete! Run 'startsql' to open your fresh SQL shell.\033[0m\n"
    else
        printf "\033[0;31m✖ Failed to re-initialise database.\033[0m\n" >&2
        return 1
    fi
}

sqluninstall() {
    _txsql_bins
    printf "\n\033[0;31m=========================================================\033[0m\n"
    printf "\033[0;31m WARNING: COMPLETE UNINSTALL OF TXSQL & MARIADB\033[0m\n"
    printf "\033[0;31m=========================================================\033[0m\n"
    printf "This will:\n"
    printf "  1. Stop the MariaDB server\n"
    printf "  2. PERMANENTLY DELETE all databases in %s\n" "$_TX_DATADIR"
    printf "  3. Uninstall the MariaDB package from Termux\n"
    printf "  4. Remove ~/.txsql.sh and clean up ~/.bashrc\n\n"
    printf "Type \033[1mUNINSTALL\033[0m (in ALL CAPS) to confirm, or anything else to cancel: "

    local confirm=""
    IFS= read -r confirm
    if [ "$confirm" != "UNINSTALL" ]; then
        printf "Cancelled. Nothing was removed.\n"
        return 0
    fi

    printf "\033[0;36m➤ Stopping MariaDB processes...\033[0m\n"
    pkill -TERM -x mariadbd 2>/dev/null || pkill -TERM -x mysqld 2>/dev/null || true
    sleep 2
    pkill -KILL -x mariadbd 2>/dev/null || pkill -KILL -x mysqld 2>/dev/null || true

    printf "\033[0;36m➤ Uninstalling MariaDB package...\033[0m\n"
    pkg uninstall mariadb -y </dev/null || apt-get remove --purge -y mariadb </dev/null || true

    printf "\033[0;36m➤ Deleting database and configuration files...\033[0m\n"
    rm -rf "$_TX_DATADIR" "${PREFIX}/etc/my.cnf.d" "${PREFIX}/var/run/mysqld" "$HOME/.txsql.sh"

    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/\.txsql\.sh/d' "$rc" 2>/dev/null || true
        fi
    done

    unset -f startsql stopsql sqlstatus sqlpass sqlreset sqluninstall _txsql_bins _txsql_is_running _txsql_ensure_server 2>/dev/null || true
    printf "\033[0;32m✔ TxSQL and MariaDB have been completely uninstalled.\033[0m\n"
}
EOF

    chmod 0644 "$TXSQL_FILE"

    # Clean legacy inline startsql() block from ~/.bashrc if present from the original script
    touch "$BASHRC"
    if grep -q "^startsql()" "$BASHRC" 2>/dev/null; then
        cp "$BASHRC" "${BASHRC}.txsql.bak"
        info "Backed up ~/.bashrc to ~/.bashrc.txsql.bak and upgraded legacy inline startsql() block."
        awk '
            /^startsql\(\)[[:space:]]*\{/ { in_block=1; next }
            in_block && /^\}/ { in_block=0; next }
            !in_block { print }
        ' "${BASHRC}.txsql.bak" > "$BASHRC"
    fi

    # Ensure ~/.txsql.sh is sourced in ~/.bashrc (and ~/.zshrc if the user installed zsh)
    local SOURCE_LINE='[ -f "$HOME/.txsql.sh" ] && . "$HOME/.txsql.sh"'
    if ! grep -Fq ".txsql.sh" "$BASHRC" 2>/dev/null; then
        printf "\n# TxSQL (SquillMux) helper commands\n%s\n" "$SOURCE_LINE" >> "$BASHRC"
    fi
    if [ -f "$HOME/.zshrc" ] && ! grep -Fq ".txsql.sh" "$HOME/.zshrc" 2>/dev/null; then
        printf "\n# TxSQL (SquillMux) helper commands\n%s\n" "$SOURCE_LINE" >> "$HOME/.zshrc"
    fi

    printf "\n${CYAN}=========================================================${NC}\n"
    printf "${GREEN}${BOLD}✔ TxSQL Installation Complete!${NC}\n"
    printf "${CYAN}=========================================================${NC}\n"
    printf "Next steps:\n"
    printf "  1. Activate commands now : ${BOLD}source ~/.bashrc${NC}\n"
    printf "  2. Open MariaDB shell    : ${BOLD}startsql${NC}\n\n"
    printf "Extra commands available anytime at the Termux prompt (~ $):\n"
    printf "  • ${BOLD}startsql${NC}     - Start server (if stopped) and open MariaDB shell\n"
    printf "  • ${BOLD}sqlpass${NC}      - Set, change, or remove the MariaDB root password\n"
    printf "  • ${BOLD}stopsql${NC}      - Stop the background MariaDB server\n"
    printf "  • ${BOLD}sqlstatus${NC}    - Check if MariaDB server is running\n"
    printf "  • ${BOLD}sqlreset${NC}     - Wipe all databases & reset password (asks confirmation)\n"
    printf "  • ${BOLD}sqluninstall${NC} - Completely remove MariaDB, data & TxSQL\n"
    printf "${CYAN}=========================================================${NC}\n"
}

txsql_install_main "$@"
