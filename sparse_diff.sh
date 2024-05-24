#!/bin/sh
# Diff two sparse files by converting them to regular images and mounting them
usage() {
    cat <<EOF
Diff two sparse files by converting them to regular images and mounting them
usage: ${0} -o [old] -n [new]

-o Older sparse file
-n Newer sparse file

-h Show this help message
EOF
}

args=o:n:h

while getopts $args arg ; do
    case $arg in
        n) new_sparse=$OPTARG ;;
        o) old_sparse=$OPTARG ;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done

if [ ! $new_sparse ] ; then
    echo "New sparse not given" >&2
    exit 1
fi

if [ ! $old_sparse ] ; then
    echo "Old sparse not given" >&2
    exit 1
fi

cleanup() {
    : "${tmp_dir:? Tmp dir not set}"

    umount "$tmp_dir"/new
    umount "$tmp_dir"/old
    rm -rf -- "$tmp_dir"
    exit ${1:-1}
}

tmp_dir=$(mktemp -d)
for signal in TERM HUP QUIT; do
    # shellcheck disable=2064
    # not: $tmp_dir is the sam when the trap is set or executed
    # the warning is irrelevant.
    trap "cleanup 1" $signal
done
unset signal
# shellcheck disable=2064
# not: $tmp_dir is the same when the trap is set or executed
# the warning is irrelevant.
trap "cleanup 130" INT
trap "cleanup 0" EXIT


simg2img "$new_sparse" "$tmp_dir"/new.img
simg2img "$old_sparse" "$tmp_dir"/old.img


mkdir "$tmp_dir"/new
mkdir "$tmp_dir"/old

mount -o ro "$tmp_dir"/new.img "$tmp_dir"/new
mount -o ro "$tmp_dir"/old.img "$tmp_dir"/old

# We cd to tmp_dir since we want to diff against a relative path so the diff doesn't contain $tmp_dir in the output
cd "$tmp_dir" || exit 1

diff -ru old new
