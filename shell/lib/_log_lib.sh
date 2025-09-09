#!/bin/bash

function log._log() {
    local level="$1"; shift
    local message="$*"

    echo "${level}: ${message}"
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

