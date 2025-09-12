#!/bin/bash

function network.ping() {
    local address="$1"

     ping -q -c 3 "${address}" >>"${LOG_FILE}" 2>&1
}