#!/bin/bash

readonly CONTAINER_NAME="$(hostname)"
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
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_network_lib.sh"
# shellcheck disable=SC1090
source "${SCRIPT_LIB_DIR}/_notification_lib.sh"


log.info "$(random.get_string)"


GOTIFY_NOTIFICATION_CHANNEL_SECRET="AodSQfS7okC5t_c"
GOTIFY_URL="https://gotify.lab.escapethelan.com/message"

# notification.send_to_gotify_notification_channel "test title" "test message" 5

DISCORD_NOTIFICATION_CHANNEL_SECRET="1412830338153185443/NGbCm76LQn4VRJDevc5-Q_2VImpqk19OmNeXMmqfNOiJQSldjpll7P6wJnD1wYIWfo61"
DISCORD_URL="https://discord.com/api/webhooks"

# notification.send_to_discord_notification_channel "test title" "test message"

notification.info "test title" "test message"