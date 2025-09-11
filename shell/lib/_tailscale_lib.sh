#!/bin/bash

readonly MESSAGE_TAILSCALE_RESTORE_SUCCESSFUL="Tailscale successfully restored!"
readonly MESSAGE_TAILSCALE_RESTORE_FAILED="Failed to restore tailscale!"
readonly MESSAGE_TAILSCALE_BACKUP_SUCCESSFUL="Tailscale backup was successful!"
readonly MESSAGE_TAILSCALE_BACKUP_FAILED="Failed to backup tailscale!"

readonly TAILSCALE_PLAIN_DIRECTORY_PATH="/var/lib/tailscale"
readonly TAILSCALE_CYPHER_DIRECTORY_PATH="/mnt/gocryptfs/cypher/tailscale"
readonly TAILSCALE_RESTORE_DIRECTORY_PATH="/mnt/gocryptfs/plain/tailscale"
readonly TAILSCALE_BACKUP_DIRECTORY_PATH="/backup/${CONTAINER_NAME}/tailscale"

readonly TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_FILE="${TAILSCALE_PLAIN_DIRECTORY_PATH}/.gocryptfs.reverse.conf"
readonly TAILSCALE_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE="/tmp/.gocryptfs.reverse.conf"

function tailscale.status() {
    tailscale status >/dev/null 2>&1
}

function tailscale.is_first_run() {
    if common.is_dir_exists "${TAILSCALE_BACKUP_DIRECTORY_PATH}" && ! tailscale.status; then
        return 0
    else
        return 1
    fi
}

function tailscale.stop() {
    log.debug "Stopping tailscale... (delay 5sec)"

    tailscale down >/dev/null 2>&1 && \
    systemctl stop tailscaled >/dev/null 2>&1 && \
    sleep 5
}

function tailscale.start() {
    log.debug "Starting tailscale... (delay 5sec)"

    systemctl start tailscaled >/dev/null 2>&1 && \
    tailscale up >/dev/null 2>&1 && \
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
        log.info "This is the first run. Restoring backup before proceeding."
        if tailscale.stop && tailscale.restore && tailscale.start; then
            log.warn "${MESSAGE_TAILSCALE_RESTORE_SUCCESSFUL}"
        else
            log.error "${MESSAGE_TAILSCALE_RESTORE_FAILED}"
        fi
    else
        if tailscale.status; then
            if tailscale.stop && tailscale.backup && tailscale.start; then
                log.info "${MESSAGE_TAILSCALE_BACKUP_SUCCESSFUL}"
            else
                log.error "${MESSAGE_TAILSCALE_BACKUP_FAILED}"
                notification.error "Tailscale" "${MESSAGE_TAILSCALE_BACKUP_FAILED}"
            fi
        else
            log.warn "Postponing backup until tailscale already logged in."
        fi
    fi
}
