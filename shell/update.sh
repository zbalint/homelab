#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"

readonly CONFIG_DIR="/root"
# readonly CONFIG_DIR="/home/zbalint/.hl-test-config"
readonly GLOBAL_SECRET_DIR="/secrets"
readonly CONTAINER_SECRET_DIR="${CONFIG_DIR}/secrets"
readonly ENCRYPTION_KEY_FILE_PATH="${GLOBAL_SECRET_DIR}/.encryption_key"
readonly GOCRYPTFS_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.restic_secret"
readonly GOTIFY_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.gotify_secret"
readonly DISCORD_SECRETS_CHANNEL_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.discord_secrets_channel_secret"
readonly DISCORD_NOTIF_CHANNEL_SECRET_FILE_PATH="${CONTAINER_SECRET_DIR}/.discord_notif_channel_secret"

readonly RESTIC_VERSION="0.18.0"
readonly RESTIC_ARCHIVE_URL="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
readonly RESTIC_REPOSITORY_PATH="/backup/${CONTAINER_NAME}"

readonly GOCRYPTFS_VERSION="2.6.1"
readonly GOCRYPTFS_ARCHIVE_URL="https://github.com/rfjakob/gocryptfs/releases/download/v${GOCRYPTFS_VERSION}/gocryptfs_v${GOCRYPTFS_VERSION}_linux-static_amd64.tar.gz"
readonly GOCRYPTFS_PLAIN_DIR_PATH="/opt/docker"
readonly GOCRYPTFS_CIPER_DIR_PATH="/backup/${CONTAINER_NAME}"

readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/zbalint/homelab/master"
readonly GITHUB_FIREWALL_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/firewall/nftables.conf"
readonly GITHUB_FIREWALL_CONFIG_URL="${GITHUB_BASE_URL}/firewall/${CONTAINER_NAME}/nftables.conf"
readonly GITHUB_DOCKER_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/docker/daemon.json"
readonly GITHUB_DOCKER_CONFIG_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/daemon.json"
readonly GITHUB_DOCKER_COMPOSE_FILE_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/docker-compose.yaml"
readonly GITHUB_GOTIFY_SECRET_URL="${GITHUB_BASE_URL}/secret/.gotify_secret"
readonly GITHUB_DISCORD_NOTIF_CHANNEL_SECRET_URL="${GITHUB_BASE_URL}/secret/.discord_notif_channel_secret"
readonly GITHUB_DISCORD_SECRETS_CHANNEL_SECRET_URL="${GITHUB_BASE_URL}/secret/.discord_secrets_channel_secret"

readonly FIREWALL_CONFIG_FILE_PATH="/etc/nftables.conf"
readonly FIREWALL_BACKUP_FILE_PATH="/etc/nftables.conf.bak"

readonly DOCKER_CONFIG_FILE_PATH="/etc/docker/daemon.json"
readonly DOCKER_BACKUP_FILE_PATH="/etc/docker/daemon.json.bak"

readonly DOCKER_USER="tartarus"
# readonly DOCKER_PROJECT_DIR="/opt/docker/stacks/{project}"
readonly DOCKER_PROJECT_DIR="/tmp/docker/stacks/{project}"
readonly DOCKER_PROJECT_FILE_PATH="${DOCKER_PROJECT_DIR}/docker-compose.yml"

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

function init_config_dir() {
    mkdir -p "${CONTAINER_SECRET_DIR}"
}

function is_file_exists() {
    local file="$1"

    test -f "${file}"
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

function create_dir() {
    local dir="$1"

    mkdir -p "${dir}" >/dev/null 2>&1 && chown ${DOCKER_USER}:${DOCKER_USER} "${dir}" >/dev/null 2>&1
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

function update_firewall_config() {
    if backup_firewall_config; then
        if download_firewall_config && reload_firewall_config; then
            echo firewall config succesfully updated and loaded
        elif restore_firewall_config && reload_firewall_config; then
            echo firewall config update/load failed, but sucessfully restored and loaded
        else
            echo firewall config failed to update/load and failed to restore/load
        fi
    else
        echo failed to backup firewall config
    fi
}

function backup_docker_config() {
    copy_file ${DOCKER_CONFIG_FILE_PATH} ${DOCKER_BACKUP_FILE_PATH}
}

function restore_docker_config() {
    copy_file ${DOCKER_BACKUP_FILE_PATH} ${DOCKER_CONFIG_FILE_PATH}
}

function download_docker_config() {
    if ! download_file "${GITHUB_DOCKER_CONFIG_URL}" "${DOCKER_CONFIG_FILE_PATH}"; then
        download_file "${GITHUB_DOCKER_DEFAULT_CONFIG_URL}" "${DOCKER_CONFIG_FILE_PATH}"
    fi
}

function reload_docker_config() {
    systemctl restart docker >/dev/null 2>&1
}

function update_docker_config() {
    if backup_docker_config; then
        if download_docker_config && reload_docker_config; then
            echo docker daemon config succesfully updated and loaded
        elif restore_docker_config && reload_docker_config; then
            echo docker daemon config update/load failed, but sucessfully restored and loaded
        else
            echo docker daemon config failed to update/load and failed to restore/load
        fi
    else
        echo failed to backup docker daemon config
    fi
}

function get_project_name() {
    # local hostname="${CONTAINER_NAME}"
    local hostname="lxc-traefik-01"
    local temp_rm_prefix=${hostname#lxc-}
    local temp_rm_postfix=${temp_rm_prefix%-0*}
    local container_name=${temp_rm_postfix}

    echo "${container_name}"
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


function install_restic_archive() {
    if restic version >/dev/null 2>&1; then
        restic self-update >/dev/null 2>&1
    else
        wget -q "${RESTIC_ARCHIVE_URL}" -O /tmp/restic.bz2 && \
        bzip2 -d /tmp/restic.bz2 && \
        mv /tmp/restic /usr/bin/restic && \
        chmod +x /usr/bin/restic && \
        restic self-update >/dev/null 2>&1
    fi
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

        send_discord_notification "secret" "Container: ${CONTAINER_NAME}\nSECRET: ${encrypted_password}"
    fi
}


function init() {
    init_config_dir
    install_gocryptfs
    download_gotify_secret
    download_discord_secret
    generate_gocryptfs_password
}

function main() {
    return 0
}

init && \
main 