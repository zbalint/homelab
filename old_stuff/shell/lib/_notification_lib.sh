#!/bin/bash

readonly GOTIFY_URL="https://gotify.lab.escapethelan.com/message"
readonly DISCORD_URL="https://discord.com/api/webhooks"

readonly GOTIFY_NOTIFICATION_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.gotify_notification_channel_secret"
readonly GOTIFY_SECRET_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.gotify_secret_channel_secret"
readonly DISCORD_NOTIFICATION_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.discord_notification_channel_secret"
readonly DISCORD_SECRET_CHANNEL_SECRET_FILE="${REPO_DIR}/secret/.discord_secret_channel_secret"

readonly GOTIFY_NOTIFICATION_CHANNEL_SECRET="$(cat "${GOTIFY_NOTIFICATION_CHANNEL_SECRET_FILE}")"
readonly GOTIFY_SECRET_CHANNEL_SECRET="$(cat "${GOTIFY_SECRET_CHANNEL_SECRET_FILE}")"
readonly DISCORD_NOTIFICATION_CHANNEL_SECRET="$(cat "${DISCORD_NOTIFICATION_CHANNEL_SECRET_FILE}")"
readonly DISCORD_SECRET_CHANNEL_SECRET="$(cat "${DISCORD_SECRET_CHANNEL_SECRET_FILE}")"

declare GOTIFY_IS_AVAILABLE="false"

function notification.send_to_gotify() {
    local url="$1"
    local secret="$2"
    local title="$3"
    local message="$4"
    local priority="$5"
    local container="${CONTAINER_NAME}"

    if common.is_var_empty "${url}" || common.is_var_empty "${secret}"; then
        return 1
    fi

    if common.is_var_empty "${priority}"; then
        priority=5
    fi

    if ! curl --insecure -m 6 --retry 3 "${url}?token=${secret}" -F "title=${container}: ${title}" -F "message=${message}" -F "priority=${priority}" >>"${LOG_FILE}" 2>&1; then
        log.error "Failed to send notification to Gotify server!"
    fi
}

function notification.send_to_gotify_notification_channel() {
    local secret="${GOTIFY_NOTIFICATION_CHANNEL_SECRET}"
    local url="${GOTIFY_URL}"
    local title="$1"
    local message="$2"
    local priority="$3"

    notification.send_to_gotify "${url}" "${secret}" "${title}" "${message}" "${priority}"
}

function notification.send_to_gotify_secret_channel() {
    local secret="${GOTIFY_SECRET_CHANNEL_SECRET}"
    local url="${GOTIFY_URL}"
    local title="$1"
    local message="$2"
    local priority="$3"

    notification.send_to_gotify "${url}" "${secret}" "${title}" "${message}" "${priority}"
}

function notification.send_to_discord() {
    local url="$1"
    local secret="$2"
    local title="$3"
    local message="$4"
    local container="${CONTAINER_NAME}"
    local content_type; content_type="Content-Type: application/json"

    if common.is_var_empty "${secret}" && common.is_var_empty "${url}"; then
        return 1
    fi

    if ! curl -m 6 --retry 3 -H "${content_type}" -X POST -d "{\"content\":\"container: ${container}\ntitle: ${title}\nmessage: ${message}\"}" "${url}/${secret}" >>"${LOG_FILE}" 2>&1; then
        log.error "Failed to send notification to Discord server!"
    fi
}

function notification.send_to_discord_notification_channel() {
    local secret="${DISCORD_NOTIFICATION_CHANNEL_SECRET}"
    local url="${DISCORD_URL}"
    local title="$1"
    local message="$2"
    

    notification.send_to_discord "${url}" "${secret}" "${title}" "${message}"
}

function notification.send_to_discord_secret_channel() {
    local secret="${DISCORD_SECRET_CHANNEL_SECRET}"
    local url="${DISCORD_URL}"
    local title="$1"
    local message="$2"

    notification.send_to_discord "${url}" "${secret}" "${title}" "${message}"
}


function notification.send() {
    local level="$1"
    local title="$2"
    local message="$3"
    local priority="$4"

    if common.is_var_equals "${GOTIFY_IS_AVAILABLE}" "false" && tailscale status >/dev/null 2>&1; then
        GOTIFY_IS_AVAILABLE="true"
    fi
    
    if common.is_var_equals "${level}" "SECRET"; then
        if common.is_var_equals "${GOTIFY_IS_AVAILABLE}" "true"; then
            notification.send_to_gotify_secret_channel "${title}" "${message}" "${priority}"
        fi
        notification.send_to_discord_secret_channel "${title}" "${message}"
    else
        if common.is_var_equals "${GOTIFY_IS_AVAILABLE}" "true"; then
            notification.send_to_gotify_notification_channel "${title}" "${message}" "${priority}"
        fi
        notification.send_to_discord_notification_channel "${title}" "${message}"
    fi
}

function notification.info() {
    local title="$1"
    local message="$2"

    notification.send "INFO" "${title}" "${message}" "1"
}

function notification.warn() {
    local title="$1"
    local message="$2"

    notification.send "WARN" "${title}" "${message}" "5"
}

function notification.error() {
    local title="$1"
    local message="$2"

    notification.send "ERROR" "${title}" "${message}" "10"
}

function notification.secret() {
    local title="$1"
    local message="$2"

    notification.send "SECRET" "${title}" "${message}" "10"
}

