#!/bin/bash

# COLORS
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}   MariaDB Auto-Installer & 'startsql'   ${NC}"
echo -e "${CYAN}=========================================${NC}"

# 1. Update & Install
echo -e "${GREEN}[1/3] Installing MariaDB...${NC}"
pkg update -y && pkg upgrade -y
pkg install mariadb -y

# 2. Init Database
echo -e "${GREEN}[2/3] Initializing Database...${NC}"
if [ ! -d "$PREFIX/var/lib/mysql/mysql" ]; then
    mysql_install_db
else
    echo "Database already initialized."
fi

# 3. Create Alias
echo -e "${GREEN}[3/3] Setting up 'startsql' command...${NC}"
BASHRC="$HOME/.bashrc"

# Only add if not already there
if ! grep -q "startsql()" "$BASHRC"; then
    cat << 'EOF' >> "$BASHRC"

startsql() {
    if pgrep -x "mysqld" >/dev/null; then
        echo "✔ Server already running."
    else
        echo "➤ Starting Server..."
        mysqld_safe >/dev/null 2>&1 & 
        sleep 4
    fi
    echo "➤ Connecting..."
    mysql -u root -p
}
EOF
fi

echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}DONE! Restart Termux or type: source ~/.bashrc${NC}"
echo -e "${GREEN}Then type: startsql${NC}"
echo -e "${CYAN}=========================================${NC}"
