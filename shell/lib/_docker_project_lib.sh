#!/bin/bash

readonly DOCKER_PROJECT_NAME="${PROJECT_BASE_NAME#lxc-}"

readonly DOCKER_PROJECT_DIRECTORY_PATH="${REPO_DIR}/docker"
readonly DOCKER_PROJECT_CUSTOM_DIRECTORY_PATH="${REPO_DIR}/docker/${PROJECT_NAME}"
readonly DOCKER_PROJECT_CUSTOM_BASE_DIRECTORY_PATH="${REPO_DIR}/docker/${PROJECT_BASE_NAME}"

readonly MESSAGE_DOCKER_PROJECT_UNCHANGED="No changes detected in the docker project."
readonly MESSAGE_DOCKER_PROJECT_CHANGE_DETECTED="Changes detected in the docker project."
readonly MESSAGE_DOCKER_PROJECT_UPDATE_SUCCESSFUL="Docker project successfully updated!"
readonly MESSAGE_DOCKER_PROJECT_UPDATE_FAILED="Failed to update docker project, but sucessfully restored!"
readonly MESSAGE_DOCKER_PROJECT_RESTORE_FAILED="Failed to restore docker project!"
readonly MESSAGE_DOCKER_PROJECT_BACKUP_SUCCESSFUL="Docker project backup was successful!"
readonly MESSAGE_DOCKER_PROJECT_BACKUP_FAILED="Failed to backup docker project!"

readonly DOCKER_PROJECT_TEMP_DIRECTORY_PATH="/tmp/${DOCKER_PROJECT_NAME}"
readonly DOCKER_PROJECT_PROD_DIRECTORY_PATH="/opt/docker/stacks/${DOCKER_PROJECT_NAME}"
readonly DOCKER_PROJECT_PLAIN_DIRECTORY_PATH="/opt/docker"
readonly DOCKER_PROJECT_CYPHER_DIRECTORY_PATH="/mnt/gocryptfs/cypher/docker"
readonly DOCKER_PROJECT_BACKUP_DIRECTORY_PATH="/backup/${CONTAINER_NAME}/docker"


function docker.project.stop() {
    cd "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}" >/dev/null 2>&1 && \
    docker compose down >/dev/null 2>&1
}

function docker.project.start() {
    cd "${DOCKER_PROJECT_PROD_DIRECTORY_PATH}" >/dev/null 2>&1 && \
    docker compose pull >/dev/null 2>&1 && \
    docker compose up -d >/dev/null 2>&1 && \
    yes | docker system prune --all >/dev/null 2>&1
}

function docker.project.reload() {
    docker.project.stop && docker.project.start
}

function docker.project.backup() {
    if gocryptfs.init_reverse_volume "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"; then
        if ! common.is_dir_exists "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"; then
            log.info "Creating directory for gocryptfs cipher volume at ${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
        fi

        if gocryptfs.mount_reverse_volume "${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}" "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"; then
            if ! common.is_dir_exists "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}" && common.create_directory "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
                log.info "Creating backup directory at ${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"
            fi
            if common.copy_directory "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}" "${DOCKER_PROJECT_BACKUP_DIRECTORY_PATH}"; then
                log.info "Docker project backup was successful."
            else
                log.error "Docker project backup failed!"
            fi
            gocryptfs.unmount "${DOCKER_PROJECT_CYPHER_DIRECTORY_PATH}"
        else
            log.error "Failed to mount reverse gocryptfs volume at ${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"
        fi
    else
        log.error "Failed to initialize reverse gocryptfs volume at ${DOCKER_PROJECT_PLAIN_DIRECTORY_PATH}"
    fi
    return 0
}

function docker.project.restore() {
    return 0
}

function docker.project.check() {
    return 0
}

function docker.project.update() {
    docker.project.backup
    return 0
}

