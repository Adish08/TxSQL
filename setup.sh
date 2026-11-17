#!/data/data/com.termux/files/usr/bin/bash
# TxSQL (SquillMux) - MariaDB installer for Termux
set -u

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

if [ -z "${PREFIX:-}" ] || ! command -v pkg >/dev/null 2>&1; then
  echo -e "${RED}This script is for Termux only.${NC}"; exit 1
fi

DATADIR="$PREFIX/var/lib/mysql"
export DEBIAN_FRONTEND=noninteractive

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN} MariaDB Auto-Installer & 'startsql' ${NC}"
echo -e "${CYAN}=========================================${NC}"

# 1. Update & Install
echo -e "${GREEN}[1/3] Installing MariaDB...${NC}"
pkg update -y
apt-get -y -o Dpkg::Options::="--force-confold" upgrade
mkdir -p "$PREFIX/etc/my.cnf.d" "$DATADIR"
pkg install -y mariadb || { echo -e "${RED}MariaDB install failed.${NC}"; exit 1; }

# 2. Init Database
echo -e "${GREEN}[2/3] Initializing Database...${NC}"
if [ ! -d "$DATADIR/mysql" ]; then
  mysql_install_db --datadir="$DATADIR" \
    --auth-root-authentication-method=normal \
    || { echo -e "${RED}Database init failed.${NC}"; exit 1; }
else
  echo "Database already initialized."
fi

# 3. Commands (separate file, refreshed on every run)
echo -e "${GREEN}[3/3] Setting up 'startsql' command...${NC}"
cat > "$HOME/.txsql.sh" << 'EOF'
_txsql_running() {
  pgrep -x mariadbd >/dev/null 2>&1 || pgrep -x mysqld >/dev/null 2>&1
}
startsql() {
  if _txsql_running; then
    echo "✔ Server already running."
  else
    echo "➤ Starting Server..."
    nohup mysqld_safe >/dev/null 2>&1 &
    for _ in $(seq 1 30); do
      mysqladmin ping --silent >/dev/null 2>&1 && break
      sleep 1
    done
    if ! mysqladmin ping --silent >/dev/null 2>&1; then
      echo "✘ Server did not start. Check logs in: $PREFIX/var/lib/mysql/*.err"
      return 1
    fi
  fi
  echo "➤ Connecting... (fresh install: just press Enter at the password)"
  mysql -u root -p
}
stopsql() { mysqladmin -u root -p shutdown; }
EOF

BASHRC="$HOME/.bashrc"
touch "$BASHRC"
grep -qF ".txsql.sh" "$BASHRC" || \
  echo '[ -f "$HOME/.txsql.sh" ] && . "$HOME/.txsql.sh"' >> "$BASHRC"

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}DONE! Restart Termux or type: source ~/.bashrc${NC}"
echo -e "${GREEN}Then type: startsql   (stop with: stopsql)${NC}"
echo -e "${GREEN}Tip: set a root password after first login.${NC}"
echo -e "${CYAN}=========================================${NC}"