#!/bin/bash

readonly CONFIG_DIR="/root"
readonly BIN_DIR="${CONFIG_DIR}/shell"
readonly SERVICE_DIR="${CONFIG_DIR}/service"
readonly SHELL_SCRIPT_PATH="${BIN_DIR}/hlctmgr.sh"
readonly SERVICE_PATH="${SERVICE_DIR}/container-updater.service"
readonly TIMER_PATH="${SERVICE_DIR}/container-updater.timer"

readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/zbalint/homelab/master"
readonly GITHUB_SHELL_SCRIPT_URL="${GITHUB_BASE_URL}/shell/hlctmgr.sh"
readonly GITHUB_SHELL_SERVICE_URL="${GITHUB_BASE_URL}/systemd/container-updater.service"
readonly GITHUB_SHELL_TIMER_URL="${GITHUB_BASE_URL}/systemd/container-updater.timer"

function is_var_equals() {
    local var="$1"
    local str="$2"

    if [ "${var}" == "${str}" ]; then
        return 0
    else
        return 1
    fi
}

function is_dir_exists() {
    local dir="$1"

    test -d "${dir}"
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

function init_bin_dir() {
    if ! is_dir_exists "${BIN_DIR}"; then
        mkdir -p "${BIN_DIR}" &&  chmod 700 "${BIN_DIR}"
    fi
}

function init_service_dir() {
    if ! is_dir_exists "${SERVICE_DIR}"; then
        mkdir -p "${SERVICE_DIR}" &&  chmod 700 "${SERVICE_DIR}"
    fi
}

function download_hl_manager_service_and_timer() {
    if download_from_github "${SERVICE_PATH}" "${GITHUB_SHELL_SERVICE_URL}"; then
        echo "INFO: Service successfully downloaded."
    else
        echo "ERROR: Failed to download service."
        return 1
    fi

    if download_from_github "${TIMER_PATH}" "${GITHUB_SHELL_TIMER_URL}"; then
        echo "INFO: Timer successfully downloaded."
    else
        echo "ERROR: Failed to download timer."
        return 1
    fi

    return 0
}

function download_hl_manager_script() {
    if download_from_github "${SHELL_SCRIPT_PATH}" "${GITHUB_SHELL_SCRIPT_URL}"; then
        if compare_files "${SHELL_SCRIPT_PATH}" "${SHELL_SCRIPT_PATH}.bak"; then
            echo "INFO: Shell script successfully downloaded, but no new changes detected. Proceeding with the new script."
        else
            echo "INFO: Shell script successfully downloaded and new changes detected. Proceeding with the new script."
        fi
    else
        echo "ERROR: Failed to download shell script. Running the existing one."
    fi
}

function install_systemd_service_and_timer() {
    local changes_detected="false"

    if compare_files "${SERVICE_PATH}" "${SERVICE_PATH}.bak"; then
        echo "INFO: The downloaded service does not contains new changes. Skipping install."
    else
        changes_detected="true"
        echo "INFO: The downloaded service contains new changes. Proceeding with install."
        cp "${SERVICE_PATH}" /etc/systemd/system/
    fi

    if compare_files "${TIMER_PATH}" "${TIMER_PATH}.bak"; then
        echo "INFO: The downloaded timer does not contains new changes. Skipping install."
    else
        changes_detected="true"
        echo "INFO: The downloaded timer contains new changes. Proceeding with install."
        cp "${TIMER_PATH}" /etc/systemd/system/
    fi
    
    if is_var_equals "${changes_detected}" "false"; then
        return 1
    fi

    systemctl daemon-reload
}

function main() {
    init_bin_dir
    init_service_dir
    
    download_hl_manager_script
    bash "${SHELL_SCRIPT_PATH}"
    return 0
}

main