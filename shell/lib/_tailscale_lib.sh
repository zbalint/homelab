#!/bin/bash

readonly TAILSCALE_SECRET_FILE="${REPO_DIR}/secret/.tailscale_secret"

readonly TAILSCALE_CONFIG_DIRECTORY_PATH="${REPO_DIR}/tailscale"
readonly TAILSCALE_CUSTOM_CONFIG_DIRECTORY_PATH="${TAILSCALE_CONFIG_DIRECTORY_PATH}/${PROJECT_NAME}"
readonly TAILSCALE_CUSTOM_BASE_CONFIG_DIRECTORY_PATH="${TAILSCALE_CONFIG_DIRECTORY_PATH}/${PROJECT_BASE_NAME}"

readonly TAILSCALE_CONFIG_FILE_NAME="tailscale_params.txt"

readonly TAILSCALE_LOCAL_CONFIG_DIRECTORY_PATH="${CONFIG_DIR}/tailscale"
readonly TAILSCALE_LOCAL_CONFIG_FILE_PATH="${TAILSCALE_LOCAL_CONFIG_DIRECTORY_PATH}/${TAILSCALE_CONFIG_FILE_NAME}"
readonly TAILSCALE_LOCAL_CONFIG_BACKUP_FILE_PATH="${TAILSCALE_LOCAL_CONFIG_DIRECTORY_PATH}/${TAILSCALE_CONFIG_FILE_NAME}.bak"
readonly TAILSCALE_LOCAL_CONFIG_TEMP_FILE_PATH="${TEMP_DIR}/${TAILSCALE_CONFIG_FILE_NAME}"

readonly TAILSCALE_CONFIG_FILE_PATH="${TAILSCALE_CONFIG_DIRECTORY_PATH}/${TAILSCALE_CONFIG_FILE_NAME}"
readonly TAILSCALE_CUSTOM_CONFIG_FILE_PATH="${TAILSCALE_CUSTOM_CONFIG_DIRECTORY_PATH}/${TAILSCALE_CONFIG_FILE_NAME}"
readonly TAILSCALE_CUSTOM_BASE_CONFIG_FILE_PATH="${TAILSCALE_CUSTOM_BASE_CONFIG_DIRECTORY_PATH}/${TAILSCALE_CONFIG_FILE_NAME}"

readonly MESSAGE_TAILSCALE_CONFIG_UNCHANGED="No changes detected in the tailscale config."
readonly MESSAGE_TAILSCALE_CONFIG_CHANGE_DETECTED="Changes detected in the tailscale config."
readonly MESSAGE_TAILSCALE_UPDATE_SUCCESSFUL="Tailscale config successfully updated!"
readonly MESSAGE_TAILSCALE_UPDATE_FAILED="Failed to update tailscale config, but sucessfully restored!"
readonly MESSAGE_TAILSCALE_RESTORE_FAILED="Failed to restore tailscale config!"
readonly MESSAGE_TAILSCALE_BACKUP_SUCCESSFUL="Tailscale config backup was successful!"
readonly MESSAGE_TAILSCALE_BACKUP_FAILED="Failed to backup tailscale config!"

readonly TAILSCALE_PLAIN_DIRECTORY_PATH="/var/lib/tailscale"
readonly TAILSCALE_CYPHER_DIRECTORY_PATH="/mnt/gocryptfs/cypher/tailscale"
readonly TAILSCALE_RESTORE_DIRECTORY_PATH="/mnt/gocryptfs/plain/tailscale"
readonly TAILSCALE_BACKUP_DIRECTORY_PATH="/backup/${CONTAINER_NAME}/tailscale"

readonly TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_FILE="${TAILSCALE_PLAIN_DIRECTORY_PATH}/.gocryptfs.reverse.conf"
readonly TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE="/tmp/.gocryptfs.reverse.conf"

function tailscale.status() {
    tailscale status >>"${LOG_FILE}" 2>&1
}

function tailscale.is_restore_required() {
    if common.is_dir_exists "${TAILSCALE_BACKUP_DIRECTORY_PATH}" && ! tailscale.status; then
        return 0
    else
        return 1
    fi
}

function tailscale.is_first_run() {
    if ! common.is_dir_exists "${TAILSCALE_BACKUP_DIRECTORY_PATH}" && ! tailscale.status; then
        return 0
    else
        return 1
    fi
}

function tailscale.compare_config() {
    local tailscale_api_key
    local tailscale_params
    local config_file_path

    if common.is_file_exists "${TAILSCALE_CUSTOM_CONFIG_FILE_PATH}"; then
        config_file_path="${TAILSCALE_CUSTOM_CONFIG_FILE_PATH}"
        log.info "Found custom tailscale config at ${config_file_path}"
    elif common.is_file_exists "${TAILSCALE_CUSTOM_BASE_CONFIG_FILE_PATH}"; then
        config_file_path="${TAILSCALE_CUSTOM_BASE_CONFIG_FILE_PATH}"
        log.info "Found custom tailscale config at ${config_file_path}"
    else
        config_file_path="${TAILSCALE_CONFIG_FILE_PATH}"
        log.info "Found default tailscale config at ${config_file_path}"
    fi

    common.copy_file "${config_file_path}" "${TAILSCALE_LOCAL_CONFIG_TEMP_FILE_PATH}"
    common.compare_files "${TAILSCALE_LOCAL_CONFIG_TEMP_FILE_PATH}" "${TAILSCALE_LOCAL_CONFIG_FILE_PATH}"
}

function tailscale.load_config() {
    local tailscale_api_key
    local tailscale_params
    local config_file_path

    if ! common.is_dir_exists "${TAILSCALE_LOCAL_CONFIG_DIRECTORY_PATH}"; then
        common.create_directory "${TAILSCALE_LOCAL_CONFIG_DIRECTORY_PATH}"
    fi

    common.copy_file "${TAILSCALE_LOCAL_CONFIG_FILE_PATH}" "${TAILSCALE_LOCAL_CONFIG_BACKUP_FILE_PATH}"
    common.copy_file "${TAILSCALE_LOCAL_CONFIG_TEMP_FILE_PATH}" "${TAILSCALE_LOCAL_CONFIG_FILE_PATH}"
}

function tailscale.validate_hostname() {
    local current_hostname; current_hostname="$(tailscale status | head -n 1 | awk '{print $2}')"
    local local_hostname="${CONTAINER_NAME}"

    common.is_var_equals "${local_hostname}" "${current_hostname}"
}

function tailscale.set_hostname() {
    if tailscale status >/dev/null 2>&1 && ! tailscale.validate_hostname; then
        log.warn "Tailscale hostname is not the same as the container hostname!"
        local count;count="$(tailscale status | grep -c "${CONTAINER_NAME}")"

        if (( count > 1 )); then
            log.warn "More than one machine has the same name. Please rename or delate them until no name collosion remains."
            notification.warn "More than one machine has the same name. Please rename or delate them until no name collosion remains."
        else
            log.info "Setting machine name to ${CONTAINER_NAME}"
            tailscale set --hostname="${PROJECT_BASE_NAME}-temp" && \
            sleep 5 && \
            tailscale set --hostname="${CONTAINER_NAME}"

            if ! tailscale.validate_hostname; then
                log.error "Failed to set hostname."
            fi
        fi
    fi
}

function tailscale.login() {
    local tailscale_api_key
    local tailscale_params
    local config_file_path

    tailscale_params="$(common.read_file "${TAILSCALE_LOCAL_CONFIG_FILE_PATH}")"
    tailscale_api_key="$(common.read_file "${TAILSCALE_SECRET_FILE}")"

    # shellcheck disable=SC2086
    tailscale up --reset --hostname="${CONTAINER_NAME}" ${tailscale_params} --auth-key=${tailscale_api_key} >>"${LOG_FILE}" 2>&1
    tailscale.set_hostname    
}

function tailscale.stop() {
    log.debug "Stopping tailscale... (delay 5sec)"

    tailscale down >>"${LOG_FILE}" 2>&1 && \
    systemctl stop tailscaled >>"${LOG_FILE}" 2>&1 && \
    sleep 5
}

function tailscale.start() {
    log.debug "Starting tailscale... (delay 5sec)"

    systemctl start tailscaled >>"${LOG_FILE}" 2>&1 && \
    tailscale up >>"${LOG_FILE}" 2>&1 && \
    sleep 5
}

function tailscale.reload() {
    log.debug "Restarting tailscale..."

    tailscale.stop && tailscale.start
}

function tailscale.backup() {
    if gocryptfs.init_reverse_volume "${TAILSCALE_PLAIN_DIRECTORY_PATH}"; then
        if ! common.is_dir_exists "${TAILSCALE_CYPHER_DIRECTORY_PATH}" && common.create_directory "${TAILSCALE_CYPHER_DIRECTORY_PATH}"; then
            log.debug "Creating directory for gocryptfs cipher volume at ${TAILSCALE_CYPHER_DIRECTORY_PATH}"
        fi

        if gocryptfs.mount_reverse_volume "${TAILSCALE_PLAIN_DIRECTORY_PATH}" "${TAILSCALE_CYPHER_DIRECTORY_PATH}"; then
            if ! common.is_dir_exists "${TAILSCALE_BACKUP_DIRECTORY_PATH}" && common.create_directory "${TAILSCALE_BACKUP_DIRECTORY_PATH}"; then
                log.debug "Creating backup directory at ${TAILSCALE_BACKUP_DIRECTORY_PATH}"
            fi
            
            if common.copy_directory "${TAILSCALE_CYPHER_DIRECTORY_PATH}" "${TAILSCALE_BACKUP_DIRECTORY_PATH}"; then
                gocryptfs.unmount "${TAILSCALE_CYPHER_DIRECTORY_PATH}"
                return 0
            else
                gocryptfs.unmount "${TAILSCALE_CYPHER_DIRECTORY_PATH}"
                return 1
            fi
        else
            log.error "Failed to mount reverse gocryptfs volume at ${TAILSCALE_PLAIN_DIRECTORY_PATH}"
            return 1
        fi
    else
        log.error "Failed to initialize reverse gocryptfs volume at ${TAILSCALE_PLAIN_DIRECTORY_PATH}"
        return 1
    fi
}

function tailscale.restore() {
    if ! common.is_dir_exists "${TAILSCALE_BACKUP_DIRECTORY_PATH}"; then
        log.debug "Backup directory does not exists at ${TAILSCALE_CYPHER_DIRECTORY_PATH}"
        return 1
    fi

    if ! common.is_dir_exists "${TAILSCALE_RESTORE_DIRECTORY_PATH}" && common.create_directory "${TAILSCALE_RESTORE_DIRECTORY_PATH}"; then
        log.debug "Creating directory for gocryptfs plain volume at ${TAILSCALE_RESTORE_DIRECTORY_PATH}"
    fi

    if gocryptfs.mount_normal_volume "${TAILSCALE_RESTORE_DIRECTORY_PATH}" "${TAILSCALE_BACKUP_DIRECTORY_PATH}"; then
        if ! common.is_dir_exists "${TAILSCALE_PLAIN_DIRECTORY_PATH}"; then
            log.warn "Tailscale config directory does not exists at ${TAILSCALE_PLAIN_DIRECTORY_PATH}"
        fi
        
        if common.is_file_exists "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_FILE}"; then
            common.copy_file "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_FILE}" "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}"
        fi

        if common.copy_directory "${TAILSCALE_RESTORE_DIRECTORY_PATH}" "${TAILSCALE_PLAIN_DIRECTORY_PATH}"; then
            if common.is_file_exists "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}"; then
                common.copy_file "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}" "${TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_FILE}"
            fi
            gocryptfs.unmount "${TAILSCALE_RESTORE_DIRECTORY_PATH}"
            common.copy_file "${TAILSCALE_LOCAL_CONFIG_BACKUP_FILE_PATH}" "${TAILSCALE_LOCAL_CONFIG_FILE_PATH}"
            return 0
        else
            gocryptfs.unmount "${TAILSCALE_RESTORE_DIRECTORY_PATH}"
            return 1
        fi
    else
        log.error "Failed to mount gocryptfs volume at ${TAILSCALE_RESTORE_DIRECTORY_PATH}"
        return 1
    fi
}

function tailscale.update() {
    if tailscale.is_first_run; then
        log.info "First run. Run tailscale login and waiting for device approval..."
        if tailscale.login; then
            log.info "Tailscale login was successful."
        else
            log.error "Tailscale login failed!"
        fi
    fi

    if tailscale.is_restore_required; then
        log.info "This is the first run. Restoring backup before proceeding."
        if tailscale.stop && tailscale.restore && tailscale.start; then
            log.warn "${MESSAGE_TAILSCALE_RESTORE_SUCCESSFUL}"
        else
            log.error "${MESSAGE_TAILSCALE_RESTORE_FAILED}"
        fi
    fi

    if tailscale.compare_config; then
        log.info "${MESSAGE_TAILSCALE_CONFIG_UNCHANGED}"
        tailscale.set_hostname
    else
        log.info "${MESSAGE_TAILSCALE_CONFIG_CHANGE_DETECTED}"
        if tailscale.stop && tailscale.backup && tailscale.start; then
            log.info "${MESSAGE_TAILSCALE_BACKUP_SUCCESSFUL}"
            if tailscale.load_config && tailscale.login && tailscale.status; then
                log.info "${MESSAGE_TAILSCALE_UPDATE_SUCCESSFUL}"
                notification.info "Tailscale" "${MESSAGE_TAILSCALE_UPDATE_SUCCESSFUL}"
            elif tailscale.stop && tailscale.restore && tailscale.start && tailscale.login; then
                log.warn "${MESSAGE_TAILSCALE_UPDATE_FAILED}"
                notification.warn "Tailscale" "${MESSAGE_TAILSCALE_UPDATE_FAILED}"
            else
                log.error "${MESSAGE_TAILSCALE_RESTORE_FAILED}"
                notification.error "Tailscale" "${MESSAGE_TAILSCALE_RESTORE_FAILED}"
            fi
        else
            log.error "${MESSAGE_TAILSCALE_BACKUP_FAILED}"
            notification.error "Tailscale" "${MESSAGE_TAILSCALE_BACKUP_FAILED}"
        fi
    fi
}
