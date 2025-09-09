#!/bin/bash

# readonly INSTALL_DIR="."
readonly INSTALL_DIR="/root/homelab"
readonly LOG_DIR="${INSTALL_DIR}/log"
readonly REPO_DIR="."
# readonly REPO_DIR="${INSTALL_DIR}/repo"
readonly SECRET_DIR="${REPO_DIR}/secret"
readonly SCRIPT_DIR="${REPO_DIR}/shell"
readonly SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

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

log.info "$(random.get_string)"