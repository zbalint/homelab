#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"

readonly CONFIG_DIR="/root"
readonly FIRST_RUN_FLAG="${CONFIG_DIR}/.initialized"
# readonly CONFIG_DIR="/home/zbalint/.hl-test-config"
readonly GLOBAL_SECRET_DIR="/secrets"
readonly CONTAINER_SECRET_DIR="${CONFIG_DIR}/secrets"
readonly ENCRYPTION_KEY_FILE_PATH="${GLOBAL_SECRET_DIR}/.encryption_key"
readonly GOCRYPTFS_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.gocryptfs_secret.enc"
readonly GOTIFY_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.gotify_secret.enc"
readonly DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.discord_secrets_secret.enc"
readonly DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.discord_notif_secret.enc"

readonly GOCRYPTFS_VERSION="2.6.1"
readonly GOCRYPTFS_ARCHIVE_URL="https://github.com/rfjakob/gocryptfs/releases/download/v${GOCRYPTFS_VERSION}/gocryptfs_v${GOCRYPTFS_VERSION}_linux-static_amd64.tar.gz"

readonly GOCRYPTFS_PLAIN_DOCKER_DIR_PATH="/opt/docker"
readonly GOCRYPTFS_PLAIN_TAILSCALE_DIR_PATH="/var/lib/tailscale"
readonly GOCRYPTFS_BACKUP_DOCKER_DIR_PATH="/backup/${CONTAINER_NAME}/docker"
readonly GOCRYPTFS_BACKUP_TAILSCALE_DIR_PATH="/backup/${CONTAINER_NAME}/tailscale"
readonly GOCRYPTFS_CIPHER_DIR_PATH="/opt/cipher"
readonly GOCRYPTFS_RESTORE_DIR_PATH="/opt/restore"

readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/zbalint/homelab/master"
readonly GITHUB_FIREWALL_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/firewall/nftables.conf"
readonly GITHUB_FIREWALL_CONFIG_URL="${GITHUB_BASE_URL}/firewall/${CONTAINER_NAME}/nftables.conf"
readonly GITHUB_DOCKER_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/docker/daemon.json"
readonly GITHUB_DOCKER_CONFIG_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/daemon.json"
readonly GITHUB_DOCKER_COMPOSE_FILE_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/docker-compose.yaml"
readonly GITHUB_DOCKER_COMPOSE_ENV_FILE_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/env.enc"
readonly GITHUB_GOTIFY_SECRET_URL="${GITHUB_BASE_URL}/secret/.gotify_secret.enc"
readonly GITHUB_DISCORD_NOTIF_CHANNEL_SECRET_URL="${GITHUB_BASE_URL}/secret/.discord_notif_secret.enc"
readonly GITHUB_DISCORD_SECRETS_CHANNEL_SECRET_URL="${GITHUB_BASE_URL}/secret/.discord_secrets_secret.enc"

readonly FIREWALL_CONFIG_FILE_PATH="/etc/nftables.conf"
readonly FIREWALL_BACKUP_FILE_PATH="/etc/nftables.conf.bak"

readonly DOCKER_CONFIG_FILE_PATH="/etc/docker/daemon.json"
readonly DOCKER_BACKUP_FILE_PATH="/etc/docker/daemon.json.bak"

readonly DOCKER_USER="tartarus"
readonly DOCKER_PROJECT_BASE_DIR="/opt/docker/stacks"
readonly DOCKER_PROJECT_FILE_NAME="docker-compose.yml"
readonly DOCKER_PROJECT_ENV_FILE_NAME=".env"
readonly DOCKER_PROJECT_ENV_ENC_FILE_NAME="env_enc"

declare GOTIFY_SECRET
declare DISCORD_SECRETS_CHANNEL_SECRET
declare DISCORD_NOFIY_CHANNEL_SECRET
declare GOCRYPTFS_SECRET

function is_var_equals() {
    local var="$1"
    local str="$2"

    if [ "${var}" == "${str}" ]; then
        return 0
    else
        return 1
    fi
}

function is_file_exists() {
    local file="$1"

    test -f "${file}"
}

function is_dir_exists() {
    local dir="$1"

    test -d "${dir}"
}

function is_dir_mounted() {
    local directory="$1"

    if mountpoint -q "${directory}"; then
        return 0
    fi

    return 1
}

function read_file() {
    local file="$1"

    if is_file_exists "${file}"; then
        cat "${file}"
    fi
}

function write_file() {
    local file="$1"
    local content="$2"

    echo -n "${content}" > "${file}"
}

function init_config_dir() {
    if ! is_dir_exists "${CONTAINER_SECRET_DIR}"; then
        mkdir -p "${CONTAINER_SECRET_DIR}" &&  chmod 700 "${CONTAINER_SECRET_DIR}"
    fi
}

function generate_random_string() {
    local length="$1"
    openssl rand -hex "${length}"
}

function encrypt_file() {
    local plain_file="$1"
    local encrypted_file="$2"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -e -k "${key}" -in "${plain_file}" -out "${encrypted_file}"
}

function decrypt_file() {
    local encrypted_file="$1"
    local plain_file="$2"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -d -k "${key}" -in "${encrypted_file}" -out "${plain_file}"
}

function encrypt_string() {
    local plain_text="$*"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    echo -n "${plain_text}" | openssl enc -chacha20 -pbkdf2 -iter 200000 -a -e -k "${key}" | base64 -d | base64 -w 0
}

function decrypt_string() {
    local encrypted_text="$*"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    echo "${encrypted_text}" | openssl enc -chacha20 -pbkdf2 -iter 200000 -a -d -k "${key}"
}

function decrypt_file_content() {
    local file="$1"

    decrypt_string "$(read_file "${file}")"
}

function compare_files() {
    local file_1="$1"
    local file_2="$2"

    diff "${file_1}" "${file_2}" >/dev/null 2>&1
}

function download_file() {
    local url=$1
    local dest=$2

    curl -fsSL "${url}" -o "${dest}" >/dev/null 2>&1
}

function copy_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/cp -rf "${src_file}" "${dst_file}" >/dev/null 2>&1
}

function move_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/mv -f "${src_file}" "${dst_file}" >/dev/null 2>&1
}

function create_dir() {
    local dir="$1"

    mkdir -p "${dir}" >/dev/null 2>&1 && chown ${DOCKER_USER}:${DOCKER_USER} "${dir}" >/dev/null 2>&1
}

function is_first_run() {
    if is_file_exists "${FIRST_RUN_FLAG}"; then
        return 1
    else
        return 0
    fi
}

function clear_first_run_flag() {
    touch "${FIRST_RUN_FLAG}"
}

function stop_docker_daemon() {
    echo "INFO: Stopping docker daemon... (5s wait time)"
    systemctl stop docker.socket && systemctl stop docker.service && systemctl stop containerd.service && sleep 5
}

function start_docker_daemon() {
    echo "INFO: Starting docker daemon... (5s wait time)"
    systemctl start containerd.service && systemctl start docker.service && systemctl start docker.socket && sleep 5
}

function stop_tailscale_daemon() {
    tailscale down; systemctl stop tailscaled
}

function start_tailscale_daemon() {
    systemctl start tailscaled && tailscale up
}

function download_from_github() {
    local original_file_path="$1"
    local backup_file_path="${original_file_path}.bak"
    local github_url="$2"

    copy_file "${original_file_path}" "${backup_file_path}"
    if download_file "${github_url}" "${original_file_path}"; then
        return 0
    else
        copy_file "${backup_file_path}" "${original_file_path}"
        return 1
    fi

    return 1
}

function download_gotify_secret() {
    local encrypted_secret
    local decrypted_secret

    if download_from_github "${GOTIFY_SECRET_FILE_PATH}" "${GITHUB_GOTIFY_SECRET_URL}"; then
        echo "INFO: Gotify secret successfully downloaded."
    else
        echo "WARN: Failed to download Gotify secret from github!"
    fi

    if is_file_exists "${GOTIFY_SECRET_FILE_PATH}"; then
        encrypted_secret="$(read_file "${GOTIFY_SECRET_FILE_PATH}")"
        decrypted_secret="$(decrypt_string "${encrypted_secret}")"
        GOTIFY_SECRET="${decrypted_secret}"
        return 0
    else
        echo "ERROR: Gotify secret file does not exists!"
        return 1
    fi
}

function download_discord_secret() {
    local encrypted_secret
    local decrypted_secret

    if download_from_github "${DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH}" "${GITHUB_DISCORD_NOTIF_CHANNEL_SECRET_URL}"; then
        echo "INFO: Discord notif channel secret successfully downloaded."
    else
        echo "WARN: Failed to download Discord notif channel secret from github!"
    fi
    
    if download_from_github "${DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH}" "${GITHUB_DISCORD_SECRETS_CHANNEL_SECRET_URL}"; then
        echo "INFO: Discord secrets channel secret successfully downloaded."
    else
        echo "WARN: Failed to download Discord secrets channel secret from github!"
    fi
    

    if is_file_exists "${DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH}"; then
        encrypted_secret="$(read_file "${DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH}")"
        decrypted_secret="$(decrypt_string "${encrypted_secret}")"
        DISCORD_NOFIY_CHANNEL_SECRET="${decrypted_secret}"
    else
        echo "ERROR: Discord secrets channel secret file does not exists!"
    fi

    if is_file_exists "${DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH}"; then
        encrypted_secret="$(read_file "${DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH}")"
        decrypted_secret="$(decrypt_string "${encrypted_secret}")"
        DISCORD_SECRETS_CHANNEL_SECRET="${decrypted_secret}"
    else
        echo "ERROR: Discord secrets channel secret file does not exists!"
    fi
    
}

function send_gotify_notification() {
    local secret; secret="$(decrypt_file_content ${GOTIFY_SECRET_FILE_PATH})"
    local title="$1"; shift
    local message="$*"
    local priority=5
    local gotify_url="https://gotify.lab.escapethelan.com/message?token=${secret}"

    if ! curl --insecure -m 10 --retry 2 "${gotify_url}" -F "title=${title}" -F "message=${message}" -F "priority=${priority}" > /dev/null 2>&1; then
        echo "ERROR: Failed to send notification to the Gotify server!"
    fi
}

function send_discord_notification() {
    local type="$1"; shift
    local secret
    local discord_url
    local content_type
    local message

    if is_var_equals "${type}" "notif"; then
        secret="$(decrypt_file_content ${DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH})"
    elif is_var_equals "${type}" "secret"; then
        secret="$(decrypt_file_content ${DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH})"
    else
        echo "ERROR: Invalid Discord channel type!"
        return 1
    fi
    
    discord_url="https://discord.com/api/webhooks/${secret}"
    content_type="Content-Type: application/json"
    message="$*"

    if  [ -n "${secret}" ]; then
        curl -H "${content_type}" -X POST -d "{\"content\":\"${message}\"}" "${discord_url}" >/dev/null 2>&1
    fi
}

function backup_firewall_config() {
    copy_file ${FIREWALL_CONFIG_FILE_PATH} ${FIREWALL_BACKUP_FILE_PATH}
}

function restore_firewall_config() {
    copy_file ${FIREWALL_BACKUP_FILE_PATH} ${FIREWALL_CONFIG_FILE_PATH}
}

function download_firewall_config() {
    if ! download_file "${GITHUB_FIREWALL_CONFIG_URL}" "${FIREWALL_CONFIG_FILE_PATH}"; then
        download_file "${GITHUB_FIREWALL_DEFAULT_CONFIG_URL}" "${FIREWALL_CONFIG_FILE_PATH}"
    fi
}

function reload_firewall_config() {
    systemctl reload nftables >/dev/null 2>&1
}

function compate_firewall_config() {
    compare_files "${FIREWALL_CONFIG_FILE_PATH}" "${FIREWALL_BACKUP_FILE_PATH}"
}

function update_firewall_config() {
    if backup_firewall_config; then
        if download_firewall_config; then
            if compate_firewall_config; then
                echo "INFO: The downloaded firewall config does not contains changes. Skipping update."
            elif reload_firewall_config; then
                echo "INFO: Firewall config succesfully updated and loaded."
            elif restore_firewall_config && reload_firewall_config; then
                echo "WARN: Firewall config update/load failed, but sucessfully restored and loaded."
            else
                echo "ERROR: Firewall config failed to update/load and failed to restore/load."
                return 1
            fi
        else
            echo "ERROR: Failed to download firewall config!"
            return 1
        fi
    else
        echo "ERROR: Failed to backup firewall config!"
        return 1
    fi
}

function backup_docker_daemon_config() {
    copy_file ${DOCKER_CONFIG_FILE_PATH} ${DOCKER_BACKUP_FILE_PATH}
}

function restore_docker_daemon_config() {
    copy_file ${DOCKER_BACKUP_FILE_PATH} ${DOCKER_CONFIG_FILE_PATH}
}

function download_docker_daemon_config() {
    if ! download_file "${GITHUB_DOCKER_CONFIG_URL}" "${DOCKER_CONFIG_FILE_PATH}"; then
        download_file "${GITHUB_DOCKER_DEFAULT_CONFIG_URL}" "${DOCKER_CONFIG_FILE_PATH}"
    fi
}

function reload_docker_daemon_config() {
    stop_docker_daemon
    start_docker_daemon
}

function compare_docker_config() {
    compare_files "${DOCKER_CONFIG_FILE_PATH}" "${DOCKER_BACKUP_FILE_PATH}"
}

function update_docker_config() {
    if backup_docker_daemon_config; then
        if download_docker_daemon_config; then
            if compare_docker_config; then
                echo "INFO: The downloaded docker daemon config does not contains changes. Skipping update."
            elif reload_docker_daemon_config; then
                echo "INFO: Docker daemon config succesfully updated and loaded."
            elif restore_docker_daemon_config && reload_docker_daemon_config; then
                echo "WARN: Docker daemon config update/load failed, but sucessfully restored and loaded."
            else
                echo "ERROR: Docker daemon config failed to update/load and failed to restore/load."
                return 1
            fi
        else
            echo "ERROR: Failed to download docker daemon config!"
            return 1
        fi
    else
        echo "ERROR: Failed to backup docker daemon config."
        return 1
    fi
}

function get_project_name() {
    local container_name="${CONTAINER_NAME}"
    local temp_rm_prefix=${container_name#lxc-}
    local temp_rm_postfix=${temp_rm_prefix%-0*}
    local project_name=${temp_rm_postfix}

    echo "${project_name}"
}

function install_gocryptfs() {
    if ! gocryptfs -version >/dev/null 2>&1; then
        local archive_path="/tmp/gocryptfs.tar.gz"
        local extract_path="/tmp/gocryptfs"
        if wget -q "${GOCRYPTFS_ARCHIVE_URL}" -O "${archive_path}" && is_file_exists "${archive_path}"; then
            mkdir "${extract_path}" >/dev/null 2>&1 && \
            tar -xvf "${archive_path}" -C "${extract_path}" >/dev/null 2>&1 && \
            mv "${extract_path}/gocryptfs" /usr/bin/gocryptfs >/dev/null 2>&1 && \
            mv "${extract_path}/gocryptfs-xray" /usr/bin/gocryptfs-xray >/dev/null 2>&1 && \
            chmod 700 /usr/bin/gocryptfs >/dev/null 2>&1 && \
            chmod 700 /usr/bin/gocryptfs-xray >/dev/null 2>&1 && \
            rm -rf "${extract_path}"

            if gocryptfs -version >/dev/null 2>&1; then
                echo "INFO: Gocryptfs successfully installed."
                return 0
            else
                echo "FATAL: Could not install gocryptfs"
                return 1
            fi
            
        else
            echo "ERROR: Could not download gocryptfs!"
            return 1
        fi
    fi
}

function init_gocryptfs_dir() {
    local type="$1"
    local directory="$2"
    local mode="$3"

    if ! is_dir_exists "${directory}"; then
        echo "INFO: Creating gocryptfs ${type} dir at ${directory}"
        mkdir -p "${directory}" && chmod "${mode}" "${directory}"
    fi
}

function init_gocryptfs_dirs() {
    init_gocryptfs_dir "plain" "${GOCRYPTFS_PLAIN_DOCKER_DIR_PATH}" "755"
    init_gocryptfs_dir "plain" "${GOCRYPTFS_PLAIN_TAILSCALE_DIR_PATH}" "700"
    init_gocryptfs_dir "backup" "${GOCRYPTFS_BACKUP_DOCKER_DIR_PATH}" "700"
    init_gocryptfs_dir "backup" "${GOCRYPTFS_BACKUP_TAILSCALE_DIR_PATH}" "700"
    init_gocryptfs_dir "cipher" "${GOCRYPTFS_CIPHER_DIR_PATH}" "700"
    init_gocryptfs_dir "restore" "${GOCRYPTFS_RESTORE_DIR_PATH}" "700"
}

function generate_gocryptfs_password() {
    local password_length=32
    local password; 
    local encrypted_password; 
    
    if is_file_exists "${GOCRYPTFS_SECRET_FILE_PATH}"; then
        echo "INFO: Loading gocryptfs secret into memory." 
        encrypted_password="$(read_file "${GOCRYPTFS_SECRET_FILE_PATH}")"
        password="$(decrypt_string "${encrypted_password}")"
        GOCRYPTFS_SECRET="${password}"
    else
        echo "WARN: Generating new password for gocryptfs folder..."
        password="$(generate_random_string ${password_length})"
        encrypted_password="$(encrypt_string "${password}")"

        write_file "${GOCRYPTFS_SECRET_FILE_PATH}" "${encrypted_password}"
        GOCRYPTFS_SECRET="${password}"

        send_discord_notification "secret" "Container:\n${CONTAINER_NAME}\nSECRET:\n${encrypted_password}"
    fi
}

function init_gocryptfs_volume() {
    local plain_dir="$1"

    if is_file_exists "${plain_dir}/.gocryptfs.reverse.conf"; then
        echo "INFO: Gocryptfs reverse volume found at ${plain_dir}"
        return 0
    fi

    if echo "${GOCRYPTFS_SECRET}" | gocryptfs -init -reverse "${plain_dir}"; then
        echo "INFO: Gocryptfs reverse volume initialized at ${plain_dir}"
        return 0
    else
        echo "ERROR: Could not initialize gocryptfs at ${plain_dir}!"
        return 1
    fi
}

function init_gocryptfs_docker() {
    init_gocryptfs_volume "${GOCRYPTFS_PLAIN_DOCKER_DIR_PATH}"
}

function init_gocryptfs_tailscale() {
    init_gocryptfs_volume "${GOCRYPTFS_PLAIN_TAILSCALE_DIR_PATH}"
}

function mount_gocryptfs_volume() {
    local mode="$1"
    local plain_dir="$2"
    local cipher_dir="$3"

    if is_var_equals "${mode}" "normal"; then
        if is_dir_mounted "${plain_dir}"; then
            echo "WARN: Gocrypfs plain dir already mounted at ${plain_dir}"
        else
            echo "${GOCRYPTFS_SECRET}" | gocryptfs "${cipher_dir}" "${plain_dir}"
            echo "INFO: Gocrypfs cipher dir ${cipher_dir} mounted as plain dir at ${plain_dir}"
        fi
    elif is_var_equals "${mode}" "reverse"; then
        if is_dir_mounted "${cipher_dir}"; then
            echo "WARN: Gocrypfs cipher dir already mounted at ${cipher_dir}"
        else
            echo "${GOCRYPTFS_SECRET}" | gocryptfs -reverse "${plain_dir}" "${cipher_dir}"
            echo "INFO: Gocrypfs plain dir ${plain_dir} mounted as cipher dir at ${cipher_dir}"
        fi
    else
        echo "ERROR: Invalid gocryptfs mount mode!"
        return 1
    fi
}

function umount_gocryptfs_volume() {
    local mount_path="$1"

    if is_dir_mounted "${mount_path}"; then
        if umount "${mount_path}"; then
            echo "INFO: Gocrypfs dir unmounted at ${mount_path}"
            return 0
        else
            echo "ERROR: Failed to unmount gocryptfs dir at ${mount_path}"
            return 1
        fi
    else
        echo "WARN: Gocrypfs dir already unmounted at ${mount_path}"
        return 0
    fi
}

function umount_gocryptfs_backup_volume() {
    umount_gocryptfs_volume "${GOCRYPTFS_CIPHER_DIR_PATH}"
}

function umount_gocryptfs_restore_volume() {
    umount_gocryptfs_volume "${GOCRYPTFS_RESTORE_DIR_PATH}"
}

function mount_gocryptfs_docker_volume() {
    mount_gocryptfs_volume "reverse" "${GOCRYPTFS_PLAIN_DOCKER_DIR_PATH}" "${GOCRYPTFS_CIPHER_DIR_PATH}"
}

function mount_gocryptfs_tailscale_volume() {
    mount_gocryptfs_volume "reverse" "${GOCRYPTFS_PLAIN_TAILSCALE_DIR_PATH}" "${GOCRYPTFS_CIPHER_DIR_PATH}"
}

function mount_gocryptfs_restore_volume() {
    mount_gocryptfs_volume "normal" "${GOCRYPTFS_RESTORE_DIR_PATH}" "${GOCRYPTFS_BACKUP_DIR_PATH}"
}

function mount_gocryptfs_docker_restore_volume() {
    mount_gocryptfs_volume "normal" "${GOCRYPTFS_RESTORE_DIR_PATH}" "${GOCRYPTFS_BACKUP_DOCKER_DIR_PATH}"
}

function mount_gocryptfs_tailscale_restore_volume() {
    mount_gocryptfs_volume "normal" "${GOCRYPTFS_RESTORE_DIR_PATH}" "${GOCRYPTFS_BACKUP_TAILSCALE_DIR_PATH}"
}

function backup_directory() {
    local source_dir="$1"
    local dest_dir="$2"

    rsync -av --delete "${source_dir}/" "${dest_dir}/" >/dev/null 2>&1
}

function backup_docker_directory() {
    local result=1

    if mount_gocryptfs_docker_volume; then
        stop_docker_daemon
        if backup_directory "${GOCRYPTFS_CIPHER_DIR_PATH}/" "${GOCRYPTFS_BACKUP_DOCKER_DIR_PATH}/"; then
            echo "INFO: Docker directory backup was successful!"
            result=0
        else
            echo "ERROR: Docker directory backup failed!"
        fi
        umount_gocryptfs_backup_volume
        start_docker_daemon
    else
        echo "ERROR: Failed to mount docker backup directory!"
        result=1
    fi

    return ${result}
}

function backup_tailscale_directory() {
    local result=1

    if mount_gocryptfs_tailscale_volume; then
        stop_tailscale_daemon
        if backup_directory "${GOCRYPTFS_CIPHER_DIR_PATH}/" "${GOCRYPTFS_BACKUP_TAILSCALE_DIR_PATH}/"; then
            echo "INFO: Tailsacle directory backup was successful!"
            result=0
        else
            echo "ERROR: Tailscale directory backup failed!"
        fi
        umount_gocryptfs_backup_volume
        start_tailscale_daemon
    fi

    return ${result}
}

function restore_directory() {
    local source_dir="$1"
    local dest_dir="$2"

    if is_file_exists "${dest_dir}/.gocryptfs.reverse.conf"; then
        mv "${dest_dir}/.gocryptfs.reverse.conf" "${CONFIG_DIR}/.gocryptfs.reverse.conf"
    fi
    rsync -av --delete "${source_dir}/" "${dest_dir}/"
    local result=$?
    if is_file_exists "${CONFIG_DIR}/.gocryptfs.reverse.conf"; then
        mv "${CONFIG_DIR}/.gocryptfs.reverse.conf" "${dest_dir}/.gocryptfs.reverse.conf"
    fi

    return ${result}
}

function restore_docker_directory() {
    local result=1

    if mount_gocryptfs_docker_restore_volume; then
        stop_docker_daemon
        if restore_directory "${GOCRYPTFS_RESTORE_DIR_PATH}" "${GOCRYPTFS_PLAIN_DOCKER_DIR_PATH}"; then
            echo "INFO: Docker directory restore was successful!"
            result=0
        else
            echo "ERROR: Docker directory restore failed!"
        fi
        umount_gocryptfs_restore_volume
        start_docker_daemon
    fi
    
    return ${result}
}

function restore_tailscale_directory() {
    local result=1

    if mount_gocryptfs_tailscale_restore_volume; then
        stop_tailscale_daemon
        if restore_directory "${GOCRYPTFS_RESTORE_DIR_PATH}" "${GOCRYPTFS_PLAIN_TAILSCALE_DIR_PATH}"; then
            echo "INFO: Tailsacle directory restore was successful!"
            result=0
        else
            echo "ERROR: Tailscale directory restore failed!"
        fi
        umount_gocryptfs_restore_volume
        start_tailscale_daemon
    fi
    
    return ${result}
}

function check_for_docker_backup() {
    if is_file_exists "${GOCRYPTFS_BACKUP_DOCKER_DIR_PATH}/gocryptfs.conf"; then
        return 0
    else
        return 1
    fi
}

function check_for_tailscale_backup() {
    if is_file_exists "${GOCRYPTFS_BACKUP_TAILSCALE_DIR_PATH}/gocryptfs.conf"; then
        return 0
    else
        return 1
    fi
}

function check_for_backups() {
    if is_first_run; then
        init_gocryptfs_dirs
        echo "INFO: Running first run checks..."
        if is_file_exists "${GOCRYPTFS_SECRET_FILE_PATH}"; then
            generate_gocryptfs_password
            init_gocryptfs_docker
            init_gocryptfs_tailscale

            if check_for_docker_backup; then
                echo "INFO: Docker backup found! Restoring on first run."
                restore_docker_directory
            elif check_for_tailscale_backup; then
                echo "INFO: Tailscale backup found! Restoring on first run."
                restore_tailscale_directory
            else
                echo "INFO: No backups found!"
            fi
            clear_first_run_flag
        else
            if check_for_docker_backup || check_for_tailscale_backup; then
                echo "WARN: Backups found! Missing encryption key."
                send_discord_notification "notif" "Please provide encryption key for container ${CONTAINER_NAME} or delete existing backups!"
            else
                generate_gocryptfs_password
                init_gocryptfs_docker
                init_gocryptfs_tailscale
                clear_first_run_flag
            fi
        fi
    else
        generate_gocryptfs_password
        init_gocryptfs_docker
        init_gocryptfs_tailscale
    fi
}

function backup_docker_project() {
    echo "INFO: Starting docker project backup..."
    backup_docker_directory
}

function restore_docker_project() {
    echo "INFO: Starting docker project restore..."
    restore_docker_directory
}

function stop_docker_project() {
    local docker_project_dir="$1"

    echo "INFO: Stopping the docker project..."
    
    cd "${docker_project_dir}" || return 1
    docker compose down >/dev/null 2>&1
    cd || return 1
}

function start_docker_project() {
    local docker_project_dir="$1"

    echo "INFO: Starting the docker project..."

    cd "${docker_project_dir}" || return 1
    docker compose pull >/dev/null 2>&1 && docker compose up -d >/dev/null 2>&1
    yes | docker system prune --all >/dev/null 2>&1
    cd || return 1
}

function download_docker_project() {
    local project; project="$(get_project_name)"
    local docker_project_dir="${DOCKER_PROJECT_BASE_DIR}/${project}"
    local docker_project_file_path="${docker_project_dir}/${DOCKER_PROJECT_FILE_NAME}"
    local docker_project_temp_file_path="/tmp/${DOCKER_PROJECT_FILE_NAME}.temp"
    local docker_project_env_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_FILE_NAME}"
    local docker_project_env_enc_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_ENC_FILE_NAME}"
    local docker_project_temp_env_enc_file_path="/tmp/${DOCKER_PROJECT_ENV_ENC_FILE_NAME}.temp"

    if download_from_github "${docker_project_temp_file_path}" "${GITHUB_DOCKER_COMPOSE_FILE_URL}" && download_from_github "${docker_project_temp_env_enc_file_path}" "${GITHUB_DOCKER_COMPOSE_ENV_FILE_URL}"; then
        if compare_files "${docker_project_temp_file_path}" "${docker_project_file_path}" && compare_files "${docker_project_temp_env_enc_file_path}" "${docker_project_env_enc_file_path}"; then
            echo "INFO: The docker compose files does not contains any changes. Skipping update."
            return 1
        else
            move_file "${docker_project_temp_file_path}" "${docker_project_file_path}"
            chown ${DOCKER_USER}:${DOCKER_USER} "${docker_project_file_path}"
            echo "INFO: Docker compose file successfully downloaded."

            move_file "${docker_project_temp_env_enc_file_path}" "${docker_project_env_enc_file_path}"
            chown ${DOCKER_USER}:${DOCKER_USER} "${docker_project_env_enc_file_path}"
            echo "INFO: Encrypted docker compose env file successfully downloaded."

            if decrypt_file "${docker_project_env_enc_file_path}" "${docker_project_env_file_path}"; then
                chown ${DOCKER_USER}:${DOCKER_USER} "${docker_project_env_file_path}"
                echo "INFO: Encrypted docker compose env file sucessfuly decrypted!"
            else
                echo "ERROR: Failed to decrypt docker compose env file!"
                return 1
            fi
        fi
    else
        echo "ERROR: Failed to download docker project files from github!"
        return 1
    fi

    return 0
}

function compare_docker_project() {
    local project; project="$(get_project_name)"
    local docker_project_dir="${DOCKER_PROJECT_BASE_DIR}/${project}"
    local docker_project_file_path="${docker_project_dir}/${DOCKER_PROJECT_FILE_NAME}"
    local docker_project_env_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_FILE_NAME}"
    local docker_project_env_enc_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_ENC_FILE_NAME}"
    local new_docker_project_hash;
    local old_docker_project_hash;
    local new_docker_project_env_hash;
    local old_docker_project_env_hash;

    new_docker_project_hash="$(curl -fsSL "${GITHUB_DOCKER_COMPOSE_FILE_URL}" | sha1sum)"
    old_docker_project_hash="$(cat ${docker_project_file_path} | sha1sum)"
    
    new_docker_project_env_hash="$(curl -fsSL "${GITHUB_DOCKER_COMPOSE_ENV_FILE_URL}" | sha1sum)"
    old_docker_project_env_hash="$(cat ${docker_project_env_enc_file_path} | sha1sum)"

    if is_var_equals "${new_docker_project_hash}" "${old_docker_project_hash}" && is_var_equals "${new_docker_project_env_hash}" "${old_docker_project_env_hash}"; then
        return 0
    else
        return 1
    fi
}

function check_docker_project() {
    local docker_project_file_path="$1"
    local temp_file="/tmp/container_list"
    local status=0

    echo "INFO: Checking docker project health..."
    grep "container_name" "${docker_project_file_path}" | awk '{print $2}' > "${temp_file}"
    
    while IFS= read -r container; do
        if docker ps | grep "${container}" >/dev/null 2>&1; then
            echo "INFO: ${container} is running."
        else
            echo "ERROR: ${container} is not running!"
            status=1
        fi
    done < "${temp_file}"

    rm -f "${temp_file}"

    return ${status}
}

function update_docker_project() {
    local project; project="$(get_project_name)"
    local docker_project_dir="${DOCKER_PROJECT_BASE_DIR}/${project}"
    local docker_project_file_path="${docker_project_dir}/${DOCKER_PROJECT_FILE_NAME}"
    local docker_project_env_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_FILE_NAME}"
    local docker_project_env_enc_file_path="${docker_project_dir}/${DOCKER_PROJECT_ENV_ENC_FILE_NAME}"

    if ! is_dir_exists "${docker_project_dir}"; then
        if create_dir "${docker_project_dir}"; then
            echo "INFO: Docker project dir successfully created at ${docker_project_dir}"
        else
            echo "ERROR: Failed to create docker project dir at ${docker_project_dir}"
            return 1
        fi
    fi

    if compare_docker_project; then
        echo "INFO: The new docker project files does not contains any changes. Skipping update."
        return 0
    fi

    stop_docker_project "${docker_project_dir}"
    backup_docker_directory
    download_docker_project
    start_docker_project "${docker_project_dir}"
    echo "INFO: Waiting 10s for project start up..."
    sleep 10
    if check_docker_project "${docker_project_file_path}"; then
        echo "INFO: Docker project successfully updated!"
    else
        echo "WARN: Docker project healthcheck failed!"
        echo "INFO: Waiting 10s before attempting to restore the docker project..."
        sleep 10
        echo "INFO: Restoring docker project..."
        stop_docker_project "${docker_project_dir}"
        restore_docker_directory
        start_docker_project "${docker_project_dir}"
        if check_docker_project "${docker_project_file_path}"; then
            echo "INFO: Docker project healthcheck is successful after restore."
        else
            echo "ERROR: Docker project healthcheck still failing after restore!"
        fi
    fi
}


function init() {
    init_config_dir
    install_gocryptfs
    download_discord_secret
    download_gotify_secret
    update_firewall_config
    update_docker_config
    check_for_backups
}

function main() {
    update_docker_project
    return 0
}

init && \
main 