#!/bin/bash -e

DEBUG=0 ## shows debug output
OPENSSL_BIN='' ## auto-detected
IGNORED_PROTOCOLS='dtls1'

COLOR_RESET=$(tput sgr0 2>/dev/null)
COLOR_RED=$(tput setaf 1 2>/dev/null)
COLOR_BLUE=$(tput setaf 4 2>/dev/null)

echo -ne "${COLOR_RESET}"

function platform_specific_sed() {
    if [[ $(uname) == 'Darwin' ]]
    then
        echo -n 'sed -E'
    elif [[ $(uname) == 'Linux' ]]
    then
        echo -n 'sed -r'
    else
        echo -n ''
    fi
}

function usage() {
    if [[ ${DEBUG} == 1 ]]
    then
        echo "[+] Total arguments: $#"
    fi

    if [[ $# < 2 ]]
    then
        echo
        echo -e "${COLOR_RED}[+] usage: $(basename $0) host port
        location-of-openssl-bin (optional) ${COLOR_RESET}\n"
        echo "e.g. $(basename $0) gateway.push.apple.com 2195 /usr/bin/openssl"
        echo
    fi
}

function detect_openssl_binary() {
    local openssl_bin="$(which openssl)"

    if [[ ! -e ${openssl_bin} ]]
    then
        echo '(null)'
    else
        echo -n "${openssl_bin}"
    fi
}

function detect_openssl_capability() {
    local magic_string='just use'
    local openssl_client_capabilities=$(${OPENSSL_BIN} s_client -help 2>&1 \
        | grep -i "${magic_string}" \
        | awk '{print $1}' \
        | xargs echo)

    if [[ -z ${openssl_client_capabilities} \
        || ${#openssl_client_capabilities[*]} == 0 ]]
    then
        echo "(null)"
    else
        echo -n "${openssl_client_capabilities}"
    fi
}

function check_server() {
    local SERVER_HOST="$1"
    local SERVER_PORT="$2"
    local PROTOCOL="$3"
    local MAGIC_STRING="Master-Key:"

    local result=$(${OPENSSL_BIN} s_client \
        -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
        2>&1 </dev/null \
        | grep "${MAGIC_STRING}")

    if [[ ${DEBUG} == 1 ]]
    then
        ${OPENSSL_BIN} s_client \
            -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
            2>&1 </dev/null
    fi

    if [[ ! -z ${result} ]]
    then
        echo "$result" \
            | $(platform_specific_sed) "s/${MAGIC_STRING}//g;s/[\t ]+//g;"
    fi
}

function main() {
    usage $@

    if [[ -z "$3" ]]
    then
        OPENSSL_BIN=$(detect_openssl_binary)
    else
        OPENSSL_BIN="$3"
    fi

    if [[ -e ${OPENSSL_BIN} ]]
    then
        echo "[+] using openssl binary at: ${OPENSSL_BIN}"
        echo "[+] openssl version: '$(${OPENSSL_BIN} version)'"

        OPENSSL_CLIENT_CAPABILITIES=$(detect_openssl_capability)
        if [[ ${OPENSSL_CLIENT_CAPABILITIES} != '(null)' ]]
        then
            echo "[+] openssl client supports: ${OPENSSL_CLIENT_CAPABILITIES}"
        else
            echo "[+] openssl client capabilities couldn't be detected, quitting ..."
            return -1
        fi
    else
        echo "[+] invalid openssl binary, quitting ..."
        return -1
    fi

    if [[ ! -z ${IGNORED_PROTOCOLS} ]]
    then
        echo "[+] ignoring from check: ${IGNORED_PROTOCOLS}"
    fi

    echo
    for protocol in ${OPENSSL_CLIENT_CAPABILITIES}
    do
        if [[ ! $(echo "${protocol}" | grep "${IGNORED_PROTOCOLS}") ]]
        then
            echo "[+] trying '${protocol}' on '$1:$2'"
            local result=$(check_server "$1" "$2" "${protocol}")
            if [[ -z "${result}" ]]
            then
                echo -e "${COLOR_RED}\t- connection failed with '${protocol}' ${COLOR_RESET}"
            else
                echo -e "${COLOR_BLUE}\t- connection successful with '${protocol}' ${COLOR_RESET}"
                echo -e "\t- session master-key: $result"
            fi
        fi
    done
}

main $@


