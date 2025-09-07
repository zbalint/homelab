#!/bin/bash

readonly CONFIG_DIR="/root"
readonly BIN_DIR="${CONFIG_DIR}/shell"
readonly SHELL_SCRIPT_PATH="${BIN_DIR}/hlctmgr.sh"

readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/zbalint/homelab/master"
readonly GITHUB_SHELL_SCRIPT_URL="${GITHUB_BASE_URL}/shell/hlctmgr.sh"

function is_dir_exists() {
    local dir="$1"

    test -d "${dir}"
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

function main() {
    init_bin_dir
    if download_from_github "${SHELL_SCRIPT_PATH}" "${GITHUB_SHELL_SCRIPT_URL}"; then
        echo "INFO: Shell script successfully downloaded. Proceeding with the new script."
    else
        echo "ERROR: Failed to download shell script. Running the existing one."
    fi
    bash "${SHELL_SCRIPT_PATH}"
    return 0
}

main