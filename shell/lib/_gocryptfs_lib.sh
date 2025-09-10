#!/bin/bash

function gocryptfs._is_dir_mounted() {
    local directory="$1"

    if mountpoint -q "${directory}"; then
        return 0
    fi

    return 1
}

function gocryptfs.init_normal_volume() {
    local cipher_directory="$1"

    if test -f "${cipher_directory}/.gocryptfs.conf"; then
        log.into "Gocryptfs normal volume found at ${cipher_directory}"
        return 0
    fi

    if echo "${GOCRYPTFS_SECRET}" | gocryptfs -init "${cipher_directory}"; then
        log.info "Gocryptfs normal volume initialized at ${cipher_directory}"
        return 0
    else
        log.error "Could not initialize gocryptfs normal volume at ${cipher_directory}!"
        return 1
    fi
}

function gocryptfs.init_reverse_volume() {
    local plain_directory="$1"

    if test -f "${plain_directory}/.gocryptfs.reverse.conf"; then
        log.info "Gocryptfs reverse volume found at ${plain_directory}"
        return 0
    fi

    if echo "${GOCRYPTFS_SECRET}" | gocryptfs -init -reverse "${plain_directory}"; then
        log.info "Gocryptfs reverse volume initialized at ${plain_directory}"
        return 0
    else
        log.error "Could not initialize gocryptfs reverse volume at ${plain_directory}!"
        return 1
    fi
}

function gocryptfs.mount_normal_volume() {
    local plain_directory="$1"
    local chiper_directory="$2"

    if gocryptfs._is_dir_mounted "${plain_directory}"; then
        log.warn "Gocrypfs plain directory already mounted at ${plain_directory}"
    else
        echo "${GOCRYPTFS_SECRET}" | gocryptfs "${chiper_directory}" "${plain_directory}"
        log.info "Gocrypfs cipher directory ${chiper_directory} mounted as plain directory at ${plain_directory}"
    fi
}

function gocryptfs.mount_reverse_volume() {
    local plain_directory="$1"
    local chiper_directory="$2"

    if gocryptfs._is_dir_mounted "${chiper_directory}"; then
        log.warn "Gocrypfs cipher directory already mounted at ${chiper_directory}"
    else
        echo "${GOCRYPTFS_SECRET}" | gocryptfs -reverse "${plain_directory}" "${chiper_directory}"
        log.info "Gocrypfs plain directory ${plain_directory} mounted as cipher directory at ${chiper_directory}"
    fi
}

