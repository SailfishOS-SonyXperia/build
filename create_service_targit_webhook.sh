#!/bin/sh
#
# Create _service file for obs with tar_git and webhook

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh

branch=master

usage() {
    cat <<EOF
usage: create_targit_webhook_package.sh [options] packages

options:
-r      repository url
-b      target branch

-P      OBS Project to upload to
-p      OBS Package to create

-A      API url to the target obs, defaults to $obs_api_url

-h      Show this help

EOF
}

create__service()
{
    file="$1"
    shift

    cat > "$file" <<EOF
<services>
  <service name="webhook">
  <param name="repourl">$repository</param>
  <param name="branch">$branch</param>
  </service>
<service name="tar_git">
  <param name="url">$repository</param>
  <param name="branch">$branch</param>
  <param name="revision"/>
  <param name="token"/>
  <param name="debian">N</param>
  <param name="dumb">N</param>
</service></services>
EOF
}


while getopts hr:b:P:p:A: arg ; do
    case $arg in
        r) repository=$OPTARG;;
        b) branch=$OPTARG;;
        P) obs_project=$OPTARG;;
        p) obs_package=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done


obs_default_opts="-A $obs_api_url"

if [ ! -e "$obs_project" ] ; then
    osc co "$obs_project"
fi

cd "$obs_project" || exit $?

if [  -e "$obs_package" ] ; then
    die "Package already exists"
fi

osc mkpac "$obs_package"

cd "$obs_package"

create__service "_service"

osc add _service

osc commit -m"Added package"
