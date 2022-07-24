#!/bin/bash
# Fetch device we build for from obs_project and use hadk_tools to build droid-system
# for each supported devices

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh

usage_description="Fetch device we build for from obs_project and use hadk_tools to build droid-system for each supported devices, requires that local build env has been setup"

while getopts hr:b:P:p:A: arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        p) obs_package=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

obs_checkout_prj $obs_project

osc_parse_env

tmp_unit=$(mktemp)
for signal in TERM HUP QUIT EXIT; do
    # shellcheck disable=2064
    # note: $tmp_unit is the same when the trap is set or executed
    # the warning is irelevant.
    trap "rm $tmp_unit; exit 1" $signal
done
unset signal
# shellcheck disable=2064
# note: $tmp_unit is the same when the trap is set or executed
# the warning is irelevant.
trap "rm $tmp_unit; exit 130" INT


SUPPORTED_DEVICES=$(osc_parse_define "supported_devices")
if [ -z "$SUPPORTED_DEVICES" ] ; then
    error "\$SUPPORTED_DEVICES can't be empty, please define inside your prjconf"
    exit 1
fi

cat > $vendor.$family.devices.hadk <<EOF
FAMILY=$family
SUPPORTED_DEVICES=$SUPPORTED_DEVICES
EOF

cat > $tmp_unit <<EOF
VENDOR=$vendor
FAMILY=$family
TARGET_UNIT=sfos.droid.syspart.hadk


depend sfos.build.fordevice.hadk
EOF

hadk.build -f "$tmp_unit"
