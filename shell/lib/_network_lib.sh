#!/bin/bash

function network.curl() {
    local params="$*"

    # shellcheck disable=SC2086
    curl --insecure -m 10 --retry 3 ${params}
}