#!/bin/bash
# transfer one file/directory at one trip

function USAGE() {
    echo "Usage: $routname [OPTION] src-f [others-f...] dst-f"
    echo "OPTION:"
    echo "  -h, --help     help"
    echo "  -r, --recur    recursively copy directories"
}

function name_split() {
    local fname=$1
    filename=${fname##*:}
    remote=${fname%${filename}}
    echo "\"$filename\" \"${remote%:}\""
}

function path_dname() {
    # append slash in the end of path, like a directory
    local dname=$1
    if [ x"$dname" != x"/" ]; then dname=${dname%/}/; fi
    echo "$dname"
}

function path_join() {
    local dname=`path_dname "$1"`
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

function path_quote() {
    # ~ will not work in double quote
    local paths=''
    for p in "$@"; do paths="$paths \"$path\""; done
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

function command_quote() {
    local commd=$1

    # echo "command: [$commd]" >&2

    kws='\ " $'
    for k in $kws
    do
        # echo "[$k]"
        commd=${commd//"$k"/"\\$k"}
    done
    echo "$commd"
}

# command_quote '[ -d ~/hj\ dir ] && echo "$fname_nxt" || echo ~/hj\ dir'
# exit

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

    echo "command: [$commd]"
    echo "num of layers: $num"

    local nest=0

    commd=${commd//';'/' then_do '}
    commd=${commd//'$'/'var_'}
    commd=${commd//'('/'left_q_'}
    commd=${commd//')'/'_right_q'}
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

ARGS=`getopt -o hr --long help,recur -n $0 -- "$@"`
if [ $? != 0 ]; then USAGE; exit -1; fi

eval set -- "$ARGS"
while :
do
    opt="$1"
    case "$1" in
        -h|--help) USAGE; exit;;
        -r|--recur) scp_opt='-r'; shift;;
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

if(($narg==2))
then
    scp $scp_opt "$@"
    exit
fi

file_src=${args[0]}
file_dst=${args[-1]}

echo "------------------------------------------"
echo "src file: [$file_src]"
echo "dst file: [$file_dst]"
echo "------------------------------------------"
echo

eval split_src=(`name_split "$file_src"`)
fname_src=${split_src[0]}
host_src=${split_src[1]}

eval split_dst=(`name_split "$file_dst"`)
fname_dst=${split_dst[0]}
host_dst=${split_dst[1]}

bname_src=`basename "$fname_src"`

files_rst=("${args[@]:1}")
((nrst=narg-1))

echo "------------------------------------------"
echo "src fname: [$fname_src]"
echo "src host: [$host_src]"
echo "dst fname: [$fname_dst]"
echo "dst host: [$host_dst]"
echo "basename: $bname"
echo_array "rest files" "${files_rst[@]}"
echo "number of rest: $nrst"
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

# exit

# from local to remote
if [ x"$host_src" == x ]
then
    echo "from local to remote"

    ((n=nrst-1))
    commd=''
    while :
    do
        file_nxt=${files_rst[$n]}
        eval split_nxt=(`name_split "$file_nxt"`)
        fname_nxt=${split_nxt[0]}
        host_nxt=${split_nxt[1]}
        dname_nxt=`path_dname "$fname_nxt"`

        file_nxt_2q=`path_escape_quote "$file_nxt"`
        fname_nxt_q=`path_escape "$fname_nxt"`
        dname_nxt_q=`path_escape "$dname_nxt"`

        # command to determine filename in next host
        commd_init="bname=\$(basename \"\$fname\")"
        commd_init="$commd_init; fname_nxt=\"$dname_nxt\$bname\""
        commd_init="$commd_init; echo \"fname now=[\$fname]\""
        commd_init="$commd_init; echo \"bname now=[\$bname]\""

        #command in next host
        commd_host="[ -d $fname_nxt_q ] && echo \\\"\$fname_nxt\\\""
        commd_host="$commd_host || echo \\\"$fname_nxt\\\""
        commd_host="fname_nxt=\$(ssh \"$host_nxt\" \"$commd_host\")"

        commd_fnm="$commd_init; $commd_host"
        commd_fnm="$commd_fnm; echo \"next fname=[\$fname_nxt]\""

        # scp command
        commd_scp="scp $scp_opt \"\$fname\" $file_nxt_2q"

        # assign vars in ssh
        commd_var_nxt="fname=\${fname_nxt// /'\ '}"
        # commd_var="$commd_var; echo \"new fname=[\$fname]\""
        # commd_var="$commd_var; echo \"new bname=[\$bname]\""

        if [ x"$commd" == x ]
        then
            commd=$commd_scp
        else
            # join the uppers
            commd_now="$commd_fnm; $commd_scp"

            commd_pre_q=`command_quote "$commd"`
            commd_nxt="$commd_var_nxt; $commd_pre_q"

            commd="$commd_now; ssh \"$host_nxt\" \"$commd_nxt\""
        fi

        ((n--))
        if((n<0)); then break; fi
    done

    ((nlayer=nrst-1))
    layer_command $nlayer -1 "$commd"

    echo "==================================="
    echo "begin to eval:"
    
    # bname=$bname_src
    fname=$fname_src

    echo "fname command: [$commd_fnm]"
    echo "scp command: [$commd_scp]"
    echo "var command: [$commd_scp]"
    echo "total command: [$commd]"
    # echo "bname now: [$bname]"
    echo "fname now: [$fname]"
    echo

    eval "$commd"

    exit
fi

# from remote to local
if [ x"$host_dst" == x ]
then
    echo "from remote to local"

    # command in the second remote host
    file_pre=$file_src
    fname_pre=$fname_src
    host_pre=$host_src

    file_now=${files_rst[0]}
    eval split_now=(`name_split "$file_now"`)
    fname_now=${split_now[0]}
    host_now=${split_now[1]}
    dname_now=`path_dname "$fname_now"`
    
    file_pre_q=`path_escape "$file_pre"`
    fname_now_q=`path_escape "$fname_now"`

    # command to echo filename in this host
    commd_fnm="[ -d $fname_now_q ] && echo \"$dname_now$bname_src\""
    commd_fnm="$commd_fnm || echo \"$fname_now\""

    # command to scp
    commd_scp="scp $scp_opt \"$file_pre_q\" $fname_now_q"

    # join these two
    commd="$commd_fnm; $commd_scp"

    echo "command 0: [$commd]"
    echo

    # exit

    ((n=1))
    while :
    do
        file_pre=$file_now
        fname_pre=$fname_now
        host_pre=$host_now

        file_now=${files_rst[$n]}
        eval split_now=(`name_split "$file_now"`)
        fname_now=${split_now[0]}
        host_now=${split_now[1]}
        dname_now=`path_dname "$fname_now"`

        fname_now_q=`path_escape "$fname_now"`

        # capture filename in previous host in previous command
        commd_pre_q=`command_quote "$commd"`
        echo "pre host: [$host_pre]"
        echo "command $n: [$commd]"
        echo "quoted pre command: [$commd_pre_q]"
        echo
        commd_pre="fname=\$(ssh \"$host_pre\" \"$commd_pre_q\")"
        commd_pre="$commd_pre; echo \"pre fname=[\$fname]\" >&2"

        # command for basename
        commd_bnm="bname=\$(basename \"\$fname\")"
        commd_bnm="$commd_bnm; echo \"pre bname=[\$bname]\" >&2"

        # command to echo filename in this host
        commd_fnm="[ -d $fname_now_q ] && echo \"$dname_now\$bname\""
        commd_fnm="$commd_fnm || echo \"$fname_now\""
        commd_fnm="$commd_bnm; $commd_fnm"

        # command to scp
        commd_svar="pfile_q=\"$host_pre:\${fname// /'\ '}\""
        commd_svar="$commd_svar; echo \"quoted pre file=[\$pfile_q]\" >&2"
        commd_svar="$commd_svar; echo >&2"
        commd_scp="scp $scp_opt \"\$pfile_q\" $fname_now_q"
        commd_scp="$commd_svar; $commd_scp"

        # join the uppers
        if((n==nrst-1))
        then
            commd="$commd_pre; $commd_scp"
        else
            commd="$commd_pre; $commd_fnm; $commd_scp"
        fi

        ((n++))
        if((n==nrst)); then break; fi
    done

    # ((nlayer=nrst-1))
    # layer_command $nlayer 2 "$commd"

    echo "==================================="
    echo "begin to eval:"
    
    # bname=$bname_src
    # fname=$fname_src

    echo "fname command: [$commd_fnm]"
    echo "scp command: [$commd_scp]"
    echo "var command: [$commd_scp]"
    echo "total command: [$commd]"
    # echo "bname now: [$bname]"
    # echo "fname now: [$fname]"
    echo

    eval "$commd"

    exit
fi
