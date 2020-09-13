#!/bin/bash

# execute a command in remote, through a chain of hosts

echo "number of args: $#"

function USAGE() {
    echo "Usage: $routname [OPTION] src [others...] command"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -a, --all      execute command in all hosts along chain"
}

function host_split() {
    local host=$1
    # url and port, format xxx.xxx.xxx.xxx[pxxx]
    up=${host##*@}   # url and port
    arr_up=(${up/p/ })
    port=${arr_up[1]}
    host=${host%p${port}}
    echo "\"$host\" \"$port\""
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

eval arr_nxt=(`host_split "${hosts[0]}"`)
host_nxt=${arr_nxt[0]}
port_nxt=${arr_nxt[1]}

echo "number of hosts: $nhost"
echo "next host: $host_nxt"

# port
if [ -z "$port_nxt" ]
then
    ssh_nxt=ssh
else
    ssh_nxt="ssh -p $port_nxt"
    echo "next port: $port_nxt"
fi

# nested command
((n=nhost-1))
while :
do
    if((n==0)); then break; fi
    host=${hosts[$n]}
    eval arr=(`host_split "$host"`)
    host=${arr[0]}
    port=${arr[1]}

    # port
    if [ -z "$port" ]
    then
        ssh=ssh
    else
        ssh="ssh -p $port"
    fi
    
    # command
    commd=${commd//'\'/'\\'}
    commd=${commd//'"'/'\"'}
    commd="$ssh $host \"$commd\""

    if [ "$exec_all" ]
    then
        commd="$commd_init; $commd"
    fi
    
    ((n--))
done

echo "command: [$commd]"
echo

$ssh_nxt $host_nxt "$commd"
