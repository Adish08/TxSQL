# TxSQL: MariaDB on Termux in one command

Installs and configures **MariaDB (MySQL-compatible)** on Termux (Android) and gives you six simple helper commands: `startsql`, `sqlpass`, `stopsql`, `sqlstatus`, `sqlreset` and `sqluninstall`.

---

## 🛠 Install

Open Termux and type:

```bash
curl -fsSL https://adish.sagarawat.in/txsql | bash
```

Then reload the shell:

```bash
source ~/.bashrc
```

*(or close and reopen Termux)*

> **Network blocked or mirror issue?** Use the direct GitHub link:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/Adish08/TxSQL/main/setup.sh | bash
> ```

**Prerequisites**

- Termux from **[F-Droid](https://f-droid.org/en/packages/com.termux/)** or GitHub (the Play Store version is outdated).
- Internet connection and about 250 MB free space.

The installer is safe to re-run. It never deletes your databases, it refreshes the helper commands, and it repairs the older "root login refused" problem when it can.

Want to read the script before running it?

```bash
curl -fsSL https://adish.sagarawat.in/txsql | less
```

---

## 💻 Daily use

| Command | What it does |
|---|---|
| `startsql` | Starts the server (if needed) and opens the SQL prompt |
| `sqlpass` | Sets, changes or removes the root password (no SQL typing needed) |
| `stopsql` | Stops the background server |
| `sqlstatus` | Shows whether the server is **RUNNING** or **STOPPED** |
| `sqlreset` | Deletes ALL databases and the root password, then re-creates an empty MariaDB (asks to confirm) |
| `sqluninstall` | Completely removes MariaDB, all data and the TxSQL commands (asks to confirm) |

### First login

1. Type `startsql`.
2. On a fresh install root has no password, so you go straight to the `MariaDB [(none)]>` prompt.
3. Try: `SHOW DATABASES;`
4. Type `EXIT;` to return to Termux.

If a password has been set, `startsql` asks for it. Type it (you will not see the characters) and press **Enter**.

---

## ⚠️ Know your two prompts

This is the most common mistake for beginners.

| Prompt looks like | Where you are | What to type |
|---|---|---|
| `~ $` | Termux (bash) | Commands like `startsql`, `sqlpass`, `stopsql`, `ls` |
| `MariaDB [(none)]>` | Inside MariaDB | SQL such as `SHOW DATABASES;` |

- Typing SQL at the `~ $` prompt gives `bash: syntax error near unexpected token '('`. Nothing is broken. Run `startsql` first, and type SQL only at the `MariaDB [(none)]>` prompt.
- Typing `EXIT;` at `MariaDB [(none)]>` takes you back to `~ $`.
- Typing `exit` at `~ $` **closes the Termux session**, so do it only when you are finished.

---

## 🔐 Set, change or remove the root password

From the normal `~ $` prompt, simply run:

```bash
sqlpass
```

It starts the server if needed, asks for your current password (only if one is set), then asks for the new one twice. Leave the new password **empty** to remove the password completely. Typing is invisible.

Don't use a real or reused password while your screen is projected or shared.

**Manual SQL way** (only at the `MariaDB [(none)]>` prompt, never at `~ $`), if required:

```sql
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('your_password_here');
FLUSH PRIVILEGES;
```

---

## 🧯 Troubleshooting

| You see | Meaning | Fix |
|---|---|---|
| `bash: syntax error near unexpected token '('` | SQL typed at the `~ $` prompt | Run `startsql`, then type SQL at `MariaDB [(none)]>` |
| `curl: (22)` or the download fails | Typo in the link, network block or a temporary server error | Check the link letter by letter, then try the direct GitHub link from the Install section |
| `Could not update the package lists` | Termux mirror or internet problem | Check your internet, or run `termux-change-repo`, then run the install command again |
| `Access denied for user 'root'` | Wrong password, or an older install | Run the install command again to auto-repair. If you forgot the password, run `sqlreset` (deletes all data) |
| `Server did not start within 30 seconds` | MariaDB could not launch | Read the log lines shown, or open `$PREFIX/var/lib/mysql/txsql-error.log`, then try `startsql` again |
| `Database initialisation failed` | Often low storage | Free some space and run the install command again. Details are in `$PREFIX/tmp/txsql-init.log` |
| `Can't connect to local server` | Server is stopped | Use `startsql` instead of starting `mysql` yourself |
| Server stops after Termux is closed or the phone sleeps | Android stopped the background app | Run `startsql` again. TxSQL requests a wake lock when `termux-wake-lock` is available, but Android may still stop apps. Turning off battery optimisation for Termux helps |

---

## 🔄 Reset or uninstall

**Fresh database** (keeps MariaDB installed, deletes all databases and the root password):

```bash
sqlreset
```

*(Asks you to type `RESET` to confirm.)*

**Complete uninstall** (removes MariaDB, all data and the TxSQL commands):

```bash
sqluninstall
```

*(Asks you to type `UNINSTALL` to confirm.)*

Both commands permanently delete your databases. Nothing is deleted unless you type the confirmation word.

---

## 🔍 What the script does

1. Checks it is running in Termux as a normal user, and warns if free space is low.
2. Updates the package lists and packages without interactive prompts, then installs `mariadb`. It also tries to install `procps` (optional, used as a fallback to stop the server).
3. Creates the database only if none exists yet, using normal password authentication with an empty root password. An existing database is never touched.
4. Starts the server, waiting for it to respond (up to 30 seconds) instead of using a fixed delay, and repairs the older "root login refused" setup when it can.
5. Writes the helper commands to `~/.txsql.sh` and loads them from `~/.bashrc`. If the very first TxSQL version left an old `startsql` in `~/.bashrc`, it removes it and saves a backup as `~/.bashrc.txsql.bak`.

---

## 🤝 Contributing

Fork the repository and send a pull request with improvements.

**Maintained by [Adish08](https://github.com/Adish08)**
