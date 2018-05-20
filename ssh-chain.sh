#!/bin/bash

# execute a command in remote, through a chain of hosts

echo "number of args: $#"

function USAGE() {
    echo "Usage: $routname [OPTION] src [others...] command"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -a, --all      execute command in all hosts along chain"
}

# isd=$(file_test_remote $2 $1)
# if [ x"$isd" != x ]
# then
#     echo "yes for $1"
# else
#     echo "no for $1"
# fi

# exit

# doscp

# parse options
exec_all=''
chain_opt=''

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
    chain_opt="$chain_opt $opt"
done

# doscp

# exit

routname=`basename $0`
narg=$#
args=("$@")

# echo "narg: $narg"
# echo "narr: ${#args[@]}"
# exit

routine_host="~/$routname"

echo "=====================================" >&2
echo "chain ssh run......" >&2
echo "narg: $narg" >&2
echo "chain opt: [$chain_opt]" >&2
echo "chain: ${args[@]::${#args[@]}-1}" >&2
echo "command: ${args[-1]}" >&2
echo >&2

if(($narg<2))
then
    echo "no enough arguments" >&2
    USAGE >&2
    exit -1
fi

chain=("${args[@]::${#args[@]}-1}")
remote=${args[0]}
commd=${args[-1]}

args=("${args[@]:1}")
chain=("${chain[@]:1}")

if [ $narg == 2 ]
then
    echo end of chain: $remote
    ssh $remote "$commd"
    echo
    exit -1
fi

commd_remote="$routine_host $chain_opt ${chain[@]} \"$commd\""

if [ "$exec_all" ]
then
    echo exec on $remote
    commd_remote="$commd; $commd_remote"
fi

ssh $remote "$commd_remote"