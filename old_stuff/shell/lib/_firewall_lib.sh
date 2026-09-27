#!/bin/bash

readonly CHECK_ADDRESS_CLOUDFLARE="1.1.1.1"
readonly CHECK_ADDRESS_TAILSCALE="tailscale.com"
readonly CHECK_ADDRESS_TRAEFIK_PROXY_01="lxc-traefik-01"
readonly CHECK_ADDRESS_TRAEFIK_PROXY_02="lxc-traefik-02"

readonly FIREWALL_CONFIG_DIRECTORY_PATH="${REPO_DIR}/firewall"
readonly FIREWALL_CUSTOM_CONFIG_DIRECTORY_PATH="${REPO_DIR}/firewall/${CONTAINER_NAME}"
readonly FIREWALL_CUSTOM_BASE_CONFIG_DIRECTORY_PATH="${REPO_DIR}/firewall/${CONTAINER_BASE_NAME}"
readonly FIREWALL_CONFIG_FILE_NAME="nftables.conf"
readonly FIREWALL_CONFIG_FILE_PATH="${FIREWALL_CONFIG_DIRECTORY_PATH}/${FIREWALL_CONFIG_FILE_NAME}"
readonly FIREWALL_CUSTOM_CONFIG_FILE_PATH="${FIREWALL_CUSTOM_CONFIG_DIRECTORY_PATH}/${FIREWALL_CONFIG_FILE_NAME}"
readonly FIREWALL_CUSTOM_BASE_CONFIG_FILE_PATH="${FIREWALL_CUSTOM_BASE_CONFIG_DIRECTORY_PATH}/${FIREWALL_CONFIG_FILE_NAME}"

readonly FIREWALL_CONFIG_PROD_FILE_PATH="/etc/nftables.conf"
readonly FIREWALL_CONFIG_BACKUP_FILE_PATH="/etc/nftables.conf.bak"


readonly MESSAGE_NETWORK_CLOUDFLARE_UNREACHABLE="Could not reach cloudflare at ${CHECK_ADDRESS_CLOUDFLARE}."
readonly MESSAGE_NETWORK_TAILSCALE_UNREACHABLE="Could not reach tailscale at ${CHECK_ADDRESS_TAILSCALE}."
readonly MESSAGE_NETWORK_TRAEFIK_UNREACHABLE="Could not reach reverse proxy at any of the following addresses: ${CHECK_ADDRESS_TRAEFIK_PROXY_01}, ${CHECK_ADDRESS_TRAEFIK_PROXY_02}."

readonly MESSAGE_FIREWALL_CONFIG_UNCHANGED="No changes detected in the firewall config."
readonly MESSAGE_FIREWALL_CONFIG_CHANGE_DETECTED="Changes detected in the firewall config."
readonly MESSAGE_FIREWALL_UPDATE_SUCCESSFUL="Firewall config successfully updated!"
readonly MESSAGE_FIREWALL_UPDATE_FAILED="Failed to update firewall config, but sucessfully restored!"
readonly MESSAGE_FIREWALL_RESTORE_FAILED="Failed to restore firewall config!"
readonly MESSAGE_FIREWALL_BACKUP_SUCCESSFUL="Firewall config backup was successful!"
readonly MESSAGE_FIREWALL_BACKUP_FAILED="Failed to backup firewall config!"

function firewall.reload() {
    systemctl start nftables >>"${LOG_FILE}" 2>&1 && \
    systemctl reload nftables >>"${LOG_FILE}" 2>&1
}

function firewall.backup() {
    common.copy_file "${FIREWALL_CONFIG_PROD_FILE_PATH}" "${FIREWALL_CONFIG_BACKUP_FILE_PATH}"
}

function firewall.restore() {
    common.copy_file "${FIREWALL_CONFIG_BACKUP_FILE_PATH}" "${FIREWALL_CONFIG_PROD_FILE_PATH}"
}

function firewall.load_config() {
    local config_file="$1"

    common.copy_file "${config_file}" "${FIREWALL_CONFIG_PROD_FILE_PATH}"
}

function firewall.connectivity_check() {
    if ! network.ping "${CHECK_ADDRESS_CLOUDFLARE}"; then
        log.error "${MESSAGE_NETWORK_CLOUDFLARE_UNREACHABLE}"
        return 1
    fi
    if ! network.ping "${CHECK_ADDRESS_TAILSCALE}"; then
        log.error "${MESSAGE_NETWORK_TAILSCALE_UNREACHABLE}"
        return 1
    fi
    # if ! network.ping "${CHECK_ADDRESS_TRAEFIK_PROXY_01}" && ! network.ping "${CHECK_ADDRESS_TRAEFIK_PROXY_02}"; then
    #     log.error "${MESSAGE_NETWORK_TRAEFIK_UNREACHABLE}"
    #     return 1
    # fi

    return 0   
}

function firewall.update() {
    local firewall_new_config_path
    local firewall_old_config_path; firewall_old_config_path="${FIREWALL_CONFIG_PROD_FILE_PATH}"

    if common.is_file_exists "${FIREWALL_CUSTOM_CONFIG_FILE_PATH}"; then
        firewall_new_config_path="${FIREWALL_CUSTOM_CONFIG_FILE_PATH}"
        log.info "Found custom firewall config at ${firewall_new_config_path}"
    elif common.is_file_exists "${FIREWALL_CUSTOM_BASE_CONFIG_FILE_PATH}"; then
        firewall_new_config_path="${FIREWALL_CUSTOM_BASE_CONFIG_FILE_PATH}"
        log.info "Found custom firewall config at ${firewall_new_config_path}"
    else
        firewall_new_config_path="${FIREWALL_CONFIG_FILE_PATH}"
        log.info "Found default firewall config at ${firewall_new_config_path}"
    fi

    if common.compare_files "${firewall_new_config_path}" "${firewall_old_config_path}"; then
        log.info "${MESSAGE_FIREWALL_CONFIG_UNCHANGED}"
    else
        log.info "${MESSAGE_FIREWALL_CONFIG_CHANGE_DETECTED}"
        if firewall.backup; then
            log.info "${MESSAGE_FIREWALL_BACKUP_SUCCESSFUL}"
            if firewall.load_config "${firewall_new_config_path}" && firewall.reload && firewall.connectivity_check; then
                log.info "${MESSAGE_FIREWALL_UPDATE_SUCCESSFUL}"
                notification.info "Firewall" "${MESSAGE_FIREWALL_UPDATE_SUCCESSFUL}"
            elif firewall.restore && firewall.reload && firewall.connectivity_check; then
                log.warn "${MESSAGE_FIREWALL_UPDATE_FAILED}"
                notification.warn "Firewall" "${MESSAGE_FIREWALL_UPDATE_FAILED}"
            else
                log.error "${MESSAGE_FIREWALL_RESTORE_FAILED}"
                notification.error "Firewall" "${MESSAGE_FIREWALL_RESTORE_FAILED}"
            fi
        else
            log.error "${MESSAGE_FIREWALL_BACKUP_FAILED}"
            notification.error "Firewall" "${MESSAGE_FIREWALL_BACKUP_FAILED}"
        fi
    fi
}