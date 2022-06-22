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

obs_checkout_prj_pkg $obs_project:dhd $obs_package
obs_checkout_prj_pkg $obs_project $obs_package

start_date="$(date -R)"


pushd "$obs_project:dhd"/"$obs_package" || exit $?
osc service run tar_git
osc_parse_env
popd

should_build "$obs_project/$obs_package" \
             "$obs_project:dhd/$obs_package/_service:tar_git:$obs_package.spec" \
             "$obs_project:dhd/droid-src-$vendor-$family/droid-src-$vendor-$family.spec"

if [ $should_build -eq 1 ] ; then
    exit 0
fi

# droid_src was updated but not droid-hal bump release
if [ $should_build -eq 2 ] ; then
    osc_build_args+=(  --release=$(($(parse_spec_stat "$obs_project:dhd/$obs_package/_service:tar_git:$obs_package.spec" "Release"|head -n1) + 1 )) )
fi

(
    cd "$obs_project:dhd"/"$obs_package" || exit $?
    osc_build "$@"
)




SIZE_1G_IN_B=$(echo 1G |numfmt --from si)

cd $obs_project/$obs_package || exit 1


for rpm in "../../$obs_project:dhd/$obs_package/"*.rpm ; do
    if [ "$(stat -c '%s' $rpm)" -ge $SIZE_1G_IN_B ] ; then
        7z a -v750m "$rpm.7z" "$rpm"
    fi
    mv "$rpm" .
    osc $obs_default_opts add $(basename $rpm)*
done

gen_build_script
osc add build.script

write_pkg_meta .
osc add pkg_meta

gen_build_script_stub_spec
osc add $pkg.spec

osc $obs_default_opts \
    commit \
    --skip-local-service-run \
    -m"Run osc build as of $start_date"
