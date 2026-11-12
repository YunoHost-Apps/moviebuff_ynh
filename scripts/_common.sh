#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# The Django project root: settings.py reads .env from here
code_dir="$install_dir/app"

# The web service keeps the app's own name, so that `yunohost service` and
# the diagnosis point at the one people care about first
_moviebuff_services() {
    echo "$app $app-worker $app-peer-reads $app-beat"
}

# The venv is rebuilt every time to follow Python upgrades of the system
_moviebuff_install_code() {
    ynh_setup_source --dest_dir="$code_dir" --full_replace

    ynh_safe_rm "$install_dir/venv"
    chown -R "$app:$app" "$install_dir"
    pushd "$install_dir"
        ynh_exec_as_app python3 -m venv "$install_dir/venv"
        ynh_hide_warnings ynh_exec_as_app "$install_dir/venv/bin/pip" install --no-cache-dir --upgrade pip
        ynh_hide_warnings ynh_exec_as_app "$install_dir/venv/bin/pip" install --no-cache-dir -r "$code_dir/requirements.txt"
    popd
    ynh_safe_rm "$install_dir/.cache"
}

_moviebuff_write_env() {
    # Set from the config panel, which refuses to open while one of them is
    # missing from the settings. An instance from before the choice keeps
    # sending as it did: through its own server if it named one, else not at all
    ynh_app_setting_set_default --key=email_mode --value="$([ -n "${email_host:-}" ] && echo custom || echo none)"
    ynh_app_setting_set_default --key=mail_user --value="$app"
    ynh_app_setting_set_default --key=mail_domain --value="$domain"
    ynh_app_setting_set_default --key=email_host --value=""
    ynh_app_setting_set_default --key=email_port --value=587
    ynh_app_setting_set_default --key=email_security --value=starttls
    ynh_app_setting_set_default --key=email_user --value=""
    ynh_app_setting_set_default --key=email_password --value=""
    ynh_app_setting_set_default --key=email_from --value=""

    # Read by the template
    smtp_host="" smtp_port=587 smtp_user="" smtp_password="" smtp_from=""
    smtp_use_tls=False smtp_use_ssl=False smtp_tls_server_name=""
    case "$email_mode" in
        yunohost)
            # YunoHost's postfix, reached on this machine: its certificate
            # carries the public name it is chosen by (SNI)
            smtp_host=127.0.0.1 smtp_use_tls=True
            smtp_user="$app" smtp_password="$mail_pwd"
            smtp_from="$mail_user@$mail_domain" smtp_tls_server_name="$domain"
            ;;
        custom)
            smtp_host="$email_host" smtp_port="$email_port"
            smtp_use_tls="$([ "$email_security" == starttls ] && echo True || echo False)"
            smtp_use_ssl="$([ "$email_security" == ssl ] && echo True || echo False)"
            smtp_user="$email_user" smtp_password="$email_password" smtp_from="$email_from"
            ;;
    esac
    timezone="$(timedatectl show --value --property=Timezone 2> /dev/null || echo UTC)"
    webpush_contact="mailto:$(ynh_user_get_info --username="$admin" --key=mail)"
    webpush_public_key="${webpush_public_key:-}"
    webpush_private_key="${webpush_private_key:-}"

    ynh_config_add --template="env" --destination="$code_dir/.env"
    chmod 400 "$code_dir/.env"
    chown "$app:$app" "$code_dir/.env"
}

_moviebuff_add_config() {
    _moviebuff_write_env

    # Outside $code_dir, which every upgrade replaces. Created up front:
    # systemd refuses to start a unit whose ReadWritePaths is missing
    local dir
    for dir in cache beat jellyfin-plugin exports; do
        mkdir -p "$install_dir/$dir"
        chown "$app:$app" "$install_dir/$dir"
    done

    # Minted once and kept: a new pair silently unsubscribes every device.
    # The command needs the settings, hence the .env written first without them
    if [ -z "$webpush_public_key" ] || [ -z "$webpush_private_key" ]; then
        local keys
        keys="$(_moviebuff_manage webpush_keys 2> /dev/null)"
        webpush_public_key="$(sed -n 's/^WEBPUSH_PUBLIC_KEY=//p' <<< "$keys")"
        webpush_private_key="$(sed -n 's/^WEBPUSH_PRIVATE_KEY=//p' <<< "$keys")"
        ynh_app_setting_set --key=webpush_public_key --value="$webpush_public_key"
        ynh_app_setting_set --key=webpush_private_key --value="$webpush_private_key"
        _moviebuff_write_env
    fi
}

_moviebuff_manage() {
    pushd "$code_dir" > /dev/null
        ynh_exec_as_app "$install_dir/venv/bin/python" manage.py "$@"
    popd > /dev/null
}

_moviebuff_build() {
    _moviebuff_manage migrate --noinput
    # Bootstrap, its icons and htmx, checked against pinned SHA-256: the
    # running site never reaches a CDN
    _moviebuff_manage fetch_frontend_assets
    _moviebuff_manage collectstatic --noinput --verbosity 0
    # The .mo files are not in the repository: without them every page is in English
    _moviebuff_manage compilemessages --verbosity 0

    _moviebuff_set_permissions
}

_moviebuff_set_permissions() {
    chown -R "$app:$app" "$install_dir"
    chmod -R o-rwx "$install_dir"
    # NGINX serves the static files itself, so it must reach them
    chown "$app:www-data" "$install_dir"
    chmod 750 "$install_dir"
    chown -R "$app:www-data" "$install_dir/staticfiles"
    chmod -R g+rX "$install_dir/staticfiles"
}

# Through stdin rather than createsuperuser's environment variables, which
# would show the password on sudo's command line
_moviebuff_create_admin() {
    local email password_b64
    email="$(ynh_user_get_info --username="$admin" --key=mail)"
    password_b64="$(printf '%s' "$password" | base64 --wrap=0)"
    _moviebuff_manage shell --no-imports --verbosity 0 << EOF
import base64
from django.contrib.auth import get_user_model

get_user_model().objects.create_superuser(
    username="$admin",
    email="$email",
    password=base64.b64decode("$password_b64").decode(),
)
EOF
}

_moviebuff_add_services() {
    ynh_config_add_systemd --service="$app" --template="web.service"
    ynh_config_add_systemd --service="$app-worker" --template="worker.service"
    ynh_config_add_systemd --service="$app-peer-reads" --template="peer-reads.service"
    ynh_config_add_systemd --service="$app-beat" --template="beat.service"
    _moviebuff_register_services
}

_moviebuff_register_services() {
    yunohost service add "$app" --description="MovieBuff web server"
    yunohost service add "$app-worker" --description="MovieBuff federation worker"
    yunohost service add "$app-peer-reads" --description="MovieBuff reads from other servers"
    yunohost service add "$app-beat" --description="MovieBuff scheduled tasks"
}

_moviebuff_start() {
    ynh_systemctl --service="$app-worker" --action="start"
    ynh_systemctl --service="$app-peer-reads" --action="start"
    ynh_systemctl --service="$app-beat" --action="start"
    ynh_systemctl --service="$app" --action="start" --log_path="systemd" --wait_until="Booting worker"
}

_moviebuff_stop() {
    local service
    for service in $(_moviebuff_services); do
        if [ -e "/etc/systemd/system/$service.service" ]; then
            ynh_systemctl --service="$service" --action="stop"
        fi
    done
}
