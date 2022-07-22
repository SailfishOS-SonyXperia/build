#!/bin/bash

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh

usage() {
    cat <<EOF
usage: $0  [options] packages

options:
-r      repository url

-P      OBS source Project

-A      API url to the target obs, defaults to $obs_api_url

-h      Show this help

EOF
}


while getopts hr:b:P:p:A: arg ; do
    case $arg in
        r) repository=$OPTARG;;
        P) obs_project=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done


start_date="$(date -R)"

repository_basename=$(basename $repository |sed 's/\.git//')
obs_checkout_prj $obs_project
obs_project=$PWD/$obs_project

if [ ! -e $repository_basename ] ; then
    git clone --recursive "$repository"
else
    cd $repository_basename || exit 1
    git pull --recurse-submodule=yes
fi

# droid-prjconf package copy start
# The lines marked as copy are copied from droid-hal-prjconf.inc:
# https://github.com/mer-hybris/droid-hal-prjconf/blob/master/droid-hal-prjconf.inc
CONFDIR=prjconf
SUBMODULE=droid-hal-prjconf
SRC_GENERIC=$SUBMODULE/$CONFDIR
SRC_SPECIFIC=$CONFDIR
DEST=$obs_project/prjconf_upload.xml

mkdir -p $DESTDIR

if grep -q "^Macros:" $SRC_GENERIC/prjconf.xml $SRC_SPECIFIC/prjconf.xml; then
    echo "prjconf.xml must not contain Macros section. Put them to macros.xml"
    exit 1
fi

cp -f $SRC_GENERIC/prjconf.xml $DEST
if [ -e $SRC_SPECIFIC/prjconf.xml ]; then
    cat $SRC_SPECIFIC/prjconf.xml >> $DEST
fi
# droid-prjconf package interrupt

# Store the %device macro defined in prjconf spec in the prjconf
# so that later we can find out to which device and thus vendor and family
# the building project and it's droid-src package belong to.
device=$(parse_spec_stat rpm/droid-hal-prjconf.spec "name"|head -n1|
             sed 's/droid-hal-prjconf-//')
echo "%define device $device" >> $DEST

# droid-prjconf package continue
if [ -e $SRC_SPECIFIC/macros.xml ]; then
    echo "Macros:" >> $DEST
    cat $SRC_SPECIFIC/macros.xml | grep -v "^Macros:" >> $DEST
fi
# droid-prjconf package end


pkg_ver=$(git describe --tags)

cd "$obs_project" || exit 1
osc meta prjconf --file="$DEST" --message "Update to $pkg_ver on $start_date"

rm "$DEST"
