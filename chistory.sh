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
    if [[ $counter -eq 23 ]]; then
        echo '@Change '`date +"%m-%d-%Y %T"` > ~/.chistory/${file_dir_name}.log
        counter=0
    else
        echo '@Change '`date +"%m-%d-%Y %T"` >> ~/.chistory/${file_dir_name}.log
        counter=$((counter+1))
    fi
    
    # using hexdump for binaries
    if [[ $binary == true ]]; then
        diff <(hexdump ~/.chistory/${file_dir_name}/${file}) <(hexdump $file)
    else
        diff ~/.chistory/${file_dir_name}/${file} $file >> ~/.chistory/${file_dir_name}.log
    fi
    
    echo >> ~/.chistory/${file_dir_name}.log
    # saving modified version of a file as a new template
    rm ~/.chistory/${file_dir_name}/${file}
    cp $file ~/.chistory/${file_dir_name}

    # remove lockfile
    rm -f ${LOCKFILE}
done

