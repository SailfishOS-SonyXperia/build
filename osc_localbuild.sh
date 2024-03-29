#!/bin/bash
# Run osc build for package in prj that is shadowed in :dhd
# Then upload.

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh

usage_description="Build package in project"
usage_options() {
    cat <<EOF
-U      Also upload build package
-C      Keep build packages in cache pkg cache directory
EOF
}

while getopts hr:b:P:p:A:UC arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        p) obs_package=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        C) obs_build_to_cache="${osc_build_cache_pkgs}";;
        U) upload=t;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

obs_checkout_prj_pkg $obs_project $obs_package

start_date="$(date -R)"

obs_cd_project "$obs_project"/"$obs_package" || exit $?

osc service run tar_git
osc_parse_env


should_build "$obs_project/$obs_package" \
             "$obs_project/$obs_package/_service:tar_git:$obs_package.spec" \
             "$obs_project:dhd/droid-src-$vendor-$family/droid-src-$vendor-$family.spec"

if [ $should_build -eq 1 ] ; then
    exit 0
fi

# droid_src was updated but not droid-hal bump release
if [ $should_build -eq 2 ] ; then
    osc_build_args+=(  --release=$(($(parse_spec_stat "$obs_project:dhd/$obs_package/_service:tar_git:$obs_package.spec" "Release"|head -n1) + 1 )) )
fi

osc_build "$@"


if [ $upload ] ; then
    SIZE_1G_IN_B=$(echo 1G |numfmt --from si)

    for rpm in $obs_project/$obs_package/*.rpm ; do
        case $rpm in
            *.src.rpm) : ;; # Ignore source packages
            *)  mv "$rpm" .
                osc add "$(basename $rpm)"
                ;;
        esac
    done


    gen_build_script
    osc add build.script


    write_pkg_meta .
    osc add pkg_meta

    gen_build_script_stub_spec
    osc add $obs_package.spec


    osc \
        commit \
        --skip-local-service-run \
        -m"Run osc build as of $start_date"
fi
