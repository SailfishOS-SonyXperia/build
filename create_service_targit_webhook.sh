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
-w      Create webhook service (default)
-W      Don't create webhook service

-P      OBS Project to upload to
-p      OBS Package to create

-A      API url to the target obs, defaults to $obs_api_url

-h      Show this help

EOF
}

webhook="--webhook"

while getopts hr:b:P:p:A:wW arg ; do
    case $arg in
        r) repository=$OPTARG;;
        b) branch=$OPTARG;;
        P) obs_project=$OPTARG;;
        p) obs_package=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        w) webhook="--webhook";;
        W) webhook="";;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done


obs_default_opts="-A $obs_api_url"

if [ ! -e "$(obs_cd_project_path $obs_project)" ] ; then
    osc co "$obs_project"
fi

obs_cd_project "$obs_project" || exit $?

if [  -e "$obs_package" ] ; then
    die "Package already exists"
fi

osc mkpac "$obs_package"

cd "$obs_package"

$scriptdir/osc_service_add.py --package "$obs_package" \
                                --project "$obs_project" \
                                --branch "$branch" \
                                --repository "$repository" $webhook _service
osc add _service

osc commit -m"Added package"
