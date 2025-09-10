#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"
readonly INSTALL_DIR="/root/homelab"
readonly LOG_DIR="${INSTALL_DIR}/log"
readonly TEMP_DIR="${INSTALL_DIR}/temp"
# readonly REPO_DIR="."
readonly REPO_DIR="${INSTALL_DIR}/repo"
readonly SECRET_DIR="${REPO_DIR}/secret"
readonly SCRIPT_DIR="${REPO_DIR}/shell"
readonly SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

readonly GLOBAL_SECRET_DIR="/secrets"
readonly ENCRYPTION_KEY_FILE_PATH="${GLOBAL_SECRET_DIR}/.encryption_key"

readonly LOG_LEVEL="DEBUG"
readonly LOG_FILE="${LOG_DIR}/container_manager_$(date +%Y%m%d).log"

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
# source "${SCRIPT_LIB_DIR}/_gocryptfs_lib.sh"
# shellcheck disable=SC1090
# source "${SCRIPT_LIB_DIR}/_docker_daemon_lib.sh"
# shellcheck disable=SC1090
# source "${SCRIPT_LIB_DIR}/_docker_project_lib.sh"



function main() {
    firewall.update
    # docker.daemon.update
    return 0
}

main