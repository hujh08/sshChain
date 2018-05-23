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
    echo "\"$filename\" \"${remote%:}\""
}

function path_join() {
    local dname=$1
    if [ x"$dname" != x"/" ]; then dname=${dname%/}/; fi
    shift

    local fnames=''
    for bname in "$@"
    do
        local path=`path_escape "$dname$bname"`
        fnames="$fnames $path"
    done
    echo "${fnames# }"
    # local basename=$2
    # echo "${dirname%/}/${basename}"
}

function path_escape() {
    # path used in quoted
    # ~ will not work in double quote
    local paths=''
    for p in "$@"
    do
        local path=${p//' '/'\ '}
        paths="$paths $path"
    done
    echo "${paths# }"
}

function path_escape_quote() {
    # double quoted used in scp's remote machine
    local paths=''
    for p in "$@"
    do
        local path=${p//' '/'\ '}
        paths="$paths \"$path\""
    done
    echo "${paths# }"
}

function ext_basenames() {
    local host_src=$1
    shift

    # echo "ext_basenames" >&2
    # echo "narg: $#" >&2
    # echo "src host: [$host_src]" >&2

    local basenames=''
    for nxt_file in "$@"
    do
        eval spath_split=(`name_split "$nxt_file"`)
        host=${spath_split[1]}
        path=${spath_split[0]}

        # echo "host: $host" >&2

        if [ x"$host" != x"$host_src" ]; then break; fi

        # echo $nxt_file >&2

        local basename=`basename "$path"`
        basenames="$basenames \"$basename\""
    done
    echo "${basenames# }"
}

function echo_array() {
    local head=$1
    shift

    echo -n "$head:"
    for i in "$@"; do echo -n " [$i]"; done
    echo
}

function layer_command() {
    echo 'layer of command'
    local num=$1
    local cid=$2
    local commd=$3

    echo "num of layers: $num"

    local nest=0

    commd=${commd//';'/' then '}
    commd=${commd//'||'/' otherwise '}
    while :
    do
        eval set -- "$commd"
        args=("$@")
        echo ">>>===layer: $nest"
        echo "    narg: $#"
        echo "    commd: [${commd}]"
        for i in "$@"
        do
            echo "    $i"
        done
        echo


        ((nest++))
        if [ $num == $nest ]; then break; fi

        commd=${args[$cid]}
        echo "    next commd: [${commd}]"
        echo

    done
}

routname=`basename "$0"`

# original args
echo "==================================="
echo "$0 running......"
echo
echo "original args"
echo "    routine name: $routname"
echo "    narg: $#"
echo "    args: $@"
echo

# parse options
scp_opt=''  # option used in scp
dir_force=''  # whether force to mkdir

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
done

narg=$#
args=("$@")

echo "after option parsed"
echo "    narg: $narg"
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

file_src=${args[0]}
dire_dst=${args[-1]}  # must be directory

echo "------------------------------------------"
echo "src file: [$file_src]"
echo "dst dire: [$dire_dst]"
echo "------------------------------------------"
echo

eval split_src=(`name_split "$file_src"`)
fname_src=${split_src[0]}
host_src=${split_src[1]}

eval split_dst=(`name_split "$dire_dst"`)
dname_dst=${split_dst[0]}  # must be directory
host_dst=${split_dst[1]}

basename=`basename "$fname_src"`

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
eval basenames=(`ext_basenames "$host_src" "${args[@]}"`)

nsrc=${#basenames[@]}
files_src=("${args[@]::$nsrc}")

echo "number of src: $nsrc"
echo_array "basenames" "${basenames[@]}"
echo_array "src files" "${files_src[@]}"

dires_rst=("${args[@]:${#basenames[@]}}")
((nrest=narg-nsrc))

echo "number of rest dirs: $nrest"
echo_array "rest dirs" "${dires_rst[@]}"
echo

eval files_dst=(`path_join "$dname_dst" "${basenames[@]}"`)
echo "number of files in dest: ${#files_dst[@]}"
echo_array "files in dest" "${files_dst[@]}"
echo

# exit

if(($nrest==1))
then
    echo "end of chain"
    scp $scp_opt "${files_src[@]}" "$dire_dst"
    echo '|2'
    exit
fi

# from local to remote
if [ x"$host_src" == x ]
then
    echo "from local to remote"

    dire_now=${dires_rst[-1]}
    eval split_now=(`name_split "$dire_now"`)
    dname_now=${split_now[0]}
    host_now=${split_now[1]}

    commd=''
    ((n=nrest-2))
    while :
    do
        if((n<0)); then break; fi
        dire_nxt=$dire_now
        dname_nxt=$dname_now
        host_nxt=$host_now

        dire_now=${dires_rst[$n]}
        eval split_now=(`name_split "$dire_now"`)
        dname_now=${split_now[0]}
        host_now=${split_now[1]}
        fnames_now=`path_join "$dname_now" "${basenames[@]}"`

        dire_nxt_q=`path_escape_quote "$dire_nxt"`
        commd_scp="scp $scp_opt $fnames_now $dire_nxt_q"
        if [ "$dir_force" ]
        then
            echo 'mkdir'
            dname_nxt_q=`path_escape "$dname_nxt"`
            commd_mk="[ -d $dname_nxt_q ] || mkdir -p $dname_nxt_q"

            commd_mk=${commd_mk//'\'/'\\'}
            commd_mk=${commd_mk//'"'/'\"'}
            commd_scp="ssh \"$host_nxt\" \"$commd_mk\"; $commd_scp"
        fi
        
        if [ x"$commd" != x ]
        then
            commd=${commd//'\'/'\\'}
            commd=${commd//'"'/'\"'}
            commd="ssh \"$host_nxt\" \"$commd\""
        fi

        commd="$commd_scp; $commd"
        ((n--))
    done

    ((nlayer=nrest-1))
    layer_command $nlayer -1 "$commd"

    echo "================> begin to ssh <================"
    echo "host: $host_now"
    echo "command: [$commd]"
    echo "dire now: [$dire_now]"
    echo "host now: [$host_now]"
    echo "dname now: [$dname_now]"
    echo
    if [ "$dir_force" ]
    then
        echo 'mkdir'
        dname_now_q=`path_escape "$dname_now"`
        commd_mk="[ -d $dname_now_q ] || mkdir -p $dname_now_q"
        ssh $host_now "$commd_mk"
    fi
    dire_now_q=`path_escape "$dire_now"`
    scp $scp_opt "${files_src[@]}" "$dire_now_q"
    ssh $host_now "$commd"
fi

# from remote to local
if [ x"$host_dst" == x ]
then
    echo "from remote to local"

    dire_now=${dires_rst[0]}
    eval split_now=(`name_split "$dire_now"`)
    dname_now=${split_now[0]}
    host_now=${split_now[1]}

    # quoted files' name
    fnames_src=`path_escape_quote "${files_src[@]}"`
    dname_now_q=`path_escape "$dname_now"`
    commd="scp $scp_opt $fnames_src $dname_now_q"
    if [ "$dir_force" ]
    then
        echo 'mkdir'
        commd_mk="[ -d $dname_now_q ] || mkdir -p $dname_now_q"
        commd="$commd_mk; $commd"
    fi

    ((n=1))
    while :
    do
        if((n==nrest)); then break; fi
        dire_nxt=$dire_now
        dname_nxt=$dname_now
        host_nxt=$host_now
        eval fnames_nxt=(`path_join "$dire_nxt" "${basenames[@]}"`)
        fnames_nxt_q=`path_escape_quote "${fnames_nxt[@]}"`

        dire_now=${dires_rst[$n]}
        eval split_now=(`name_split "$dire_now"`)
        dname_now=${split_now[0]}
        host_now=${split_now[1]}

        dname_now_q=`path_escape "$dname_now"`
        commd_scp="scp $scp_opt $fnames_nxt_q $dname_now_q"
        if [ "$dir_force" ]
        then
            echo 'mkdir'
            commd_mk="[ -d $dname_now_q ] || mkdir -p $dname_now_q"
            commd_scp="$commd_mk; $commd_scp"
        fi

        commd=${commd//'\'/'\\'}
        commd=${commd//'"'/'\"'}
        commd="ssh \"$host_nxt\" \"$commd\"; $commd_scp"
        ((n++))
    done

    layer_command $nrest 2 "$commd"
    
    echo "================> begin to ssh <================"
    echo "host: $host_now"
    echo "command: [$commd]"
    echo
    eval "$commd"
fi
