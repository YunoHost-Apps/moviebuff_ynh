### Moderation

Moderation is done at `https://__DOMAIN__/moderation/`, with the administrator account created during the installation, which holds every staff role: reports, sign-up requests and invitations, other servers and accounts, the server's rules and texts. Nothing tells a moderator that a report or a sign-up is waiting, so look there from time to time.

Who may create an account is chosen in `/moderation/` › Settings. The answer given at installation is only the starting value: changing it afterwards happens there, not in YunoHost.

### Services

MovieBuff runs as four services, all needed:

- `__APP__`: the web server
- `__APP__-worker`: everything sent to other servers, e-mails and the members' data exports. If it stops, the site keeps working but federation stops, without any error.
- `__APP__-peer-reads`: what MovieBuff reads from other servers, one at a time, so a slow server never holds up the deliveries
- `__APP__-beat`: the scheduled tasks (publishing lists, account deletions and suspensions coming due, clean-ups, and the release calendar, refreshed from TMDB every night at 04:37 server time)

The *Health* tab of `/moderation/` shows the queues and when each scheduled task last ran.

Logs: `journalctl -u __APP__ -u __APP__-worker -u __APP__-peer-reads -u __APP__-beat`

### Files

- `__INSTALL_DIR__/exports/`: the archives members ask for with "Export my data", deleted after seven days
- `__INSTALL_DIR__/jellyfin-plugin/`: the Jellyfin plugin, see below
- `__INSTALL_DIR__/cache/`: a cache, which can be emptied

Upgrades replace `__INSTALL_DIR__/app/` and leave these alone.

### E-mail

How e-mails are sent is set in the *Configuration* panel above. To check it, as root:

```bash
sudo -u __APP__ __INSTALL_DIR__/venv/bin/python __INSTALL_DIR__/app/manage.py sendtestemail you@example.org
```

### Maintenance commands

As root, from `__INSTALL_DIR__/app`:

```bash
sudo -u __APP__ __INSTALL_DIR__/venv/bin/python manage.py prune_remote_posts --dry-run
```

### Jellyfin plugin

MovieBuff can offer its Jellyfin plugin at `https://__DOMAIN__/jellyfin/manifest.json`, but the plugin is not part of the source code: it is built separately and its archives go into `__INSTALL_DIR__/jellyfin-plugin/`. Until something is there, the Connections panel says the server has no plugin to offer. How to build it: [upstream documentation](https://codeberg.org/retiolus/moviebuff/src/branch/main/docs/deployment.md#the-jellyfin-plugin).

See the [upstream documentation](https://codeberg.org/retiolus/moviebuff/src/branch/main/docs/deployment.md#maintenance).
