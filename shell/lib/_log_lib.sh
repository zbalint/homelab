#!/bin/bash

declare FIRST_MESSAGE_FLAG="true"

readonly _LOG_LEVEL_DEBUG=1
readonly _LOG_LEVEL_INFO=2
readonly _LOG_LEVEL_WARN=3
readonly _LOG_LEVEL_ERROR=4
readonly _LOG_LEVEL_FATAL=5

function log._is_var_equals() {
    local var="$1"
    local str="$2"

    if [ "${var}" == "${str}" ]; then
        return 0
    else
        return 1
    fi
}

function log._get_level_id() {
    local level="$1"

    case "${level}" in
        "DEBUG")
            echo "${_LOG_LEVEL_DEBUG}"
        ;;
        "INFO")
            echo "${_LOG_LEVEL_INFO}"
        ;;
        "WARN")
            echo "${_LOG_LEVEL_WARN}"
        ;;
        "ERROR")
            echo "${_LOG_LEVEL_WARN}"
        ;;
        "FATAL")
            echo "${_LOG_LEVEL_FATAL}"
        ;;
        *)
            echo "${_LOG_LEVEL_INFO}"
        ;;       
    esac
}

function log._init() {
    if ! test -d "${LOG_DIR}"; then
        mkdir -p "${LOG_DIR}"
    fi

    if [[ "${FIRST_MESSAGE_FLAG}" == "true" ]]; then
        FIRST_MESSAGE_FLAG="false"
        if test -f "${LOG_FILE}"; then
            echo "================================================ [$(date +"%Y-%m-%d %X")][$$] ================================================" >> "${LOG_FILE}"
        else
            echo "================================================ [$(date +"%Y-%m-%d %X")][$$] ================================================" > "${LOG_FILE}"
        fi
    fi
}

function log_.log_to_file() {
    local message="$*"

    echo "${message}" >> "${LOG_FILE}"
}

function log._log() {
    local level="$1"; shift
    local allowed_level_id; allowed_level_id="$(log._get_level_id "${LOG_LEVEL}")";
    local current_level_id; current_level_id="$(log._get_level_id "${level}")";
    local message="$*"

    if ((current_level_id>=allowed_level_id)); then
        echo "${level}: ${message}"
    fi

    log_.log_to_file "[$(date +"%Y-%m-%d %X")][$$][${level}]: ${message}"
}

function log.debug() {
    local message="$*"

    log._log "DEBUG" "${message}"
}

function log.info() {
    local message="$*"

    log._log "INFO" "${message}"
}

function log.warn() {
    local message="$*"

    log._log "WARN" "${message}"
}

function log.error() {
    local message="$*"

    log._log "ERROR" "${message}"
}

function log.fatal() {
    local message="$*"

    log._log "FATAL" "${message}"
}

log._init