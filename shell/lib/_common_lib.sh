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

function common.is_dir_mounted() {
    local directory="$1"

    if mountpoint -q "${directory}"; then
        return 0
    fi

    return 1
}

function common.is_dir_exists() {
    local dir="$1"

    test -d "${dir}"
}

function common.create_dir() {
    local dir="$1"

    mkdir -p "${dir}" >>"${LOG_FILE}" 2>&1
}

function common.compare_files() {
    local file_1="$1"
    local file_2="$2"

    diff "${file_1}" "${file_2}" >>"${LOG_FILE}" 2>&1
}

function common.get_directory_hash() {
    local directory="$1"
    find "${directory}" -type f -exec md5sum {} + | sort -k 2 | awk '{print $1}' | md5sum
}

function common.compare_directories() {
    local directory_1="$1"
    local directory_2="$2"

    diff "${directory_1}/" "${directory_2}/" >>"${LOG_FILE}" 2>&1
}

function common.compare_directories_by_hash() {
    local directory_1="$1"
    local directory_2="$2"
    local directory_1_hash; directory_1_hash="$(common.get_directory_hash "${directory_1}")"
    local directory_2_hash; directory_2_hash="$(common.get_directory_hash "${directory_2}")"
    
    common.is_var_equals "${directory_1_hash}" "${directory_2_hash}"
}

function common.copy_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/cp -rf "${src_file}" "${dst_file}" >>"${LOG_FILE}" 2>&1
}

function common.move_file() {
    local src_file="$1"
    local dst_file="$2"

    /bin/mv -f "${src_file}" "${dst_file}" >>"${LOG_FILE}" 2>&1
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

function common.create_directory() {
    local directory="$1"

    mkdir -p "${directory}"
}

function common.copy_directory() {
    local source_dir="$1"
    local dest_dir="$2"

    if common.is_var_empty "${source_dir}" || common.is_var_equals "${source_dir}" "/"; then
        return 1
    fi

    if common.is_var_empty "${dest_dir}" || common.is_var_equals "${dest_dir}" "/"; then
        return 1
    fi
    

    rsync -av "${source_dir}/" "${dest_dir}/" >>"${LOG_FILE}" 2>&1
}

function common.replace_directory() {
    local source_dir="$1"
    local dest_dir="$2"

    if common.is_var_empty "${source_dir}" || common.is_var_equals "${source_dir}" "/"; then
        return 1
    fi

    if common.is_var_empty "${dest_dir}" || common.is_var_equals "${dest_dir}" "/"; then
        return 1
    fi
    

    rsync -av --delete "${source_dir}/" "${dest_dir}/" >>"${LOG_FILE}" 2>&1
}