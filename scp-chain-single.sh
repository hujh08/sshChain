#!/bin/bash
# transfer one file/directory at one trip

function USAGE() {
    echo "Usage: $routname [OPTION] src-f [others-d...] dst-d"
    echo "  src-f: must be file"
    echo "  others-d, dst-d: must be directory"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -r, --recur    recursively copy directories"
    echo "  -f, --fore     force to mkdir if not exist"
}

function name_split() {
    local fname=$1
    filename=${fname##*:}
    remote=${fname%${filename}}
    echo "$filename ${remote%:}"
}

function path_join() {
    local dirname=$1
    local basename=$2
    echo "${dirname%/}/${basename}"
}

function _exec_host() {
    local commd=$1
    local host=$2
    if [ x"$host" == x ]
    then
        #echo "commd: $commd" >&2
        eval "$commd"
    else
        ssh $host "$commd"
    fi
}

# function _file_test() {
#     local test=$1
#     local path=$2
#     local host=$3

#     _exec_host "[ $test $path ] && echo yes" $host
# }

function mkdir_ifnotd() {
    local spath_split=(`name_split $1`)
    local path=${spath_split[0]}
    local host=${spath_split[1]}

    _exec_host "[ -d $path ] || mkdir -p $path" $host
}

function doscp() {
    local src=$1
    local dst=$2

    echo "===> do: scp $src $dst <==="

    if [ x"$dir_force" ]
    then
        mkdir_ifnotd $dst || exit -1
    fi
    scp $scp_opt $src $dst || exit -1
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
scp_opt=''  # option used in scp
dir_force=''  # whether force to mkdir
chain_opt=''

ARGS=`getopt -o hrf --long help,recur,force -n $0 -- "$@"`
if [ $? != 0 ]; then USAGE; exit -1; fi

eval set -- "$ARGS"
while :
do
    opt="$1"
    case "$1" in
        -h|--help) USAGE; exit;;
        -r|--recur) scp_opt='-r'; shift;;
        -f|--force) dir_force='y'; shift;;
        --) shift; break;;
    esac
    chain_opt="$chain_opt $opt"
done

# doscp

# exit

routname=`basename $0`
narg=$#
args=($@)

routine_host="~/$routname"

echo "====================================="
echo "chain scp run......"
echo "narg: $narg"
echo "scp opt: [$scp_opt]"
echo "dir force: [$dir_force]"
echo "chain: ${args[@]}"
echo

if(($narg<2))
then
    echo "no enough arguments"
    USAGE
    exit -1
fi

src_file=${args[0]}
dst_dire=${args[-1]}  # must be directory

echo "------------------------------------------"
echo "src file: $src_file"
echo "dst file: $dst_dire"
echo "------------------------------------------"
echo

split_src=(`name_split $src_file`)
fname_src=${split_src[0]}
host_src=${split_src[1]}

split_dst=(`name_split $dst_dire`)
dname_dst=${split_dst[0]}  # must be directory
host_dst=${split_dst[1]}

basename=`basename $fname_src`

echo "------------------------------------------"
echo "src fname: [$fname_src]"
echo "src host: [$host_src]"
echo "dst dir: [$dname_dst]"
echo "dst host: [$host_dst]"
echo "basename: $basename"
echo "------------------------------------------"
echo

if [ x"$host_src" == x -a x"$host_dst" == x ]
then
    echo "Error: both src and dst are local"
    exit -1
fi

if [ x"$host_src" != x -a x"$host_dst" != x ]
then
    echo "Error: both src and dst are remote"
    exit -1
fi

if(($narg==2))
then
    doscp $src_file $dst_dire
    exit
fi

# from local to remote
if [ x"$host_src" == x ]
then
    echo "from local to remote"
    nxt_dire=${args[1]}
    args=(${args[@]:2})

    split_nxt=(`name_split $nxt_dire`)
    dname_nxt=${split_nxt[0]}
    host_nxt=${split_nxt[1]}

    if [ x"$host_nxt" == x ]
    then
        echo "Error: both src and next are local"
        exit -1
    fi

    # filename in next remote
    fname_nxt=`path_join $dname_nxt $basename`

    echo "@@@@@@@@@@@@@>>>> next scp <<<<@@@@@@@@@@@@@"
    echo "host: $host_nxt"
    echo "routine_host: $routine_host"
    echo "remote fname: $fname_nxt"
    echo "remote dname: $dname_nxt"
    echo "rest chain: ${args[@]}"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo

    # from src(local) to next
    doscp $fname_src $nxt_dire

    # from next to dst
    commd="$routine_host $chain_opt $fname_nxt ${args[@]}"
    ssh $host_nxt "$commd" || exit -1
    exit
fi

# from remote to local
if [ x"$host_dst" == x ]
then
    echo "from remote to local"
    nxt_dire=${args[-2]}
    args=(${args[@]::${#args[@]}-2})

    split_nxt=(`name_split $nxt_dire`)
    dname_nxt=${split_nxt[0]}  # must be directory
    host_nxt=${split_nxt[1]}

    if [ x"$host_nxt" == x ]
    then
        echo "Error: both dest and next are local"
        exit -1
    fi

    # filename in next remote
    nxt_file=`path_join $nxt_dire $basename`

    echo "@@@@@@@@@@@@@>>>> next scp <<<<@@@@@@@@@@@@@"
    echo "host: $host_nxt"
    echo "routine_host: $routine_host"
    echo "remote fname: $nxt_file"
    echo "remote dname: $dname_nxt"
    echo "rest chain: ${args[@]}"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo

    # from src to next
    commd="$routine_host $chain_opt ${args[@]} $dname_nxt"
    ssh $host_nxt "$commd" || exit -1

    # from next to dst(local)
    doscp $nxt_file $dname_dst

    exit
fi