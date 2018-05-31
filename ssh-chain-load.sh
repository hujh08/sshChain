#!/bin/bash

# load remote host through a chain of hosts

echo "number of args: $#"

function USAGE() {
    echo "Usage: $routname [OPTION] [others...] dst"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -X/Y           untrusted/trusted X11 forwarding"
}

# parse options
ssh_opt=''
pt_opt='-tt'  # Force pseudo-terminal allocation

ARGS=`getopt -o hXY --long help -n $0 -- "$@"`
if [ $? != 0 ]; then USAGE; exit -1; fi

eval set -- "$ARGS"
while :
do
    opt="$1"
    case "$1" in
        -h|--help) USAGE; exit;;
        -X|-Y) ssh_opt="$ssh_opt $1"; shift;;
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
echo "chain: ${args[@]}" >&2
echo "ssh options: $ssh_opt"
echo >&2

if(($narg<1))
then
    echo "no enough arguments" >&2
    USAGE >&2
    exit -1
fi

hosts=("${args[@]}")
nhost=${#hosts[@]}

if(($nhost==1))
then
    echo 'only one host'
    ssh $ssh_opt ${hosts[0]}
    exit
fi

host_nxt=${hosts[0]}
host_dst=${hosts[-1]}

echo "number of hosts: $nhost"
echo "next host: $host_nxt"
echo "hosts: ${hosts[@]}"
echo "destinate host: $host_dst"

commd="ssh $ssh_opt $host_dst"
ssh_opt="$ssh_opt $pt_opt"
((n=nhost-2))
while :
do
    if((n<0)); then break; fi
    host=${hosts[$n]}

    commd=${commd//'\'/'\\'}
    commd=${commd//'"'/'\"'}
    commd="ssh $ssh_opt $host \"$commd\""

    ((n--))
done

echo "command: [$commd]"
echo

# echo 'parse command'
# ./ssh-commd-parser.py "$commd"
# echo

echo "======================================================"
echo "begin to ssh"
eval "$commd"
