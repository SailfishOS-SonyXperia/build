#!/bin/sh
#
# Upload droid-hal packages

set -e


error() {
    echo "$@" >&2
}

move()
# improved mv to detect if argument is a symlink
{
    # file = $1
    # target = $2
    if [ -L "$1" ] ; then
	mv "$(readlink "$1" )" "$2"
	rm "$1"
    else
	mv "$1" "$2"
    fi
}

move_dry()
{
    local err_count=0

    while [ ! $# = 0 ] ; do
        if [ -L "$1" ] ; then
            if [ ! -e "$(readlink "$1" )" ] ; then
                error "cannot stat '$1': No such file or directory"
                err_count=$((err_count+1))
            fi
        else
            if [ ! -e "$1" ] ; then
                error "cannot stat '$1': No such file or directory"
                err_count=$((err_count+1))
            fi
        fi
        shift
    done

    return $err_count
}



usage() {
    cat <<EOF
usage: upload.hal.sh [options] packages

options:
-d      OBS package directory
-k      Keep copy OBS package that is checked out
-m      Commit message
-P      OBS Project to upload to
-p      OBS Package to checkout

-h      Show this help

EOF
}


while getopts hkd:m:p:P: arg ; do
    case $arg in
        d) obs_package_dir=$OPTARG; keep=t;;
        k) keep=t ;;
        m) commit_message=$OPTARG;;
        P) obs_project=$OPTARG;;
        p) obs_package=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done

obs_default_opts="-A $obs_api_url"

shift $(( $OPTIND - 1 ))

if [ -d "$obs_project" ] ; then
    cd "$obs_project"
    obs_package_dir="$obs_package"
    keep=t
fi
if [ ! -e "$obs_package_dir" ] ; then
    osc co "$obs_project" "$obs_package" -o "$obs_package_dir"
else
    (
        cd "$obs_package_dir" || exit $?
        osc up
    )
fi


if [ -z "$obs_package_dir" ]; then
    obs_package_dir=$PWD/droid_hal
fi

cd "$obs_package_dir" || exit $?

# Clean up old RPMs
rm -rf -- *.rpm

while [ ! $# -eq 0 ] ; do
    move "$1" "$obs_package_dir"
    osc add "$(basename "$1")"
    shift
done

osc commit -m"$commit_message"

if [ ! $keep ] ;then
    rm -rf -- "$obs_package_dir"
fi
