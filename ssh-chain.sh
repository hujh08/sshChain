#!/bin/bash

# execute a command in remote, through a chain of hosts

echo "number of args: $#"

function USAGE() {
    echo "Usage: $routname [OPTION] src [others...] command"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -a, --all      execute command in all hosts along chain"
}

# parse options
exec_all=''

ARGS=`getopt -o ha --long help,all -n $0 -- "$@"`
if [ $? != 0 ]; then USAGE; exit -1; fi

eval set -- "$ARGS"
while :
do
    opt="$1"
    case "$1" in
        -h|--help) USAGE; exit;;
        -a|--all) exec_all='y'; shift;;
        --) shift; break;;
    esac
    # chain_opt="$chain_opt $opt"
done

# exit

routname=`basename $0`
narg=$#
args=("$@")

echo "=====================================" >&2
echo "chain ssh run......" >&2
echo "narg: $narg" >&2
echo "chain: ${args[@]::${#args[@]}-1}" >&2
echo "command: ${args[-1]}" >&2
echo >&2

if(($narg<2))
then
    echo "no enough arguments" >&2
    USAGE >&2
    exit -1
fi

hosts=("${args[@]::$narg-1}")
nhost=${#hosts[@]}
commd=${args[-1]}
commd_init="$commd"

host_nxt=${hosts[0]}

echo "number of hosts: $nhost"
echo "next host: $host_nxt"

# nested command
((n=nhost-1))
while :
do
    if((n==0)); then break; fi
    host=${hosts[$n]}

    commd=${commd//'\'/'\\'}
    commd=${commd//'"'/'\"'}
    commd="ssh $host \"$commd\""

    if [ "$exec_all" ]
    then
        commd="$commd_init; $commd"
    fi
    
    ((n--))
done

echo "command: [$commd]"
echo

ssh $host_nxt "$commd"
