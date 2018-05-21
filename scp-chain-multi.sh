#!/bin/bash

function USAGE() {
    echo "Usage: $routname [OPTION] src-f[s] [others-d...] dst-d"
    echo "  src-fs: must be file, can be files"
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
    shift

    for bname in "$@"
    do
        echo -n "${dirname%/}/${bname} "
    done
    # local basename=$2
    # echo "${dirname%/}/${basename}"
}

function ext_basenames() {
    local host_src=$1
    shift

    local basenames=''
    for nxt_file in "$@"
    do
        spath_split=(`name_split $nxt_file`)
        host=${spath_split[1]}
        path=${spath_split[0]}

        if [ x"$host" != x"$host_src" ]; then break; fi

        #echo $nxt_file >&2

        local basename=`basename $path`
        basenames="$basenames $basename"
    done
    echo $basenames
}

function ssh_exec() {
    echo "exec ssh" >&2
    local host="$1"
    local commd="$2"
    #ssh $@ || exit -1
    echo "    narg: ${#args[@]}" >&2
    echo "    args: $@" >&2
    echo "    host: $host" >&2
    echo "    command: $commd" >&2
    eval "$commd" || exit -1
}

function _exec_host() {
    local commd=$1
    local host=$2
    if [ x"$host" == x ]
    then
        #echo "commd: $commd" >&2
        eval "$commd"
    else
        ssh_exec $host "$commd"
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

function exec_scp() {
    local args=("$@")
    local dst=${args[-1]}

    echo "===> exec: scp $scp_opt ${args[@]} <==="
    echo "    narg: $#"
    echo "    args: ${args[@]}"
    echo "    dst: $dst"
    echo "    scp opt: [$scp_opt]"
    echo "    dir force: [$dir_force]"

    if [ "$dir_force" ]
    then
        echo '    mkdir'
        # mkdir_ifnotd $dst || exit -1
    else
        echo '    no mkdir'
    fi

    # scp $scp_opt ${args[@]} || exit -1
    echo '|1'
    return
}

routname=`basename $0`
routine_host="./$routname"
# routine_host="~/$routname"

# original args
echo "==================================="
echo "$0 running......"
echo
echo "original args"
echo "    local rout: $routname"
echo "    remote rout: $routine_host"
echo "    narg: $#"
echo "    args: $@"
echo

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

narg=$#
args=("$@")

echo "after option parsed"
echo "    narg: $narg"
echo "    chain opt: [$chain_opt]"
echo "    scp opt: [$scp_opt]"
echo "    dir force: [$dir_force]"
echo "    args: ${args[@]}"
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

# ext_basenames "$host_src" ${args[@]:1}
basenames_rest=`ext_basenames "$host_src" ${args[@]:1}`
basenames=($basename $basenames_rest)

nsrc=${#basenames[@]}
src_files=(${args[@]::$nsrc})

echo "number of src: $nsrc"
echo "basenames: ${basenames[@]}"
echo "src files: ${src_files[@]}"

rst_dires=(${args[@]:${#basenames[@]}})
((nrest=narg-nsrc))

echo "number of rest dirs: $nrest"
echo "rest dirs: ${rst_dires[@]}"
echo

files_dst=(`path_join $dname_dst ${basenames[@]}`)
echo "number of files in dest: ${#files_dst[@]}"
echo "files in dest: ${files_dst[@]}"

#exit

if(($nrest==1))
then
    echo "end of chain"
    exec_scp ${src_files[@]} $dst_dire
    echo '|2'
    exit
fi

# from local to remote
if [ x"$host_src" == x ]
then
    echo "from local to remote"
    nxt_dire=${rst_dires[0]}
    args=(${rst_dires[@]:1})

    split_nxt=(`name_split $nxt_dire`)
    dname_nxt=${split_nxt[0]}
    host_nxt=${split_nxt[1]}

    if [ x"$host_nxt" == x ]
    then
        echo "Error: both src and next are local"
        exit -1
    fi

    # filename in next remote
    fnames_nxt=(`path_join $dname_nxt ${basenames[@]}`)

    echo "@@@@@@@@@@@@@>>>> next scp <<<<@@@@@@@@@@@@@"
    echo "host: $host_nxt"
    echo "routine_host: $routine_host"
    echo "remote fname: ${fnames_nxt[@]}"
    echo "remote dname: $dname_nxt"
    echo "rest chain: ${args[@]}"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo

    # from src(local) to next
    exec_scp ${src_files[@]} $nxt_dire

    # from next to dst
    commd="$routine_host $chain_opt ${fnames_nxt[@]} ${args[@]}"
    ssh_exec $host_nxt "$commd"
    echo '|3'
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
    nxt_files=(`path_join $nxt_dire ${basenames[@]}`)

    echo "@@@@@@@@@@@@@>>>> next scp <<<<@@@@@@@@@@@@@"
    echo "host: $host_nxt"
    echo "routine_host: $routine_host"
    echo "remote fname: ${nxt_files[@]}"
    echo "remote dname: $dname_nxt"
    echo "rest chain: ${args[@]}"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo

    # from src to next
    commd="$routine_host $chain_opt ${args[@]} $dname_nxt"
    ssh_exec $host_nxt "$commd"

    # from next to dst(local)
    exec_scp ${nxt_files[@]} $dname_dst

    exit
fi