#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"

# readonly CONFIG_DIR="/root"
readonly CONFIG_DIR="/home/zbalint/.hl-test-config"
readonly GLOBAL_SECRET_DIR="/secrets"
readonly CONTAINER_SECRET_DIR="${CONFIG_DIR}/secrets"
readonly ENCRYPTION_KEY_FILE="${GLOBAL_SECRET_DIR}/.encryption_key"
readonly DISCORD_SECRET_FILE="${CONTAINER_SECRET_DIR}/.discord_secret"
readonly RESTIC_SECRET_FILE="${CONTAINER_SECRET_DIR}/.restic_secret"



readonly RESTIC_VERSION="0.18.0"
readonly RESTIC_ARCHIVE_URL="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
readonly RESTIC_REPOSITORY_PATH="/backup/${CONTAINER_NAME}"


readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/zbalint/homelab/master"
readonly GITHUB_FIREWALL_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/firewall/nftables.conf"
readonly GITHUB_FIREWALL_CONFIG_URL="${GITHUB_BASE_URL}/firewall/${CONTAINER_NAME}/nftables.conf"
readonly GITHUB_DOCKER_DEFAULT_CONFIG_URL="${GITHUB_BASE_URL}/docker/daemon.json"
readonly GITHUB_DOCKER_CONFIG_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/daemon.json"
readonly GITHUB_DOCKER_COMPOSE_FILE_URL="${GITHUB_BASE_URL}/docker/${CONTAINER_NAME}/docker-compose.yaml"
readonly GITHUB_DISCORD_SECRET_URL="${GITHUB_BASE_URL}/secret/.discord_secret"


readonly FIREWALL_CONFIG_FILE_PATH="/etc/nftables.conf"
readonly FIREWALL_BACKUP_FILE_PATH="/etc/nftables.conf.bak"

readonly DOCKER_CONFIG_FILE_PATH="/etc/docker/daemon.json"
readonly DOCKER_BACKUP_FILE_PATH="/etc/docker/daemon.json.bak"

readonly DOCKER_USER="tartarus"
# readonly DOCKER_PROJECT_DIR="/opt/docker/stacks/{project}"
readonly DOCKER_PROJECT_DIR="/tmp/docker/stacks/{project}"
readonly DOCKER_PROJECT_FILE_PATH="${DOCKER_PROJECT_DIR}/docker-compose.yml"

function read_file() {
    local file="$1"

    if test -f "${file}"; then
        cat "${file}"
    fi
}

function encrypt_string() {
    local plain_text="$*"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE}")
    echo -n "${plain_text}" | openssl enc -chacha20 -pbkdf2 -a -e -k "${key}"
}

function decrypt_string() {
    local encrypted_text="$*"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE}")
    echo "${encrypted_text}" | openssl enc -chacha20 -pbkdf2 -a -d -k "${key}"
}

function decrypt_file() {
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

function download_discord_secret() {
    copy_file "${DISCORD_SECRET_FILE}" "${DISCORD_SECRET_FILE}.bak"
    if ! download_file "${GITHUB_DISCORD_SECRET_URL}" "${DISCORD_SECRET_FILE}"; then
        copy_file "${DISCORD_SECRET_FILE}.bak" "${DISCORD_SECRET_FILE}"
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

function backup_docker_compose() {
    local project; project=$(get_project_name)
    local project_dir="${DOCKER_PROJECT_DIR/"{project}"/"${project}"}"
    local project_path="${DOCKER_PROJECT_FILE_PATH/"{project}"/"${project}"}"
    local backup_path="${project_dir}/docker-compose.yml.bak"
    
    copy_file ${project_path} ${backup_path}
}

function restore_docker_compose() {
    local project; project=$(get_project_name)
    local project_dir="${DOCKER_PROJECT_DIR/"{project}"/"${project}"}"
    local project_path="${DOCKER_PROJECT_FILE_PATH/"{project}"/"${project}"}"
    local backup_path="${project_dir}/docker-compose.yml.bak"
    
    copy_file ${backup_path} ${project_path}
}

function download_docker_compose() {
    local project; project=$(get_project_name)
    local project_url="${GITHUB_DOCKER_COMPOSE_FILE_URL}"
    local project_dir="${DOCKER_PROJECT_DIR/"{project}"/"${project}"}"
    local project_path="${DOCKER_PROJECT_FILE_PATH/"{project}"/"${project}"}"

    create_dir "${project_dir}" && download_file "${project_url}" "${project_path}"
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

function init_restic_repository() {
    RESTIC_REPOSITORY="${RESTIC_REPOSITORY_PATH}" RESTIC_PASSWORD="${repository_password}" restic --verbose init
}

function send_discord_notification() {
    local secret; secret="$(decrypt_file ${DISCORD_SECRET_FILE})"
    local discord_url="https://discord.com/api/webhooks/${secret}"
    local content_type="Content-Type: application/json"
    local message="$*"

    if  [ -n "${secret}" ]; then
        curl -H "${content_type}" -X POST -d "{\"content\":\"${message}\"}" "${discord_url}" >/dev/null 2>&1
    fi
}

function init() {
    download_discord_secret
}

function main() {
    send_discord_notification "test notif enc"
 
    return 0
}

init && \
main "$1"