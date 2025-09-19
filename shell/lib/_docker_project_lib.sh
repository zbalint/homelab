#!/bin/bash

readonly DOCKER_PROJECT_NAME="${PROJECT_BASE_NAME#lxc-}"

readonly DOCKER_PROJECT_DIRECTORY_PATH="${REPO_DIR}/docker/project"
readonly DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH="${DOCKER_PROJECT_DIRECTORY_PATH}/${PROJECT_NAME}"
readonly DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH="${DOCKER_PROJECT_DIRECTORY_PATH}/${PROJECT_BASE_NAME}"

readonly MESSAGE_DOCKER_PROJECT_UNCHANGED="No changes detected in the docker project."
readonly MESSAGE_DOCKER_PROJECT_CHANGE_DETECTED="Changes detected in the docker project."
readonly MESSAGE_DOCKER_PROJECT_UPDATE_SUCCESSFUL="Docker project successfully updated!"
readonly MESSAGE_DOCKER_PROJECT_UPDATE_FAILED="Failed to update docker project, but sucessfully restored!"
readonly MESSAGE_DOCKER_PROJECT_RESTORE_SUCCESSFUL="Docker project successfully restored!"
readonly MESSAGE_DOCKER_PROJECT_RESTORE_FAILED="Failed to restore docker project!"
readonly MESSAGE_DOCKER_PROJECT_BACKUP_SUCCESSFUL="Docker project backup was successful!"
readonly MESSAGE_DOCKER_PROJECT_BACKUP_FAILED="Failed to backup docker project!"

readonly DOCKER_PROJECT_TEMP_DIRECTORY_PATH="${TEMP_DIR}/${DOCKER_PROJECT_NAME}"
readonly DOCKER_PROJECT_PROD_DIRECTORY_PATH="/opt/docker/stacks/${DOCKER_PROJECT_NAME}"
readonly DOCKER_PROJECT_PLAIN_DIRECTORY_PATH="/opt/docker"
readonly DOCKER_PROJECT_CYPHER_DIRECTORY_PATH="/mnt/gocryptfs/cypher/docker"
readonly DOCKER_PROJECT_RESTORE_DIRECTORY_PATH="/mnt/gocryptfs/plain/docker"
readonly DOCKER_PROJECT_BACKUP_DIRECTORY_PATH="/backup/${CONTAINER_NAME}/docker"

readonly DOCKER_GOCRYPTFS_REVERSE_CONFIG_FILE="${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}/.gocryptfs.reverse.conf"
readonly DOCKER_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE="/tmp/.gocryptfs.reverse.conf"

readonly DOCKER_USER="tartarus"

function docker.project.stop() {
    log.debug "Stopping docker project... (delay 5sec)"

    cd "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}" >>"${LOG_FILE}" 2>&1 && \
    docker compose down >>"${LOG_FILE}" 2>&1 && \
    sleep 5
}

function docker.project.start() {
    log.debug "Starting docker project... (delay 5sec)"

    cd "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}" >>"${LOG_FILE}" 2>&1 && \
    docker compose pull >>"${LOG_FILE}" 2>&1 && \
    docker compose up -d >>"${LOG_FILE}" 2>&1 && \
    yes | docker system prune --all >>"${LOG_FILE}" 2>&1 && \
    sleep 5
}

function docker.project.reload() {
    log.debug "Restarting docker project..."
    docker.project.stop && docker.project.start
}

function docker.project.backup() {
    if gocryptfs.init_reverse_volume "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"; then
        if ! common.is_dir_exists "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"; then
            log.debug "Creating directory for gocryptfs cipher volume at ${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
        fi

        if gocryptfs.mount_reverse_volume "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}" "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"; then
            if ! common.is_dir_exists "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
                log.debug "Creating backup directory at ${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"
            fi
            
            if common.copy_directory "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}" "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
                gocryptfs.unmount "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
                return 0
            else
                gocryptfs.unmount "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
                return 1
            fi
        else
            log.error "Failed to mount reverse gocryptfs volume at ${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"
            return 1
        fi
    else
        log.error "Failed to initialize reverse gocryptfs volume at ${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"
        return 1
    fi
}

function docker.project.restore() {
    if ! common.is_dir_exists "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
        log.debug "Backup directory does not exists at ${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
        return 1
    fi

    if ! common.is_dir_exists "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}"; then
        log.debug "Creating directory for gocryptfs plain volume at ${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}"
    fi

    if gocryptfs.mount_normal_volume "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}" "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
        if ! common.is_dir_exists "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"; then
            log.debug "Creating project directory at ${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"
        fi
        
        if common.is_file_exists "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_FILE}"; then
            common.copy_file "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_FILE}" "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}"
        fi

        if common.copy_directory "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}" "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"; then
            if common.is_file_exists "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}"; then
                common.copy_file "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_BACKUP_FILE}" "${DOCKER_GOCRYPTFS_REVERSE_CONFIG_FILE}"
            fi
            gocryptfs.unmount "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}"
            return 0
        else
            gocryptfs.unmount "${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}"
            return 1
        fi
    else
        log.error "Failed to mount gocryptfs volume at ${DOCKER_PROJECT_RESTORE_DIRECTORY_PATH}"
        return 1
    fi
}

function docker.project.compare() {
    if ! common.is_dir_exists "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}"; then
        log.debug "Creating temp directory at ${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
    fi

    if common.is_dir_exists "${DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH}" && common.replace_directory "${DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH}" "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}"; then
        log.debug "Copying ${DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH} content to ${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}."
    fi
    
    if common.is_dir_exists "${DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH}" && common.copy_directory "${DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH}" "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}"; then
        log.debug "Copying ${DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH} content to ${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}."
    fi

    chown -R ${DOCKER_USER}:${DOCKER_USER} "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}"

    if common.compare_directories "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}" "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}"; then
        if common.compare_directories_by_hash "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}" "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

function docker.project.check() {
    local docker_project_file_path="${DOCKER_PROJECT_PROD_DIRECTORY_PATH}/docker-compose.yaml"
    local temp_file="/tmp/container_list"
    local status=0

    log.debug "Checking docker project health..."
    grep "container_name" "${docker_project_file_path}" | awk '{print $2}' > "${temp_file}"
    
    while IFS= read -r container; do
        if docker ps | grep "${container}" >>"${LOG_FILE}" 2>&1; then
            log.debug "Container ${container} is running."
        else
            log.debug "Container ${container} is not running!"
            status=1
        fi
    done < "${temp_file}"

    rm -f "${temp_file}"

    return ${status}
}

function docker.project.copy() {
    log.debug "Copying ${DOCKER_PROJECT_TEMP_DIRECTORY_PATH} content to ${DOCKER_PROJECT_PROD_DIRECTORY_PATH}."
    common.replace_directory "${DOCKER_PROJECT_TEMP_DIRECTORY_PATH}" "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}"
}

function docker.project.is_first_run() {
    if ! common.is_file_exists "${GOCRYPTFS_SECRET_FILE_PATH}" && common.is_dir_exists "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
        return 0
    else
        return 1
    fi
}

function docker.project.is_first_update() {
    if common.is_file_exists "${GOCRYPTFS_SECRET_FILE_PATH}" && common.is_dir_exists "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}" && ! common.is_dir_exists "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}"; then
        return 0
    else
        return 1
    fi
}

function docker.project.update() {
    if common.is_file_exists "${DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH}/docker-compose.yaml"; then
        log.info "Found docker project at ${DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH}"
    elif common.is_file_exists "${DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH}/docker-compose.yaml"; then
        log.info "Found docker project at ${DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH}"
    else
        log.info "No docker project found."
        return 1
    fi

    if docker.project.is_first_run; then
        log.warn "Docker project" "Gocryptfs secret ${GOCRYPTFS_SECRET_FILE_PATH} is missing but backup exists at ${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}. Skipping update until secret is provided or backup is deleted."
        notification.warn "Docker project" "Gocryptfs secret ${GOCRYPTFS_SECRET_FILE_PATH} is missing but backup exists at ${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}. Skipping update until secret is provided or backup is deleted."
        return 1
    fi

    if docker.project.compare; then
        log.info "${MESSAGE_DOCKER_PROJECT_UNCHANGED}"
    else
        log.info "${MESSAGE_DOCKER_PROJECT_CHANGE_DETECTED}"
        if docker.project.is_first_update; then
            log.info "This is the first update. Restoring backup before proceeding."
            if docker.project.restore; then
                log.warn "${MESSAGE_DOCKER_PROJECT_RESTORE_SUCCESSFUL}"
            else
                log.error "${MESSAGE_DOCKER_PROJECT_RESTORE_FAILED}"
            fi
        fi
        if docker.project.backup; then
            log.info "${MESSAGE_DOCKER_PROJECT_BACKUP_SUCCESSFUL}"
            if docker.project.copy && docker.project.reload && docker.project.check; then
                log.info "${MESSAGE_DOCKER_PROJECT_UPDATE_SUCCESSFUL}"
                notification.info "Docker project" "${MESSAGE_DOCKER_PROJECT_UPDATE_SUCCESSFUL}"
            elif docker.project.restore && docker.project.reload && docker.project.check; then
                log.warn "${MESSAGE_DOCKER_PROJECT_UPDATE_FAILED}"
                notification.warn "Docker project" "${MESSAGE_DOCKER_PROJECT_UPDATE_FAILED}"
            else
                log.error "${MESSAGE_DOCKER_PROJECT_RESTORE_FAILED}"
                notification.error "Docker project" "${MESSAGE_DOCKER_PROJECT_RESTORE_FAILED}"
            fi
        else
            log.error "${MESSAGE_DOCKER_PROJECT_BACKUP_FAILED}"
            notification.error "Docker project" "${MESSAGE_DOCKER_PROJECT_BACKUP_FAILED}"
        fi
    fi
    
    return 0
}

