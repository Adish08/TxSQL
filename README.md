# TxSQL - Termux SQL Auto-Installer

A simple, automated Bash script to set up **MariaDB (MySQL)** on Termux Android. This script handles installation, database initialization, and creates a convenient shortcut (`startsql`) to manage the server and client connection in one go.

---

## 🚀 Features

* **Auto-Update:** Automatically updates and upgrades Termux packages.
* **Installation:** Installs the latest stable version of MariaDB.
* **Initialization:** Runs `mysql_install_db` to set up the default data directory (only if not already present).
* **Shortcut Creation:** Adds a permanent `startsql` alias to your `.bashrc`.
* **Smart Launch:** The `startsql` command checks if the server is already running to prevent *"Address already in use"* errors.

---

## 📋 Prerequisites

* **Termux App:** Use the F-Droid version of Termux (Play Store version is deprecated).
* **Internet Connection:** Required to download packages.

---

## 🛠 Installation

Set up everything with a single command. Open Termux and run:

```bash
pkg install curl -y && bash <(curl -fsSL https://raw.githubusercontent.com/Adish08/TxSQL/refs/heads/main/setup.sh)
```

### What this command does:

* Installs `curl` (if missing).
* Downloads the `setup.sh` script from the repository.
* Executes the script immediately.

---

## 💻 Usage

After the installation script completes, you’ll see a success message.

### 1. Reload Shell

To activate the new command instantly:

```bash
source ~/.bashrc
```

(Or simply close and reopen Termux)

### 2. Start SQL

Use the single-word command:

```bash
startsql
```

### Behavior of `startsql`:

* **If server is stopped:** Starts `mysqld_safe` in the background, waits 4 seconds, then logs you in.
* **If server is running:** Skips startup and logs you in directly.
* **Default Login:** User `root`, password prompt (usually empty — press Enter).

---

## 🔍 What the Script Does (Under the Hood)

The `setup.sh` script performs:

* **System Update:** Runs `pkg update && pkg upgrade`.
* **Package Install:** Installs MariaDB.
* **Database Setup:** Checks for `$PREFIX/var/lib/mysql/mysql`; if missing, performs initialization.
* **Bash Config:** Appends the `startsql` function to your `~/.bashrc`.

---

## 🔐 Setting a Password in MariaDB

After installation, you can secure your MariaDB setup by setting a root password.

### 1. Start the SQL Server

Make sure MariaDB is running:

```bash
startsql
```

(Logs you into the MariaDB shell)

### 2. Set the Root Password

Inside the MariaDB prompt, run:

```sql
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('your_password_here');
```

Replace `your_password_here` with your desired password.

### 3. Apply Privileges

```sql
FLUSH PRIVILEGES;
```

### 4. Exit

```sql
EXIT;
```

### 5. Log In with Password

Next time you use:

```bash
startsql
```

It will prompt for the password you set.

---

## 🤝 Contributing

Feel free to fork the repository and submit pull requests with improvements.

**Maintained by *Adish08***