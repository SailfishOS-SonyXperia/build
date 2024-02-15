#!/bin/bash
# Run osc build for package in prj that is shadowed in :dhd
# Then upload.

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"

. $scriptdir/shared.sh

usage_description="Build packae in project:dhd and then upload to project
the idea is to a package that can't be build on the obs in a shadow dhd project
and then upload."

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

obs_default_opts="-A $obs_api_url"

# First checkout the lower level project to workaround
# https://github.com/openSUSE/osc/issues/1255
obs_checkout_prj_pkg $obs_project $obs_package
obs_checkout_prj_pkg $obs_project:dhd $obs_package

start_date="$(date -R)"


obs_cd_project "$obs_project:dhd"/"$obs_package" || exit $?

# Workaround for left over directory being there
rm -rf android .old

osc service run tar_git
osc_parse_env
popd

obs_project_slash=$(realpath $(obs_cd_project_path "$obs_project"))
obs_project_slash_dhd=$(realpath "$(obs_cd_project_path "$obs_project" dhd)")

should_build "$obs_project_slash/$obs_package" \
 "$obs_project_slash_dhd/$obs_package/_service:tar_git:$obs_package.spec" \
 "$obs_project_slash_dhd/droid-src-$vendor-$family/_service:tar_git:droid-src-$vendor-$family.spec"

if [ $should_build -eq 1 ] ; then
    exit 0
fi

# droid_src was updated but not droid-hal bump release
if [ $should_build -eq 2 ] ; then
    osc_build_args+=(  --release=$(($(parse_spec_stat "$obs_project_slash_dhd/$obs_package/_service:tar_git:$obs_package.spec" "Release"|head -n1) + 1 )) )
fi

(
    obs_cd_project "$obs_project:dhd"/"$obs_package" || exit $?
    osc_build "$@"
)




obs_cd_project $obs_project/$obs_package || exit 1


for rpm in "$obs_project_slash_dhd/$obs_package/"*.rpm ; do
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
osc add $pkg

osc \
    commit \
    --skip-local-service-run \
    -m"Run osc build as of $start_date"
