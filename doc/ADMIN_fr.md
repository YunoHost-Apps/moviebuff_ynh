### Modération

La modération se fait à `https://__DOMAIN__/moderation/`, avec le compte administrateur créé à l'installation, qui a tous les rôles : signalements, demandes d'inscription et invitations, autres serveurs et comptes, règles et textes du serveur. Rien ne prévient un modérateur qu'un signalement ou une inscription attend, pensez donc à y passer de temps en temps.

Qui peut créer un compte se choisit dans `/moderation/` › Paramètres. La réponse donnée à l'installation n'est que la valeur de départ : la changer ensuite se fait là, pas dans YunoHost.

### Services

MovieBuff tourne sous la forme de quatre services, tous nécessaires :

- `__APP__` : le serveur web
- `__APP__-worker` : tout ce qui part vers les autres serveurs, les e-mails et les exports de données des membres. S'il s'arrête, le site reste consultable mais la fédération s'arrête, sans aucune erreur.
- `__APP__-peer-reads` : ce que MovieBuff lit sur les autres serveurs, une lecture à la fois, pour qu'un serveur lent ne retarde jamais les envois
- `__APP__-beat` : les tâches planifiées (publication des listes, suppressions et suspensions de comptes arrivées à échéance, ménage, et le calendrier des sorties, rafraîchi depuis TMDB chaque nuit à 4 h 37, heure du serveur)

L'onglet *Santé* de `/moderation/` montre les files d'attente et quand chaque tâche planifiée a tourné pour la dernière fois.

Journaux : `journalctl -u __APP__ -u __APP__-worker -u __APP__-peer-reads -u __APP__-beat`

### Fichiers

- `__INSTALL_DIR__/exports/` : les archives que les membres demandent avec « Exporter mes données », supprimées au bout de sept jours
- `__INSTALL_DIR__/jellyfin-plugin/` : le plugin Jellyfin, voir plus bas
- `__INSTALL_DIR__/cache/` : un cache, qui peut être vidé

Les mises à jour remplacent `__INSTALL_DIR__/app/` et ne touchent pas à ces dossiers.

### Commandes de maintenance

En root, depuis `__INSTALL_DIR__/app` :

```bash
sudo -u __APP__ __INSTALL_DIR__/venv/bin/python manage.py prune_remote_posts --dry-run
```

### Plugin Jellyfin

MovieBuff peut proposer son plugin Jellyfin à l'adresse `https://__DOMAIN__/jellyfin/manifest.json`, mais le plugin ne fait pas partie du code source : il se compile à part et ses archives vont dans `__INSTALL_DIR__/jellyfin-plugin/`. Tant que ce dossier est vide, le panneau Connexions indique que le serveur n'a pas de plugin à proposer. Pour le compiler : [documentation upstream](https://codeberg.org/retiolus/moviebuff/src/branch/main/docs/deployment.md#the-jellyfin-plugin).

Voir la [documentation upstream](https://codeberg.org/retiolus/moviebuff/src/branch/main/docs/deployment.md#maintenance).
