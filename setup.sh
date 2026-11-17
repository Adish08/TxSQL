#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
# TxSQL (SquillMux) v2.0 - MariaDB installer for Termux
# Run:  curl -fsSL https://is.gd/txsql | bash
# Adds three commands:  startsql   stopsql   sqlpasswd
# Safe to re-run: it never wipes an existing database.
# =====================================================================

# Everything lives inside main(). Bash reads the whole function before
# running anything, so "curl ... | bash" cannot be broken by a command
# accidentally reading the script text from stdin.
main() {
  set -u

  local GREEN='\033[0;32m' CYAN='\033[0;36m' RED='\033[0;31m' YELLOW='\033[0;33m' NC='\033[0m'
  say()  { echo -e "${GREEN}$*${NC}"; }
  warn() { echo -e "${YELLOW}! $*${NC}"; }
  die()  { echo -e "${RED}✘ $*${NC}"; exit 1; }

  # ---- 0. Sanity checks -------------------------------------------------
  if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ] || ! command -v pkg >/dev/null 2>&1; then
    die "This script is for Termux (Android) only."
  fi
  if [ "$(id -u)" = "0" ]; then
    die "Do not run as root. Run it as the normal Termux user."
  fi

  local DATADIR="$PREFIX/var/lib/mysql"
  export DEBIAN_FRONTEND=noninteractive

  clear
  echo -e "${CYAN}=========================================${NC}"
  echo -e "${CYAN}   TxSQL: MariaDB installer for Termux   ${NC}"
  echo -e "${CYAN}=========================================${NC}"

  # ---- 1. Update & install ---------------------------------------------
  say "[1/3] Installing MariaDB (needs internet, ~200 MB free space)..."
  if ! pkg update -y </dev/null; then
    warn "First update failed, retrying once..."
    pkg update -y </dev/null || die "Cannot reach Termux repos. Check internet, then run again."
  fi
  apt-get -y -o Dpkg::Options::="--force-confold" upgrade </dev/null \
    || warn "Upgrade had problems; continuing with install."
  mkdir -p "$PREFIX/etc/my.cnf.d" "$DATADIR"
  pkg install -y mariadb </dev/null || die "MariaDB install failed. Run 'pkg update' and try again."
  command -v mysql_install_db >/dev/null 2>&1 || die "MariaDB installed but mysql_install_db is missing."

  # ---- 2. Initialise database (only if not done already) ---------------
  say "[2/3] Initialising database..."
  if [ -d "$DATADIR/mysql" ]; then
    echo "Database already initialised, leaving it untouched."
  else
    mysql_install_db --datadir="$DATADIR" \
      --auth-root-authentication-method=normal </dev/null \
      || die "Database init failed. Try: rm -rf $DATADIR/* and run this script again."
  fi

  # ---- 3. Commands (separate file, refreshed on every run) -------------
  say "[3/3] Setting up startsql / stopsql / sqlpasswd..."
  cat > "$HOME/.txsql.sh" << 'EOF'
# TxSQL helper commands (auto-generated; re-run the installer to refresh)

_txsql_running() {
  pgrep -x mariadbd >/dev/null 2>&1 || pgrep -x mysqld >/dev/null 2>&1
}

_txsql_up() { mysqladmin ping --silent >/dev/null 2>&1; }

# Start the server if needed, then open the SQL prompt
startsql() {
  if _txsql_running; then
    echo "✔ Server already running."
  else
    echo "➤ Starting server..."
    nohup mysqld_safe >"$PREFIX/tmp/txsql.log" 2>&1 &
    for _ in $(seq 1 30); do
      _txsql_up && break
      sleep 1
    done
    if ! _txsql_up; then
      echo "✘ Server did not start. See: $PREFIX/tmp/txsql.log and $PREFIX/var/lib/mysql/*.err"
      return 1
    fi
  fi
  echo "➤ Connecting as root."
  echo "  (No password set yet? Just press Enter at the password prompt.)"
  echo "  You will get a  MariaDB [(none)]>  prompt. Type SQL ONLY there."
  mysql -u root -p
}

# Stop the server
stopsql() {
  if _txsql_running; then
    mysqladmin -u root -p shutdown && echo "✔ Server stopped."
  else
    echo "Server is not running."
  fi
}

# Set or change the root password safely (no SQL typing needed)
sqlpasswd() {
  if ! _txsql_up; then
    echo "Server is not running. Start it first with: startsql  (then type exit)"
    return 1
  fi
  local p1 p2
  read -rsp "New root password: " p1; echo
  read -rsp "Repeat password:   " p2; echo
  [ -n "$p1" ] || { echo "✘ Password cannot be empty."; return 1; }
  [ "$p1" = "$p2" ] || { echo "✘ Passwords do not match."; return 1; }
  # escape backslashes and single quotes for the SQL string
  p1=${p1//\\/\\\\}
  p1=${p1//\'/\\\'}
  local sql="ALTER USER 'root'@'localhost' IDENTIFIED BY '${p1}'; FLUSH PRIVILEGES;"
  # try the current empty password first; if that fails, ask for the old one
  if mysql -u root -e "$sql" 2>/dev/null || mysql -u root -p -e "$sql"; then
    echo "✔ Root password updated. Next startsql will ask for it."
  else
    echo "✘ Could not change the password."
    return 1
  fi
}
EOF

  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    # always create .bashrc; touch .zshrc only if the user already has it
    if [ "$rc" = "$HOME/.bashrc" ] || [ -f "$rc" ]; then
      touch "$rc"
      grep -qF ".txsql.sh" "$rc" \
        || echo '[ -f "$HOME/.txsql.sh" ] && . "$HOME/.txsql.sh"' >> "$rc"
    fi
  done

  echo -e "${CYAN}=========================================${NC}"
  say "DONE!  Now run:  source ~/.bashrc   (or restart Termux)"
  say "Then:"
  say "   startsql    start server + open SQL prompt"
  say "   sqlpasswd   set a root password"
  say "   stopsql     stop the server"
  echo -e "${CYAN}=========================================${NC}"
}

main "$@"