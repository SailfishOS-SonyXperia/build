#!/bin/bash

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh
. $scriptdir/shared.hadk_tools.setup.sh

usage_description="Fetch device we build for from obs_project and use hadk_tools to build image for each supported devices, requires that plaform SDK has been setup"
TARGET_UNIT=mk.image.hadk

usage_options() {
    cat <<EOF
-S      Obs project that contains SSu config, can be supplied multiple times
-E      Extra packages to install such as additional features, can be supplied multiple times
-D      Build only for device
EOF
}

append_var() {
    local sep=$sep
    if [ -z "$sep" ] ; then
        sep=" "
    fi
    if $(eval [ -z \"\$$1\" ])  ; then
        eval "$1=\"$2\""
    else
        eval "$1=\"\$$1${sep}\"$2\"\""
    fi
}

while getopts hr:b:P:p:A:t:S:E:D: arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        t) hadk_tools_templates_dir=$OPTARG;;
        S)
            repo=$(osc_repo_baseurl "$OPTARG")
            if [ -z $repo ] ;then
                exit 1
            fi
            extra_repos+="repo --name=addon-repo-$RANDOM --baseurl=$repo
"
           ;;
        E) extra_packages+=" $OPTARG";;
        D) single_device=$OPTARG;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

obs_checkout_prj $obs_project

pushd $(obs_cd_project_path $obs_project)

osc_parse_env
hadk_setup_tmp_unit
osc_hadk_setup_supported_devices ${single_device}

# Tell the mk.image to use our adaptation repository
# instead of trying to use a local repository
echo SFOS_ADAPTION0_URL=$(osc_repo_baseurl "$obs_project") >> $tmp_dir/$vendor.$family.devices.hadk
cat >> $tmp_dir/$vendor.$family.devices.hadk <<EOF
SRCKS_DIR=/parentroot$tmp_dir/usr/share/kickstarts
KS_INSERT_EXTRA_PACKAGES="${extra_packages}"
KS_INSERT_EXTRA_REPOS="${extra_repos}"
EOF
popd


# Fetch droid-config-ssu-kickstarts here
for device in ${single_device:-${SUPPORTED_DEVICES}}; do
    osc getbinaries \
        --destdir="$tmp_dir" \
        "$obs_project" \
        droid-config-$device \
        latest_$adaptation_repo_arch \
        $adaptation_repo_arch
    (
        cd $tmp_dir
        rpm2cpio \
            $tmp_dir/droid-config-$device-ssu-kickstarts-*.$adaptation_repo_arch.rpm \
            | cpio -idv &> /dev/null
    )
done

hadk.build -t "$hadk_tools_templates_dir:$scriptdir" -f "$tmp_dir/$TARGET_UNIT.wrapper.hadk"
