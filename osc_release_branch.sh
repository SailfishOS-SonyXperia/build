#!/bin/bash

set -e

scriptdir="$(dirname -- "$( readlink -f -- "$0"; )")"


webhook_change_branch() {
    # Change branch in webhook service in obs _service file
    python3 -c"from xml.etree import ElementTree
xmlFile = ElementTree.parse('$1')
root = xmlFile.getroot()
for service in root.findall('.//service'):
        if service.attrib['name']=='webhook':
           for param in service.findall('param'):
               if param.attrib['name'] == 'branch':
                   param.text = '$2'
xmlFile.write('$1')
"
}

change_repository_from_latest_to_release() {
    # Change repostory from :latest to :$RELEASE
    python3 -c"from xml.etree import ElementTree
xmlFile = ElementTree.parse('$1')
root = xmlFile.getroot()
for service in root.findall('.//repository'):
            for path in service.findall('path'):
                for key in path.iter():
                    if 'sailfishos:latest' in key.attrib['project']:
                        key.attrib['project'] = 'sailfishos:$2'
                    # Nemo hw-common uses separate repositories per release
                    # their naming scheme differs between devel and testing :/
                    if 'sailfish_latest_${adaptation_repo_arch}' in key.attrib['repository']:
                        key.attrib['repository'] = 'sailfishos_${2}_${adaptation_repo_arch}'
                    # Switch hw-common from devel to testing
                    if 'nemo:devel:hw:common' in key.attrib['project']:
                        key.attrib['project'] = 'nemo:testing:hw:common'
xmlFile.write('$1')"
}

. $scriptdir/shared.sh

usage_description="Branch of obs project and switch package webhooks to release branch"

usage() {
    cat <<EOF
usage: $0 [options] -P project
$usage_description

options:

-P       OBS source project
-T       OBS target project to branch to
-R       Target release, should given as major.minor.patch.revision
-S <R,S> Skip (R)epository branching or (S)ervice branching
         Can be passed multiple times.

-A       API url to the target obs, defaults to $obs_api_url

-h       Show this help

EOF
}


while getopts hr:b:P:p:A:t:R:T:S: arg ; do
    case $arg in
        P) obs_project=$OPTARG;;
        T) target_obs_project=$OPTARG;;
        A) obs_api_url=$OPTARG;;
        R) RELEASE=$OPTARG;;
        S) case $OPTARG in
               R) skip_branching_repositories=t ;;
               S) skip_branching_services=t ;;
           esac
           ;;
        h) usage; exit 0;;
        ?|*) usage; exit 1;;
    esac
done
shift $(($OPTIND - 1))

start_date="$(date -R)"

osc copyprj --prjconf \
    --with-history --now \
    "$obs_project" "$target_obs_project:$RELEASE"

if [ -z $skip_branching_repositories ] ; then
    OSC_PRJ=$target_obs_project:$RELEASE osc_parse_env

    tmp_prj_conf=$(mktemp)
    for signal in TERM HUP QUIT EXIT; do
        # shellcheck disable=2064
        # note: $tmp_prj_conf is the same when the trap is set or executed
        # the warning is irelevant.
        trap "rm -rf $tmp_prj_conf; exit 1" $signal
    done
    unset signal
    # shellcheck disable=2064
    # note: $tmp_prj_conf is the same when the trap is set or executed
    # the warning is irelevant.
    trap "rm -rf $tmp_prj_conf; exit 130" INT

    osc meta prj $target_obs_project:$RELEASE > $tmp_prj_conf
    change_repository_from_latest_to_release $tmp_prj_conf $RELEASE

    osc meta prj $target_obs_project:$RELEASE --file="$tmp_prj_conf" --message "Branch from devel to testing:$RELEASE on $start_date"

    rm -f $tmp_prj_conf
fi

if [ -z $skip_branching_services ] ; then
    obs_checkout_prj $target_obs_project:$RELEASE
    obs_cd_project $target_obs_project:$RELEASE

    for dir in *;do
        # Only check dirs which are an obs package
        # Skip packages with no webhook
        if [ -e "$dir/.osc/_package" ] && [ -e "$dir/_service" ]; then
            (
                cd "$dir"
                webhook_change_branch \
                    _service  \
                    "upgrade-$(echo $RELEASE|cut --complement -d '.' -f4)" # we only want major.minor.patch version here
                osc commit -m"Switch webhook to listen to $RELEASE branch"
            )
        fi
    done
fi
