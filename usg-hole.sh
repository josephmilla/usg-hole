#!/usr/bin/env bash

set -e

readonly WORKSPACE="/etc/usg-hole"
declare -a BLACKLISTS=(
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"
    "https://mirror1.malwaredomains.com/files/justdomains"
    "http://sysctl.org/cameleon/hosts"
    "https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
    "https://hosts-file.net/ad_servers.txt"
)

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

    local ipv4_list
    local ipv6_list
    ipv4_list="/etc/dnsmasq.d/01-usg-hole-blacklist-ipv4.conf"
    ipv6_list="/etc/dnsmasq.d/02-usg-hole-blacklist-ipv6.conf"
    _check_file "$ipv4_list"
    _check_file "$ipv6_list"

    # Delete old backup
    rm "$(readlink "@last-ipv4" 2>/dev/null)" 2>/dev/null && rm "@last-ipv4" 2>/dev/null || true
    rm "$(readlink "@last-ipv6" 2>/dev/null)" 2>/dev/null && rm "@last-ipv6" 2>/dev/null || true

    # Create new backup
    local timestamp
    local ipv4_backup_list
    local ipv6_backup_list

    timestamp=$(date +"%Y%m%d%H%M")
    ipv4_backup_list="$WORKSPACE/usg-hole-blacklist-ipv4-$timestamp.conf"
    ipv6_backup_list="$WORKSPACE/usg-hole-blacklist-ipv6-$timestamp.conf"

    cp -p "$ipv4_list" "$ipv4_backup_list" 
    cp -p "$ipv6_list" "$ipv6_backup_list" 
    ln -s "$ipv4_backup_list" "$WORKSPACE/@last-ipv4"
    ln -s "$ipv6_backup_list" "$WORKSPACE/@last-ipv6"
}

# _download downloads the blacklisted hosts
# and adds them to the dnsmasq configuration
_download() {
    _info "Downloading hosts"
    echo > "/tmp/hosts"
    
    # Download hosts from sources
    for i in "${BLACKLISTS[@]}"; do
        curl -# "$i" > "/tmp/hosts"
    done

    # Sort and get the unique ones
    cat "/tmp/hosts" | sort | uniq > "/tmp/hosts.tmp"
    mv "/tmp/hosts.tmp" "/tmp/hosts"

    awk '{ 
        if ($1 == "0.0.0.0" || $1 == "127.0.0.1") 
            print "address=/"$2"/0.0.0.0/"
        else 
            print "address=/"$1"/0.0.0.0/" 
    }' "/tmp/hosts" > "/etc/dnsmasq.d/01-usg-hole-blacklist-ipv4.conf"

    awk '{ 
        if ($1 == "0.0.0.0" || $1 == "127.0.0.1") 
            print "address=/"$2"/::1/"
        else 
            print "address=/"$1"/::1/" 
    }' "/tmp/hosts" > "/etc/dnsmasq.d/01-usg-hole-blacklist-ipv6.conf"

    rm /tmp/hosts
}

# _reload reloads the dnsmasq configuration
_reload() {
    _info "Reloading configuration"
    /etc/init.d/dnsmasq force-reload
}

# _uninstall removes all trails of this script
_uninstall() {
    rm "/etc/dnsmasq.d/*usg-hole*"
    rm -rf "$WORKSPACE"
}

# _install installs the script
_install() {
    # Check for the workspace 
    _create_dir "$WORKSPACE"

    # Install
    local current_file
    current_file="$(echo $0)"
    _create_file "$WORKSPACE/$current_file"
    if [[ $(diff "$current_file" "$WORKSPACE/$current_file") != "" ]]; then 
        _info "Installing script in $WORKSPACE/$current_file."
        cp -p "$current_file" "$WORKSPACE/$current_file"
    fi
}

# _done just prints "Done
_done() {
    _info "Done"
    exit 0
}

_main() {
    _install
    _download
    _reload
    _backup
    _done
}

_main "$@"

