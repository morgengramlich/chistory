#!/bin/bash

# default values
interval_s=10
binary=false
help=false
log=false

# printing help
function help {
cat << EndOfMessage
chistory: saves the history of changes of a file.

Usage:
 chistory [options] file

Options:
 -s interval    interval in seconds to save file changes (default is 10 seconds)
 -l             prints hystory for a file
 -b             file is binary
            
EndOfMessage
}

# parse command line arguments
while [[ $# > 0 ]]; do
    key="$1"
    case $key in
        -s)
            interval_s="$2"
            shift 2
            ;;
        -b)
            binary=true
            shift 1
            ;;
        -h|--help)
            help=true
            shift 1
            ;;
        -l)
            log=true
            shift 1
            ;;
        *)
            file="$key"
            shift 1
            ;;
    esac
done

# printing help if needed
if [[ $help == true ]]; then
    help
    exit 0
fi

# printing error if file isn't specified
if [[ -z $file ]]; then
    echo "Error: file not specified"
    help
    exit 1
fi

# we will use hidden floder in home directory to store all data
# all data related to filename.ext will be placed incide filename_ext directory
file_dir_name=`echo "$file" | sed -E 's/[\.]+/_/g'`

# print history of changes
if [[ $log == true ]]; then
    cat ~/.chistory/${file_dir_name}.log
    exit 0
fi

mkdir -p ~/.chistory/${file_dir_name}
cp $file ~/.chistory/${file_dir_name}

# we will use lockfile later for protection, thus we need to delete it when script exits
LOCKFILE=/tmp/lock.txt
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT

# set limit for 10 seconds for functions execution
function limited_exec() {
    local limit=10
    ( 
        "$@" &
        child=$!
        trap -- "" SIGTERM
        (
            sleep $limit
            kill $child 2> /dev/null 
        ) &
        wait $child
    )
}

function save_changes() {
    local is_binary=$1
    local filename=$2
    local directory=$3
    # using hexdump for binaries
    if [[ $is_binary == true ]]; then
        diff <(hexdump ~/.chistory/${directory}/${filename}) <(hexdump $filename)
    else
        diff ~/.chistory/${directory}/${filename} $filename >> ~/.chistory/${directory}.log
    fi
    echo >> ~/.chistory/${directory}.log

    # saving modified version of a file as a new template
    rm ~/.chistory/${directory}/${filename}
    cp $filename ~/.chistory/${directory}
}

counter=0
while true; do
    sleep $interval_s

    # useing lockfile to prevent access to file from multiple inctanses of a script
    if [[ -e ${LOCKFILE} ]] && kill -0 `cat ${LOCKFILE}`; then
        continue
    fi
    # writing pid to lockfile
    echo $$ > ${LOCKFILE}

    # printing date and time of a changes snapshot
    header='@Change '`date +"%m-%d-%Y %T"`
    if [[ $counter -eq 23 ]]; then
        echo $header > ~/.chistory/${file_dir_name}.log
        counter=0
    else
        echo $header >> ~/.chistory/${file_dir_name}.log
        counter=$((counter+1))
    fi

    limited_exec save_changes $binary $file $file_dir_name
    result=$?
    if [[ $result -eq 143 ]]; then
        logger 'chistory: failed to save changes of ${file}'
    fi

    # remove lockfile
    rm -f ${LOCKFILE}
done

