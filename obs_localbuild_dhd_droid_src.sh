#!/bin/bash

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh
. $scriptdir/shared.hadk_tools.setup.sh

usage_description="Fetch device family we build for from obs_project and build droid-src"

# Keep droid-src packages directly in build cache so we don't have to
# move them around after
obs_build_to_cache="${osc_build_cache_pkgs}"

while getopts hr:b:P:p:A:t: arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

obs_checkout_prj $obs_project:dhd

OSC_PRJ=$obs_project osc_parse_env

obs_cd_project "$obs_project:dhd/droid-src-$vendor-$family" || exit 1

# Workaround for left over directory being there
rm -rf android .old

osc service run tar_git

# Pass specific droid-src package name since the repository might contain
# spec files for other devices.
osc_build "$@" "_service:tar_git:droid-src-$vendor-$family.spec"
