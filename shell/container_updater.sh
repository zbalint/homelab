#!/bin/bash

readonly HOMELAB_GIT_REPOSITORY_URL="https://github.com/zbalint/homelab.git"
readonly GOCRYPTFS_VERSION="2.6.1"
readonly GOCRYPTFS_ARCHIVE_URL="https://github.com/rfjakob/gocryptfs/releases/download/v${GOCRYPTFS_VERSION}/gocryptfs_v${GOCRYPTFS_VERSION}_linux-static_amd64.tar.gz"

readonly INSTALL_DIR="/root/homelab"
readonly BIN_DIR="${INSTALL_DIR}/bin"
readonly REPO_DIR="${INSTALL_DIR}/repo"
readonly SECRET_DIR="${REPO_DIR}/secret"
readonly SCRIPT_DIR="${REPO_DIR}/shell"
readonly SERVICE_DIR="${REPO_DIR}/systemd"

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

function create_dir() {
    local dir="$1"

    mkdir -p "${dir}" >/dev/null 2>&1
}

function compare_files() {
    local file_1="$1"
    local file_2="$2"

    diff "${file_1}" "${file_2}" >/dev/null 2>&1
}

function copy_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/cp -rf "${src_file}" "${dst_file}" >/dev/null 2>&1
}

function git_clone() {
    local repository_url="$1"
    local directory="$2"

    git clone --quiet --single-branch --depth 1 "${repository_url}" "${directory}"
}

function git_pull() {
    local repository_dir="$1"

    cd "${repository_dir}" && git fetch --quiet && git reset --quiet --hard origin/master
}

function install_gocryptfs() {
    if ! gocryptfs -version >/dev/null 2>&1; then
        local archive_path="/tmp/gocryptfs.tar.gz"
        local extract_path="/tmp/gocryptfs"
        if wget -q "${GOCRYPTFS_ARCHIVE_URL}" -O "${archive_path}" && test -f "${archive_path}"; then
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

function init_homelab_directory() {
    local directory="$1"

    if ! is_dir_exists "${directory}"; then
        if create_dir "${directory}"; then
            echo "INFO: Creating new directory at ${directory}."
        else
            echo "ERROR: Failed to create new directory at ${directory}."
        fi
    fi
}

function init_homelab_directories() {
    init_homelab_directory "${INSTALL_DIR}"
    init_homelab_directory "${BIN_DIR}"
}

function update_homelab_repo() {
    if is_dir_exists "${REPO_DIR}"; then
        echo "INFO: Updating homelab repository..."
        if git_pull "${REPO_DIR}"; then
            echo "INFO: Repository update was successful."
            return 0
        else
            echo "ERROR: Repository updated failed!"
            return 1
        fi
    else
        echo "INFO: Cloning homelab repository..."
        if git_clone "${HOMELAB_GIT_REPOSITORY_URL}" "${REPO_DIR}"; then
            echo "INFO: Repository clone was successful."
            /bin/cp -rf "${REPO_DIR}/shell/container_updater.sh" "${BIN_DIR}/container_updater.sh"
            return 0
        else
            echo "ERROR: Repository clone failed!"
            return 1
        fi
    fi
}

function install_systemd_service_and_timer() {
    if ! test -f /etc/systemd/system/container-updater.service; then
        echo "INFO: Installing systemd service..."
        cp "${SERVICE_DIR}/container-updater.service" /etc/systemd/system/
    fi

    if ! test -f /etc/systemd/system/container-updater.timer; then
        echo "INFO: Installing systemd timer..."
        cp "${SERVICE_DIR}/container-updater.timer" /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable --now "container-updater.timer"
    fi
}

function decrypt_secrets() {
    cd "${REPO_DIR}" && bash decrypt_files.sh
}

function main() {
    local command="$1"
    install_gocryptfs
    init_homelab_directories
    update_homelab_repo
    decrypt_secrets

    if [ "${command}" == "install" ]; then
        install_systemd_service_and_timer
    else
        bash "${SCRIPT_DIR}/container_manager.sh"
    fi
}

main "$1"