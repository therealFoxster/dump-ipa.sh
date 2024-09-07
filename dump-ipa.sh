#!/bin/zsh

program=$0

function usage() {
    echo "Usage: $program [-h] [-H <ip>] [-u <user>] [-o <output_directory>] <app_name>"
    echo "Options:"
    echo "  -h      Show this help message and exit"
    echo "  -H      IP address of the remote device"
    echo "  -u      Username of the remote device"
    echo "  -o      Output directory (default: ~/Downloads)"
    echo "Note: -H (IP address) and -u (username) options are required if .env file is not present."
}

function error() {
    echo "Error: $1"
    if [[ -n $2 ]]; then
        usage
    fi
    exit 1
}

function find_and_decrypt() {
    local appdecrypt="/tmp/appdecrypt"
    local input=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local temp
    local path
    local name
    local version
    local bundle_id

    for dir in /private/var/containers/Bundle/Application/*; do
        name=$(echo "$dir"/*.app | tr '\n' '\0' | xargs -0 -n 1 basename)
        name="${name%.*}" # Remove ".app"
        temp=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        if [[ $temp == $input ]]; then
            version=$(plutil -key bundleVersion "$dir/iTunesMetadata.plist")
            bundle_id=$(plutil -key softwareVersionBundleId "$dir/iTunesMetadata.plist")
            path=$dir
            echo -n "name: $name\n"
            echo -n "version: $version\n"
            echo -n "bundle_id: $bundle_id\n"
            echo -n "path: $path\n"
            break
        fi
    done

    if [[ -f $appdecrypt ]]; then
        $appdecrypt "$path" "/tmp" >/dev/null
        if [[ -d "/tmp/Payload" ]]; then
            cd "/tmp/Payload"
            rm *.plist
            cd .. # /tmp/
            zip -rq "${name}_${version}.ipa" "Payload"
        else
            echo "Error: Payload not found"
        fi
    else
        echo "Error: appdecrypt not found"
    fi
}

# If no arguments are passed, show usage
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

# Setting OPTIND to 1 to allow more than one function invocations
# (https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#index-OPTIND)
OPTIND=1 # Start reading opts from first arg
while getopts "hH:u:o:" opt; do
    case "${opt}" in
    h)
        usage
        exit 0
        ;;
    H) ip=${OPTARG} ;;
    u) user=${OPTARG} ;;
    o) output=${OPTARG} ;;
    *)
        usage
        exit 1
        ;; # Handle invalid options
    esac
done

env=$(dirname "$0")/.env
if [[ -f $env ]]; then
    source "$env"
elif [[ -z $ip ]]; then
    error "Missing <ip>." 1
elif [[ -z $user ]]; then
    error "Missing <user>." 1
fi

if [[ -z $output ]]; then
    output=~/Downloads
fi

app_name=${@:$OPTIND}
if [[ -z $app_name ]]; then
    error "Missing <app_name>." 1
fi

if [[ ! -f ~/appdecrypt/appdecrypt ]]; then
    error "appdecrypt not found in ~/appdecrypt."
fi

echo "Sending appdecrypt to remote device..."
scp ~/appdecrypt/appdecrypt "$user@$ip:/tmp"
if [[ $? -ne 0 ]]; then
    error "Unable to send appdecrypt to remote device."
fi

echo "Finding and decrypting $app_name (this may take a while)..."
app_info=$(
    ssh "$user@$ip" 'bash -s' <<SRC
  $(declare -f find_and_decrypt)
  find_and_decrypt "$app_name"
SRC
)

if [[ -z $app_info ]]; then
    error "Unable to find or decrypt $app_name.app."
fi

err=$(echo -e "$app_info" | grep error)

if [[ -n $err ]]; then
    error "$(echo "$err" | cut -d':' -f2)"
    exit 1
fi

app_name=$(echo -e "$app_info" | grep name | awk '{print $2}')
version=$(echo -e "$app_info" | grep version | awk '{print $2}')
filename="${app_name}_${version}.ipa"

echo "Downloading $filename..."
scp "$user@$ip:/tmp/$filename" "$output"
if [[ $? -eq 0 ]]; then
    echo "Downloaded to ${output}/${filename}."
else
    rm -f "$output/$filename"
    error "Failed to download $filename."
fi
