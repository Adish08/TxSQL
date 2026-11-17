# TxSQL: MariaDB on Termux in one command

Installs and configures **MariaDB (MySQL-compatible)** on Termux (Android) and gives you six simple helper commands: `startsql`, `sqlpass`, `stopsql`, `sqlstatus`, `sqlreset`, and `sqluninstall`.

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

> **Network blocked / Mirror issue?** Use the direct GitHub backup link:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/Adish08/TxSQL/main/setup.sh | bash
> ```

**Prerequisites**

- Termux from **[F-Droid](https://f-droid.org/en/packages/com.termux/)** or GitHub (Play Store version is outdated).
- Internet connection and ~250 MB free space.

The installer is safe to re-run. It never deletes your databases and automatically repairs older root socket errors while updating helper commands.

---

## 💻 Daily Use

| Command | What it does |
|---|---|
| `startsql` | Starts the server (if needed) and opens the SQL prompt |
| `sqlpass` | Sets, changes, or removes the root password (no SQL typing needed) |
| `stopsql` | Stops the background server cleanly |
| `sqlstatus` | Shows whether the server is currently **RUNNING** or **STOPPED** |
| `sqlreset` | Resets ALL databases & forgotten password back to fresh (asks to confirm) |
| `sqluninstall` | Completely uninstalls MariaDB and removes TxSQL shortcuts (asks to confirm) |

---

## ⚠️ Know your two prompts

This is the most common mistake for beginners.

| Prompt looks like | Where you are | What to type |
|---|---|---|
| `~ $` | Termux (bash) | Commands like `startsql`, `sqlpass`, `stopsql`, `ls` |
| `MariaDB [(none)]>` | Inside MariaDB | SQL such as `SHOW DATABASES;` |

- Typing SQL at the `~ $` prompt gives `bash: syntax error near unexpected token '('`. Nothing is broken. Run `startsql` first, and type SQL only at the `MariaDB [(none)]>` prompt.
- Typing `EXIT;` at `MariaDB [(none)]>` takes you back to `~ $`.
- Typing `exit` at `~ $` **closes the Termux app**.

---

## 🔐 Set or Change Root Password

From the normal `~ $` prompt, simply run:

```bash
sqlpass
```

It starts the server if needed, asks for your current password (if set), and sets a new one. Press **Enter** on an empty password prompt if you want to remove the password completely.

**Manual SQL Way** (only at the `MariaDB [(none)]>` prompt), if reuqired:

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_password_here';
FLUSH PRIVILEGES;
```

---

## 🧯 Troubleshooting

| You see | Meaning | Fix |
|---|---|---|
| `bash: syntax error near unexpected token '('` | SQL typed at the `~ $` prompt | Run `startsql`, then type SQL at `MariaDB [(none)]>` |
| `curl: (22)` or download fails | ISP block or connection drop | Use the direct GitHub fallback URL shown in the Install section |
| `Access denied for user 'root'` | Wrong password or old socket lock | Re-run the install command to auto-repair. If password is forgotten, run `sqlreset` |
| `Can't connect to local server` | Server is stopped | Always use `startsql` instead of `mysql` directly |
| Server turns off when screen is off | Android battery saver killed background app | Run `startsql` again. The script uses `termux-wake-lock` automatically |

---

## 🔄 Reset or Uninstall

**Fresh database (keeps MariaDB installed, resets forgotten password):**

```bash
sqlreset
```
*(Asks you to type `RESET` to confirm)*

**Complete Uninstall (removes MariaDB, all data, and commands):**

```bash
sqluninstall
```
*(Asks you to type `UNINSTALL` to confirm)*

---

## 🔍 What the script does

1. Checks it is running in Termux as a normal user with sufficient space.
2. Installs `mariadb` non-interactively via `pkg`.
3. Initialises the data directory using standard password/native authentication so root socket locking errors never happen.
4. Verifies server startup cleanly using polling instead of hardcoded delay timeouts.
5. Writes `~/.txsql.sh` (the helper commands) and loads it safely from `~/.bashrc`.

---

## 🤝 Contributing

Fork the repository and send a pull request with improvements.

**Maintained by [Adish08](https://github.com/Adish08)**
