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

readonly LOG_LEVEL="DEBUG"
readonly LOG_FILE="${LOG_DIR}/container_manager_$(date +%Y%m%d).log"

readonly GOTIFY_URL="https://gotify.lab.escapethelan.com/message"
readonly DISCORD_URL="https://discord.com/api/webhooks"

readonly GOTIFY_NOTIFICATION_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.gotify_notification_channel_secret"
readonly GOTIFY_SECRET_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.gotify_secret_channel_secret"
readonly DISCORD_NOTIFICATION_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.discord_notification_channel_secret"
readonly DISCORD_SECRET_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.discord_secret_channel_secret"

readonly GOTIFY_NOTIFICATION_CHANNEL_SECRET="$(read_file "${GOTIFY_NOTIFICATION_CHANNEL_SECRET_FILE}")"
readonly GOTIFY_SECRET_CHANNEL_SECRET="$(read_file "${GOTIFY_SECRET_CHANNEL_SECRET_FILE}")"
readonly DISCORD_NOTIFICATION_CHANNEL_SECRET="$(read_file "${DISCORD_NOTIFICATION_CHANNEL_SECRET_FILE}")"
readonly DISCORD_SECRET_CHANNEL_SECRET="$(read_file "${DISCORD_SECRET_CHANNEL_SECRET_FILE}")"

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


function main() {
    firewall.update
    return 0
}