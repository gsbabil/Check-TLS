#!/bin/bash -e

START_TIMESTAMP=$(date +%s)

DEBUG=0 ## shows debug output
OPENSSL_BIN='' ## auto-detected
CONNECTION_TIMEOUT='5s' ## openssl is killed after 'timeout' period

IGNORED_PROTOCOLS='dtls1'
IGNORED_CIPHERS=''

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

function show_usage() {
    if [[ ${DEBUG} == 1 ]]
    then
        echo "[+] Total arguments: $#"
    fi

    echo
    echo -e "${COLOR_RED}[+] usage: $(basename $0) host port \\
    location-of-openssl-bin (optional) ${COLOR_RESET}\n"
    echo "e.g. $(basename $0) gateway.push.apple.com 2195 /usr/bin/openssl"
    echo
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

function detect_openssl_protocols() {
    local magic_string='just use'
    local openssl_client_protocols=$(${OPENSSL_BIN} s_client -help 2>&1 \
        | grep -i "${magic_string}" \
        | awk '{print $1}' \
        | xargs echo)

    if [[ -z ${openssl_client_protocols} \
        || ${#openssl_client_protocols[*]} == 0 ]]
    then
        echo "(null)"
    else
        echo -n "${openssl_client_protocols}"
    fi
}

function detect_openssl_ciphers() {
    local openssl_client_ciphers=$(${OPENSSL_BIN} ciphers 'ALL:eNULL' \
        | sed -e 's/:/ /g')

    if [[ -z ${openssl_client_ciphers} \
        || ${#openssl_client_ciphers[*]} == 0 ]]
    then
        echo "(null)"
    else
        echo -n "${openssl_client_ciphers}"
    fi
}

function check_protocol() {
    local SERVER_HOST="$1"
    local SERVER_PORT="$2"
    local PROTOCOL="$3"
    local MAGIC_STRING="Master-Key:"

    local result=$(timeout ${CONNECTION_TIMEOUT} ${OPENSSL_BIN} s_client \
        -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
        2>&1 </dev/null \
        | grep "${MAGIC_STRING}")

    if [[ ${DEBUG} == 1 ]]
    then
        timeout ${CONNECTION_TIMEOUT} ${OPENSSL_BIN} s_client \
            -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
            2>&1 </dev/null
    fi

    if [[ ! -z ${result} ]]
    then
        echo "${result}" \
            | $(platform_specific_sed) "s/${MAGIC_STRING}//g;s/[\t ]+//g;"
    fi
}

function check_cipher() {
    local SERVER_HOST="$1"
    local SERVER_PORT="$2"
    local PROTOCOL="$3"
    local CIPHER="$4"
    local MAGIC_STRING="Master-Key:"

    local result=$(timeout ${CONNECTION_TIMEOUT} ${OPENSSL_BIN} s_client \
        -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
        -cipher ${CIPHER} 2>&1 </dev/null \
        | grep "${MAGIC_STRING}")

    if [[ ${DEBUG} == 1 ]]
    then
        timeout ${CONNECTION_TIMEOUT} ${OPENSSL_BIN} s_client \
            -connect ${SERVER_HOST}:${SERVER_PORT} ${PROTOCOL} \
            -cipher ${CIPHER} 2>&1 </dev/null
    fi

    if [[ ! -z ${result} ]]
    then
        echo "${result}" \
            | $(platform_specific_sed) "s/${MAGIC_STRING}//g;s/[\t ]+//g;"
    fi
}

function main() {
    if [[ $# < 2 ]]
    then
       show_usage $@
       return -1
    fi

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

        OPENSSL_CLIENT_PROTOCOLS=$(detect_openssl_protocols)
        if [[ ${OPENSSL_CLIENT_PROTOCOLS} != '(null)' ]]
        then
            echo "[+] protocols supported by openssl: ${OPENSSL_CLIENT_PROTOCOLS}"
        else
            echo "[+] openssl client supported protocols couldn't be \
                detected, quitting ..."
            return -1
        fi

        OPENSSL_CLIENT_CIPHERS=$(detect_openssl_ciphers)
        if [[ ${OPENSSL_CLIENT_CIPHERS} != '(null)' ]]
        then
            echo "[+] ciphers supported by openssl: ${OPENSSL_CLIENT_CIPHERS}"
        else
            echo "[+] openssl client supported ciphers couldn't be \
                detected, quitting ..."
            return -1
        fi
    else
        echo "[+] invalid openssl binary, quitting ..."
        return -1
    fi

    echo
    if [[ ! -z ${IGNORED_PROTOCOLS} ]]
    then
        echo "[+] ignored protocols from check: ${IGNORED_PROTOCOLS}"
    fi

    if [[ ! -z ${IGNORED_CIPHERS} ]]
    then
        echo "[+] ignored ciphers from check: ${IGNORED_PROTOCOLS}"
    fi

    echo
    SUPPORTED_PROTOCOLS=""

    for protocol in ${OPENSSL_CLIENT_PROTOCOLS}
    do
        if [[ ! $(echo "${protocol}" | grep "${IGNORED_PROTOCOLS}") ]]
        then
            echo "[+] checking ${protocol} on $1:$2"
            local result=$(check_protocol "$1" "$2" "${protocol}")
            if [[ -z "${result}" ]]
            then
                # echo -e "${COLOR_RED}\t- connection failed with ${protocol} ${COLOR_RESET}"
                echo -n
            else
                # echo -e "${COLOR_BLUE}\t- connection successful with ${protocol} ${COLOR_RESET}"
                # echo -e "\t- session master-key: $result"
                echo -n
                SUPPORTED_PROTOCOLS="${SUPPORTED_PROTOCOLS} ${protocol}"
            fi
        fi
    done

    if [[ -z ${SUPPORTED_PROTOCOLS} ]]
    then
        echo "[+] no supported protocol found, skipping cipher check"
    else
        echo
        echo "[+] protocols detected on $1:$2: ${SUPPORTED_PROTOCOLS}"
        echo "[+] proceeding to detect supported ciphers ..."
        echo
    fi

    SUPPORTED_CIPHERS=""
    for protocol in ${SUPPORTED_PROTOCOLS}
    do
        for cipher in ${OPENSSL_CLIENT_CIPHERS}
        do
            local result=$(check_cipher "$1" "$2" "${protocol}" "${cipher}")
            if [[ -z "${result}" ]]
            then
                echo -e "${COLOR_RED}  - connection failed with ${protocol}:${cipher} ${COLOR_RESET}"
            else
                echo -e "${COLOR_BLUE}  - connection successful with ${protocol}:${cipher}"
                echo -e "${COLOR_BLUE}  - session master-key: ${result} ${COLOR_RESET}"
                SUPPORTED_CIPHERS="${SUPPORTED_CIPHERS} $protocol:${cipher}"
            fi
        done
    done

    if [[ ! -z ${SUPPORTED_CIPHERS} ]]
    then
        echo
        echo "[+] "$1:$2 supports the following:
        echo

        for x in ${SUPPORTED_CIPHERS}
        do
            pc=$(echo $x | sed 's/^-//')
            echo -e "${COLOR_BLUE}  - $pc ${COLOR_RESET}"
        done
    fi
}

main $@

END_TIMESTAMP=$(date +%s)
TIME_WASTED=$(echo "${END_TIMESTAMP} - ${START_TIMESTAMP}" | bc)

echo
echo "[+] check completed in ${TIME_WASTED} seconds!"
echo

