#!/bin/bash

function common.is_var_set() {
    local var="$1"

    if [[ -n "${var}" ]]; then
        return 0
    else
        return 1
    fi
}

function common.is_var_empty() {
    local var="$1"

    if [[ -z "${var}" ]]; then
        return 0
    else
        return 1
    fi
}

function common.is_var_equals() {
    local var="$1"
    local str="$2"

    if [ "${var}" == "${str}" ]; then
        return 0
    else
        return 1
    fi
}

function common.is_file_exists() {
    local file="$1"

    test -f "${file}"
}

function common.is_dir_exists() {
    local dir="$1"

    test -d "${dir}"
}

function common.create_dir() {
    local dir="$1"

    mkdir -p "${dir}" >/dev/null 2>&1
}

function common.compare_files() {
    local file_1="$1"
    local file_2="$2"

    diff "${file_1}" "${file_2}" >/dev/null 2>&1
}

function common.copy_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/cp -rf "${src_file}" "${dst_file}" >/dev/null 2>&1
}

function common.move_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/mv -f "${src_file}" "${dst_file}" >/dev/null 2>&1
}

function common.read_file() {
    local file="$1"

    if common.is_file_exists "${file}"; then
        cat "${file}"
    fi
}

function common.write_file() {
    local file="$1"
    local content="$2"

    echo -n "${content}" > "${file}"
}