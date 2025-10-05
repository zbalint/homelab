#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"
readonly CONTAINER_BASE_NAME="${CONTAINER_NAME%-0*}"
readonly PROJECT_NAME="${CONTAINER_NAME}"
readonly PROJECT_BASE_NAME="${PROJECT_NAME%-0*}"

readonly INSTALL_DIR="/root/homelab"
readonly LOG_DIR="${INSTALL_DIR}/log"
readonly TEMP_DIR="${INSTALL_DIR}/temp"
readonly REPO_DIR="${INSTALL_DIR}/repo"
readonly CONFIG_DIR="${INSTALL_DIR}/config"
readonly SECRET_DIR="${REPO_DIR}/secret"
readonly SCRIPT_DIR="${REPO_DIR}/shell"
readonly SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

readonly GLOBAL_BACKUP_DIR="/backup"
readonly GLOBAL_SECRET_DIR="/secret"
readonly LOCAL_SECRET_DIR="${INSTALL_DIR}/secret"
readonly ENCRYPTION_KEY_FILE_PATH="${GLOBAL_SECRET_DIR}/.encryption_key"

readonly LOG_LEVEL="DEBUG"
readonly LOG_FILE="${LOG_DIR}/container_manager_$(date +%Y%m%d).log"

mkdir -p "${INSTALL_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${TEMP_DIR}"
mkdir -p "${REPO_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${LOCAL_SECRET_DIR}"

# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_log_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_common_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_random_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_encryption_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_network_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_notification_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_firewall_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_gocryptfs_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_docker_daemon_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_docker_project_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_tailscale_lib.sh"

function init() {
    if ! common.is_file_exists "${GOCRYPTFS_SECRET_FILE_PATH}" && common.is_dir_exists "${GLOBAL_BACKUP_DIR}/${CONTAINER_NAME}"; then
        log.warn "Container Manager" "Gocryptfs secret ${GOCRYPTFS_SECRET_FILE_PATH} is missing but backup exists at ${GLOBAL_BACKUP_DIR}/${CONTAINER_NAME}. Skipping update until secret is provided or backup is deleted."
        notification.warn "Container Manager" "Gocryptfs secret ${GOCRYPTFS_SECRET_FILE_PATH} is missing but backup exists at ${GLOBAL_BACKUP_DIR}/${CONTAINER_NAME}. Skipping update until secret is provided or backup is deleted."
        return 1
    fi

    local wait_time_in_sec=$(( RANDOM % 901 ))
    local wait_time_in_min=$(( wait_time_in_sec / 60 ))

    log.info "Waiting ${wait_time_in_sec}s ~ ${wait_time_in_min}m before updating the system to avoid load spike on host..."
    sleep ${wait_time_in_sec}

    return 0
}

function main() {
    firewall.update
    tailscale.update
    docker.daemon.update
    docker.project.update
    return 0
}

init && main
cp ${SCRIPT_DIR}/container_updater.sh ${INSTALL_DIR}/bin/container_updater.sh