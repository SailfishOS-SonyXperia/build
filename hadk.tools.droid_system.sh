#!/bin/bash

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh
. $scriptdir/shared.hadk_tools.setup.sh

usage_description="Fetch device we build for from obs_project and use hadk_tools to build droid-system for each supported devices, requires that local build env has been setup"
TARGET_UNIT=sfos.droid.syspart.hadk

while getopts hr:b:P:p:A:t: arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        t) hadk_tools_templates_dir=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

obs_checkout_prj $obs_project

pushd $(obs_cd_project_path $obs_project)

osc_parse_env
hadk_setup_tmp_unit
osc_hadk_setup_supported_devices


hadk.build -t "$hadk_tools_templates_dir:$scriptdir" -f "$tmp_dir/$TARGET_UNIT.wrapper.hadk"
