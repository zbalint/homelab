#!/bin/bash

function random.get_number() {
    local min="$1"
    local max="$2"

    if [[ -z "${min}" ]]; then
        min=0
    fi

    if [[ -z "${max}" ]]; then
        max=10000
    fi

    if ((min>max)); then
        local tmp=$min
        min=$max
        max=$tmp
    fi

    echo $(( RANDOM % (max - min + 1) + min ))
}

function random.get_string() {
    local length="$1"

    if [[ -n "${length}" ]]; then
        length=$((length/2))
    else
        length=$(random.get_number 8 64)
    fi

    openssl rand -hex "${length}"
}