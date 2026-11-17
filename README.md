# TxSQL (SquillMux): MariaDB on Termux in one command

Installs and configures **MariaDB (MySQL-compatible)** on Termux (Android) and gives you three simple commands: `startsql`, `stopsql` and `sqlpasswd`.

---

## 🛠 Install

Open Termux and type:

```bash
curl -fsSL https://is.gd/txsql | bash
```

Then reload the shell:

```bash
source ~/.bashrc
```

(or close and reopen Termux)

**Prerequisites**

- Termux from **F-Droid** (the Play Store version is outdated).
- Internet connection and roughly 200 MB free space.

The script is safe to re-run. It never deletes an existing database.

Want to read the script before running it?

```bash
curl -fsSL https://is.gd/txsql | less
```

---

## 💻 Daily use

| Command | What it does |
|---|---|
| `startsql` | Starts the server (if needed) and opens the SQL prompt |
| `sqlpasswd` | Sets or changes the root password (no SQL typing needed) |
| `stopsql` | Stops the server |

### ⚠️ Know your two prompts

This is the most common mistake.

| Prompt looks like | Where you are | What to type |
|---|---|---|
| `~ $` | Termux (bash) | Commands like `startsql`, `ls` |
| `MariaDB [(none)]>` | Inside MariaDB | SQL such as `SHOW DATABASES;` |

If you type SQL at the `~ $` prompt you will see `bash: syntax error near unexpected token '('`. Nothing is broken. Run `startsql` first, wait for the `MariaDB [(none)]>` prompt, and type SQL there. To leave MariaDB, type `exit`.

### First login

1. Type `startsql`.
2. At `Enter password:` just press **Enter** (no password is set on a fresh install).
3. Try: `SHOW DATABASES;`
4. Type `exit` to return to Termux.

---

## 🔐 Set a root password

Easiest way, from the normal `~ $` prompt:

```bash
startsql      # start the server, then type: exit
sqlpasswd     # type the new password twice
```

Next time `startsql` will ask for that password.

**Manual way** (only at the `MariaDB [(none)]>` prompt, not in bash):

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_password_here';
FLUSH PRIVILEGES;
```

Don't use a real or reused password when your screen is projected or shared.

---

## 🧯 Troubleshooting

| You see | Meaning | Fix |
|---|---|---|
| `bash: syntax error near unexpected token '('` | SQL typed at the `~ $` prompt | Run `startsql` and type SQL at `MariaDB [(none)]>` |
| `curl: (22) ... error: 500` (or any `curl` error) | Download failed before the script ran | Check the URL for typos (it is `https://is.gd/txsql`) and your internet, then retry |
| `Server did not start` | MariaDB could not launch | Read `$PREFIX/tmp/txsql.log`, then try `stopsql` and `startsql` again |
| `Access denied for user 'root'` | Wrong password, or an older install | Try an empty password (Enter). On an old install, try plain `mysql` as your Termux user |
| `Can't connect to local server` | Server is not running | Run `startsql` |
| Install fails midway | Repo or network hiccup | Run `pkg update`, then run the install command again |

If the database is broken and you don't need its data, you can start fresh. **This deletes all databases:**

```bash
stopsql
rm -rf $PREFIX/var/lib/mysql/*
curl -fsSL https://is.gd/txsql | bash
```

---

## 🔍 What the script does

1. Checks it is running in Termux as a normal user.
2. Runs `pkg update` and upgrades packages without interactive prompts, then installs MariaDB.
3. Initialises the data directory only if it does not exist yet, with an empty root password so the first login works.
4. Writes `~/.txsql.sh` (the commands above) and loads it from `~/.bashrc`. This file is refreshed on every run, so re-running the installer updates your commands.

Notes:

- `startsql` checks whether the server is already running, so you don't get "address already in use" errors.
- The server runs in the background, and its log is at `$PREFIX/tmp/txsql.log`.

---

## 🤝 Contributing

Fork the repository and send a pull request with improvements.

**Maintained by *Adish08***
