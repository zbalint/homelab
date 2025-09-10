#!/bin/bash

function network.ping() {
    local address="$1"

     ping -q -c 3 "${address}" >/dev/null 2>&1
}