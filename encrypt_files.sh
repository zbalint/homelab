#!/bin/bash

readonly GLOBAL_SECRET_DIR="/secrets"
readonly ENCRYPTION_KEY_FILE_PATH="${GLOBAL_SECRET_DIR}/.encryption_key"

function is_file_exists() {
    local file="$1"

    test -f "${file}"
}

function read_file() {
    local file="$1"

    if is_file_exists "${file}"; then
        cat "${file}"
    fi
}

function encrypt_file() {
    local plain_file="$1"
    local encrypted_file="$2"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -e -k "${key}" -in "${plain_file}" -out "${encrypted_file}"
}

function decrypt_file() {
    local encrypted_file="$1"
    local plain_file="$2"
    local key; key=$(read_file "${ENCRYPTION_KEY_FILE_PATH}")
    openssl enc -chacha20 -pbkdf2 -iter 200000 -a -d -k "${key}" -in "${encrypted_file}" -out "${plain_file}"
}

function encrypt_files() {
    local decrypted_file_postfix="$1"
    local encrypted_file_postfix="$2"

    find -name "*${decrypted_file_postfix}" | while read -r decrypted_file
    do
        local encrypted_file="${decrypted_file%${decrypted_file_postfix}}${encrypted_file_postfix}"  
        # echo "INFO: Encrypting ${decrypted_file} file to ${encrypted_file}"
        encrypt_file "${decrypted_file}" "${encrypted_file}" 
    done
}

function main() {
    echo "INFO: Encrypting files..."
    encrypt_files ".env" ".env.enc"
    encrypt_files "_secret" "_secret.enc"
    encrypt_files "_authelia.yml" "_authelia.yml.enc"
    return 0
}

main