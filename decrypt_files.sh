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

function decrypt_files() {
    local encrypted_file_postfix="$1"
    local decrypted_file_postfix="$2"

    find -name "*${encrypted_file_postfix}" | while read -r encrypted_file
    do
        local decrypted_file="${encrypted_file%${encrypted_file_postfix}}${decrypted_file_postfix}"  
        # echo "INFO: Decrypting ${encrypted_file} file to ${decrypted_file}"
        decrypt_file "${encrypted_file}" "${decrypted_file}"
    done
}

function main() {
    echo "INFO: Decrypting files..."
    decrypt_files ".env.enc" ".env"
    decrypt_files "_secret.enc" "_secret"
    encrypt_files "_authelia.yml.enc" "_authelia.yml"
    return 0
}

main