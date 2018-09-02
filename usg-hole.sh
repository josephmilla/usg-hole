#!/usr/bin/env bash

set -e

# Check out: https://github.com/StevenBlack/hosts
readonly RAW_HOSTS="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"
readonly WORKSPACE="/config/user-data/usg-hole"

# Crontab Entry:
# 0 3 * * * sudo /config/user-data/block-hosts.sh

# _info is a helper function for logging infos
_info() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: INFO: $*"
}
    
# _err is a helper function for logging errors 
_err() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: ERROR: $*" >&2
}

# _fatal is a helper function for logging fatals
_fatal() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: FATAL: $*" >&2
    exit 1
}

# _check_deps checks for dependencies
# in the script itself
_check_deps() {
    command -v "${DEPENDENCIES[@]}" 1>/dev/null 2>&1 || _fatal "Missing a dependency or two."
}

# _check_dir checks for the existence
# of a directory and fatals out
# if it does not
_check_dir() {
    local dir=$1
    local dir="${dir/#\~/$HOME}"

    if [[ ! -d $dir ]]; then
        _fatal "Missing directory $dir."
    fi
}

# _create_dir is similar to _check_dir
# but create a directory instead
# of a fatal
_create_dir() {
    local dir=$1
    local dir="${dir/#\~/$HOME}"

    if [[ ! -d $dir ]]; then
        _info "Missing directory $dir. Creating it now."
        mkdir -p "$dir"
    fi
}

# _check_file checks for the existence
# of a file and fatals out if it does not 
_check_file() {
    local file=$1
    local file="${file/#\~/$HOME}"

    if [[ ! -f $file ]]; then
        _fatal "Missing file $file."
    fi
}

# _create_file is similar to _check_file
# but create an empty file instead
# of a fatal
_create_file() {
    local file=$1
    local file="${file/#\~/$HOME}"

    if [[ ! -f $file ]]; then
        _info "Missing file $file. Creating an empty one now."
        touch "$file"
    fi
}

# _backup takes a backup of the last known
# configuration
_backup() {
    _info "Taking a backup of the configurations"

    # Check for files and directories
    _check_dir "$WORKSPACE" 
    _check_file "/etc/dnsmasq.d/usg-hole-blacklist-ipv4.conf"
    _check_file "/etc/dnsmasq.d/usg-hole-blacklist-ipv6.conf"

    # Delete old backup
    rm "$(readlink "@last-ipv4" 2>/dev/null)" 2>/dev/null && rm "@last-ipv4" 2>/dev/null || true
    rm "$(readlink "@last-ipv6" 2>/dev/null)" 2>/dev/null && rm "@last-ipv6" 2>/dev/null || true

    # Create new backup
    local timestamp=$(date +"%Y%m%d%H%M")
    cp -p "/etc/dnsmasq.d/usg-hole-blacklist-ipv4.conf" "$WORKSPACE/usg-hole-blacklist-ipv4-$timestamp.conf"
    cp -p "/etc/dnsmasq.d/usg-hole-blacklist-ipv6.conf" "$WORKSPACE/usg-hole-blacklist-ipv6-$timestamp.conf"
    ln -s "$WORKSPACE/usg-hole-blacklist-ipv4-$timestamp.conf" "$WORKSPACE/@last-ipv4"
    ln -s "$WORKSPACE/usg-hole-blacklist-ipv6-$timestamp.conf" "$WORKSPACE/@last-ipv6"
}


# _download downloads the blacklisted hosts
# and adds them to the dnsmasq configuration
_download() {
    _info "Downloading hosts"
    curl -# -o /tmp/hosts $RAW_HOSTS
    awk '$1 == "0.0.0.0" { print "address=/"$2"/0.0.0.0/" }' "/tmp/hosts" > "/etc/dnsmasq.d/usg-hole-blacklist-ipv4.conf"
    awk '$1 == "0.0.0.0" { print "address=/"$2"/::1/" }' "/tmp/hosts" > "/etc/dnsmasq.d/usg-hole-blacklist-ipv6.conf"
    rm /tmp/hosts
}

# _reload reloads the dnsmasq configuration
_reload() {
    _info "Reloading configuration"
    /etc/init.d/dnsmasq force-reload
}

# _uninstall removes all trails of this script
_uninstall() {
    rm "/etc/dnsmasq.d/usg-hole*"
    rm -rf "$WORKSPACE"
}

# _install installs the script
_install() {
    # Check for the workspace 
    _create_dir "$WORKSPACE"

    # Install
    local current_file="$(echo $0)"
    _create_file "$WORKSPACE/$current_file"
    if [[ $(diff "$current_file" "$WORKSPACE/$current_file") != "" ]]; then 
        _info "Installing script in $WORKSPACE/$current_file."
        cp -p "$current_file" "$WORKSPACE/$current_file"
    fi
}

_main() {
    _install
    _download
    _reload
    _backup
    _info "Done."
}

_main "$@"

