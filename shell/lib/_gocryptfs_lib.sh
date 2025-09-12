#!/bin/bash

readonly GOCRYPTFS_PASSWORD_LENGTH=64
readonly GOCRYPTFS_SECRET_FILE_PATH="${LOCAL_SECRET_DIR}/.gocryptfs_secret.enc"
declare GOCRYPTFS_SECRET

function gocryptfs._load_secret() {
    local secret_file_path="${GOCRYPTFS_SECRET_FILE_PATH}"

    if common.is_file_exists "${secret_file_path}"; then
        local encrypted_password; encrypted_password="$(common.read_file "${secret_file_path}")"
        local password; password="$(encryption.decrypt_string "${encrypted_password}")"
        
        GOCRYPTFS_SECRET="${password}"
    else
        if ! common.is_dir_exists "${LOCAL_SECRET_DIR}"; then
            common.create_directory "${LOCAL_SECRET_DIR}"
        fi

        password="$(random.get_string ${GOCRYPTFS_PASSWORD_LENGTH})"
        encrypted_password="$(encryption.encrypt_string "${password}")"

        common.write_file "${GOCRYPTFS_SECRET_FILE_PATH}" "${encrypted_password}"
        
        GOCRYPTFS_SECRET="${password}"

        notification.secret "Gocryptfs secret" "${encrypted_password}"
    fi
}

function gocryptfs._is_dir_mounted() {
    local directory="$1"

    if mountpoint -q "${directory}"; then
        return 0
    fi

    return 1
}

function gocryptfs.init_normal_volume() {
    local cipher_directory="$1"

    gocryptfs._load_secret

    if test -f "${cipher_directory}/.gocryptfs.conf"; then
        # log.into "Gocryptfs normal volume found at ${cipher_directory}"
        log.debug "Gocryptfs normal volume found at ${cipher_directory}"
        return 0
    fi

    if echo "${GOCRYPTFS_SECRET}" | gocryptfs -init "${cipher_directory}" >>"${LOG_FILE}" 2>&1; then
        # log.info "Gocryptfs normal volume initialized at ${cipher_directory}"
        log.debug "Gocryptfs normal volume initialized at ${cipher_directory}"
        return 0
    else
        # log.error "Could not initialize gocryptfs normal volume at ${cipher_directory}!"
        log.debug "Could not initialize gocryptfs normal volume at ${cipher_directory}!"
        return 1
    fi
}

function gocryptfs.init_reverse_volume() {
    local plain_directory="$1"

    gocryptfs._load_secret

    if test -f "${plain_directory}/.gocryptfs.reverse.conf"; then
        # log.info "Gocryptfs reverse volume found at ${plain_directory}"
        log.debug "Gocryptfs reverse volume found at ${plain_directory}"
        return 0
    fi

    if echo "${GOCRYPTFS_SECRET}" | gocryptfs -init -reverse "${plain_directory}" >>"${LOG_FILE}" 2>&1; then
        # log.info "Gocryptfs reverse volume initialized at ${plain_directory}"
        log.debug "Gocryptfs reverse volume initialized at ${plain_directory}"
        return 0
    else
        # log.error "Could not initialize gocryptfs reverse volume at ${plain_directory}!"
        log.debug "Could not initialize gocryptfs reverse volume at ${plain_directory}!"
        return 1
    fi
}

function gocryptfs.mount_normal_volume() {
    local plain_directory="$1"
    local chiper_directory="$2"

    gocryptfs._load_secret

    if gocryptfs._is_dir_mounted "${plain_directory}"; then
        # log.warn "Gocrypfs plain directory already mounted at ${plain_directory}"
        log.debug "Gocrypfs plain directory already mounted at ${plain_directory}"
        return 0
    else
        echo "${GOCRYPTFS_SECRET}" | gocryptfs "${chiper_directory}" "${plain_directory}" >>"${LOG_FILE}" 2>&1
        # shellcheck disable=SC2181
        if (( $? == 0 )); then
            # log.info "Gocrypfs cipher directory ${chiper_directory} mounted as plain directory at ${plain_directory}"
            log.debug "Gocrypfs cipher directory ${chiper_directory} mounted as plain directory at ${plain_directory}"
            return 0
        else
            # log.error "Failed to mount gocrypfs cipher directory ${chiper_directory} as plain directory at ${plain_directory}"
            log.debug "Failed to mount gocrypfs cipher directory ${chiper_directory} as plain directory at ${plain_directory}"
            return 1
        fi
    fi
}

function gocryptfs.mount_reverse_volume() {
    local plain_directory="$1"
    local chiper_directory="$2"

    gocryptfs._load_secret

    if gocryptfs._is_dir_mounted "${chiper_directory}"; then
        # log.warn "Gocrypfs cipher directory already mounted at ${chiper_directory}"
        log.debug "Gocrypfs cipher directory already mounted at ${chiper_directory}"
        return 0
    else
        echo "${GOCRYPTFS_SECRET}" | gocryptfs -reverse "${plain_directory}" "${chiper_directory}" >>"${LOG_FILE}" 2>&1
        # shellcheck disable=SC2181
        if (( $? == 0 )); then
            # log.info "Gocrypfs plain directory ${plain_directory} mounted as cipher directory at ${chiper_directory}"
            log.debug "Gocrypfs plain directory ${plain_directory} mounted as cipher directory at ${chiper_directory}"
            return 0
        else
            # log.error "Failed to mount gocrypfs plain directory ${plain_directory} as cipher directory at ${chiper_directory}"
            log.debug "Failed to mount gocrypfs plain directory ${plain_directory} as cipher directory at ${chiper_directory}"
            return 1
        fi
    fi
}

function gocryptfs.unmount() {
    local volume="$1"

    if common.is_dir_mounted "${volume}"; then
        if umount "${volume}" >>"${LOG_FILE}" 2>&1; then
            # log.info "Gocrypfs directory unmounted at ${volume}"
            log.debug "Gocrypfs directory unmounted at ${volume}"
            return 0
        else
            # log.error "Failed to unmount gocryptfs directory at ${volume}"
            log.debug "Failed to unmount gocryptfs directory at ${volume}"
            return 1
        fi
    else
        # log.warn "WARN: Gocrypfs directory already unmounted at ${volume}"
        log.debug "WARN: Gocrypfs directory already unmounted at ${volume}"
        return 0
    fi
}