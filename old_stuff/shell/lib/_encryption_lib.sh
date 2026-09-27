#!/bin/bash

declare ENCRYPTION_KEY; ENCRYPTION_KEY="$(common.read_file "${ENCRYPTION_KEY_FILE_PATH}")"

function encryption.encrypt_file() {
    local key; key="${ENCRYPTION_KEY}"
    local plain_file="$1"
    local encrypted_file="$2"

    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -e -k "${key}" -in "${plain_file}" -out "${encrypted_file}"
}

function encryption.decrypt_file() {
    local key; key="${ENCRYPTION_KEY}"
    local encrypted_file="$1"
    local plain_file="$2"

    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -d -k "${key}" -in "${encrypted_file}" -out "${plain_file}"
}

function encryption.encrypt_string() {
    local key; key="${ENCRYPTION_KEY}"
    local plain_text="$*"

    echo -n "${plain_text}" | openssl enc -chacha20 -pbkdf2 -iter 200000 -a -e -k "${key}" | base64 -d | base64 -w 0
}

function encryption.decrypt_string() {
    local key; key="${ENCRYPTION_KEY}"
    local encrypted_text="$*"

    echo "${encrypted_text}" | openssl enc -chacha20 -pbkdf2 -iter 200000 -a -d -k "${key}"
}