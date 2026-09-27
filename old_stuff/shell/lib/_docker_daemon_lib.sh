#!/bin/bash

readonly DOCKER_DAEMON_CONFIG_DIRECTORY_PATH="${REPO_DIR}/docker/daemon"
readonly DOCKER_DAEMON_CUSTOM_CONFIG_DIRECTORY_PATH="${DOCKER_DAEMON_CONFIG_DIRECTORY_PATH}/${PROJECT_NAME}"
readonly DOCKER_DAEMON_CUSTOM_BASE_CONFIG_DIRECTORY_PATH="${DOCKER_DAEMON_CONFIG_DIRECTORY_PATH}/${PROJECT_BASE_NAME}"
readonly DOCKER_DAEMON_CONFIG_FILE_NAME="daemon.json"

readonly DOCKER_DAEMON_CONFIG_FILE_PATH="${DOCKER_DAEMON_CONFIG_DIRECTORY_PATH}/${DOCKER_DAEMON_CONFIG_FILE_NAME}"
readonly DOCKER_DAEMON_CUSTOM_CONFIG_FILE_PATH="${DOCKER_DAEMON_CUSTOM_CONFIG_DIRECTORY_PATH}/${DOCKER_DAEMON_CONFIG_FILE_NAME}"
readonly DOCKER_DAEMON_CUSTOM_BASE_CONFIG_FILE_PATH="${DOCKER_DAEMON_CUSTOM_BASE_CONFIG_DIRECTORY_PATH}/${DOCKER_DAEMON_CONFIG_FILE_NAME}"

readonly DOCKER_DAEMON_CONFIG_PROD_FILE_PATH="/etc/docker/daemon.json"
readonly DOCKER_DAEMON_CONFIG_BACKUP_FILE_PATH="/etc/docker/daemon.json.bak"


readonly MESSAGE_DOCKER_DAEMON_CONFIG_UNCHANGED="No changes detected in the docker daemon config."
readonly MESSAGE_DOCKER_DAEMON_CONFIG_CHANGE_DETECTED="Changes detected in the docker daemon config."
readonly MESSAGE_DOCKER_DAEMON_UPDATE_SUCCESSFUL="Docker daemon config successfully updated!"
readonly MESSAGE_DOCKER_DAEMON_UPDATE_FAILED="Failed to update docker daemon config, but sucessfully restored!"
readonly MESSAGE_DOCKER_DAEMON_RESTORE_FAILED="Failed to restore docker daemon config!"
readonly MESSAGE_DOCKER_DAEMON_BACKUP_SUCCESSFUL="Docker daemon config backup was successful!"
readonly MESSAGE_DOCKER_DAEMON_BACKUP_FAILED="Failed to backup docker daemon config!"


function docker.daemon.stop() {
    systemctl stop docker.socket && systemctl stop docker.service && systemctl stop containerd.service
}

function docker.daemon.start() {
    systemctl start containerd.service && systemctl start docker.service && systemctl start docker.socket
}

function docker.daemon.reload() {
    docker.daemon.stop && sleep 5 && docker.daemon.start && sleep 5
}

function docker.daemon.backup() {
    common.copy_file "${DOCKER_DAEMON_CONFIG_PROD_FILE_PATH}" "${DOCKER_DAEMON_CONFIG_BACKUP_FILE_PATH}"
}

function docker.daemon.restore() {
    common.copy_file "${DOCKER_DAEMON_CONFIG_BACKUP_FILE_PATH}" "${DOCKER_DAEMON_CONFIG_PROD_FILE_PATH}"
}

function docker.daemon.load_config() {
    local config_file="$1"

    common.copy_file "${config_file}" "${DOCKER_DAEMON_CONFIG_PROD_FILE_PATH}"
}

function docker.daemon.update() {
    local docker_daemon_new_config_path
    local docker_daemon_old_config_path; docker_daemon_old_config_path="${DOCKER_DAEMON_CONFIG_PROD_FILE_PATH}"

    if common.is_file_exists "${DOCKER_DAEMON_CUSTOM_CONFIG_FILE_PATH}"; then
        docker_daemon_new_config_path="${DOCKER_DAEMON_CUSTOM_CONFIG_FILE_PATH}"
        log.info "Found custom docker daemon config at ${docker_daemon_new_config_path}"
    elif common.is_file_exists "${DOCKER_DAEMON_CUSTOM_BASE_CONFIG_FILE_PATH}"; then
        docker_daemon_new_config_path="${DOCKER_DAEMON_CUSTOM_BASE_CONFIG_FILE_PATH}"
        log.info "Found custom docker daemon config at ${docker_daemon_new_config_path}"
    else
        docker_daemon_new_config_path="${DOCKER_DAEMON_CONFIG_FILE_PATH}"
        log.info "Found default docker daemon config at ${docker_daemon_new_config_path}"
    fi

    if common.compare_files "${docker_daemon_new_config_path}" "${docker_daemon_old_config_path}"; then
        log.info "${MESSAGE_DOCKER_DAEMON_CONFIG_UNCHANGED}"
    else
        log.info "${MESSAGE_DOCKER_DAEMON_CONFIG_CHANGE_DETECTED}"
        if docker.daemon.backup; then
            log.info "${MESSAGE_DOCKER_DAEMON_BACKUP_SUCCESSFUL}"
            if docker.daemon.load_config "${docker_daemon_new_config_path}" && docker.daemon.reload; then
                log.info "${MESSAGE_DOCKER_DAEMON_UPDATE_SUCCESSFUL}"
                notification.info "Docker daemon" "${MESSAGE_DOCKER_DAEMON_UPDATE_SUCCESSFUL}"
            elif docker.daemon.restore && docker.daemon.reload; then
                log.warn "${MESSAGE_DOCKER_DAEMON_UPDATE_FAILED}"
                notification.warn "Docker daemon" "${MESSAGE_DOCKER_DAEMON_UPDATE_FAILED}"
            else
                log.error "${MESSAGE_DOCKER_DAEMON_RESTORE_FAILED}"
                notification.error "Docker daemon" "${MESSAGE_DOCKER_DAEMON_RESTORE_FAILED}"
            fi
        else
            log.error "${MESSAGE_DOCKER_DAEMON_BACKUP_FAILED}"
            notification.error "Docker daemon" "${MESSAGE_DOCKER_DAEMON_BACKUP_FAILED}"
        fi
    fi
}