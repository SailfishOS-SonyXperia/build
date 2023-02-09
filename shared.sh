# -*- bash -*-
# Default directories
# Override at least obs_build_rootdir if needed

obs_api_url="https://build.merproject.org"
osc_opts=()

obs_build_rootdir=/srv/build/buildservice
obs_cache_dir=${obs_build_rootdir}/cache
obs_build_root=${obs_build_rootdir}/buildroot
osc_build_cache_pkgs=${obs_cache_dir}/pkgs

export LANG=en_US.utf8
export LC_CTYPE="en_US.utf8"
export LC_ALL=
export GREP_COLORS=never

error() {
    echo "$@" >&2
}

die() {
    error "$@"
    exit 1
}

osc() {
    command osc \
            "${osc_opts[@]}" -A "${obs_api_url}" "${@}"
}

osc_parse_define()
{
    local output
    output="$(osc meta prjconf ${OSC_PRJ} |grep "define $1"| sed -e "s/%define\ *$1\ *//"| sed -e 's/^"//' | sed -e 's/"$//')"
    if [ -z "$output" ] ; then
        error "\$$1 can't be empty, please define inside your prjconf"
        exit 1
    fi
    echo "$output"
}

osc_parse_env()
# Parse the %device variable from the prjconf so we now which droid-src package
# we build for.
{
    local device=$(osc_parse_define "device")
    vendor=$(echo $device| cut -d '-' -f1)
    family=$(echo $device| cut -d '-' -f2)

    # Detect the arch for the of the adaptation repo from device_rpm_architecture_string
    adaptation_repo_arch=$(osc meta prjconf ${OSC_PRJ} |grep device_rpm_architecture_string |
                               cut -d ' ' -f2)

    # Separate local package cache per device
    osc_build_cache_pkgs=${osc_build_cache_pkgs}/${vendor}/${family}
}

osc_build() {
    local obs_build_repository=latest_$adaptation_repo_arch obs_build_repository_arch=i586
    # Clean up old build.script package that could block building the spec file
    # besides running build.script
    rm -f build.script

    mkdir -p $obs_cache_dir \
          $osc_build_cache_pkgs


    while getopts r:c: arg ; do
        case $arg in
            r) obs_build_repository=$OPTARG;;
            c) obs_build_repository_arch=$OPTARG;;
        esac
    done

    osc build --root=$obs_build_root --no-verify \
        $obs_build_repository $obs_build_repository_arch \
        -x p7zip -x bzip2 \
        --keep-pkgs="${obs_build_to_cache:-$PWD}" \
        --prefer-pkgs=$osc_build_cache_pkgs \
        --no-service \
        --trust-all-projects  \
        --ccache \
        --clean "${@}" "${osc_build_args[@]}"

    # In case we use ubu-chroot we need to unmount all mounts that were used so subsequent
    # run work fine.
    if grep -q $obs_build_root /etc/mtab; then
        sudo umount -R \
             $obs_build_root || true
    fi
    if grep -q $obs_build_root/srv/mer/sdks/ubu/parentroot /etc/mtab; then
        sudo umount -R \
             $obs_build_root/srv/mer/sdks/ubu/parentroot || true
    fi
}

obs_cd_project_path() {
    local obs_project_slash="$1" obs_project_path_separator=":"
    if osc config --dump|grep checkout_no_colon > /dev/null ; then
        obs_project_slash=$(echo "$1" | sed 's|:|/|g')
        obs_project_path_separator="/"
    fi
    echo "$obs_project_slash"${2+${obs_project_path_separator}${2}}
}


obs_cd_project(){
    # Don't use grep -q here or osc will complain: BrokenPipeError: [Errno 32] Broken pipe
    local obs_project_slash="$(obs_cd_project_path "$1")"
    pushd "$obs_project_slash"
}

obs_checkout_prj() {
    local obs_project="$1"

    if [ ! -d $(obs_cd_project_path "$1") ] || \
           [ ! -d $(obs_cd_project_path "$1")/.osc ] ; then
        osc co "$obs_project"
    else
        (
            obs_cd_project $(obs_cd_project_path "$1") || exit $?
            osc up
        )
    fi
}

obs_checkout_prj_pkg() {
    local obs_project="$1"
    local obs_package="$2"

    (
        obs_checkout_prj "$obs_project"
        obs_cd_project "$obs_project" || exit $?

        if [ ! -e "$obs_package" ] ; then
            osc co "$obs_package"
        else
            pushd  "$obs_package" || exit $?
            osc up
        fi
    )
}

osc_pkg_clean_rpms() {
    local pkg="${1:-$PWD}"

    if [ ! -e "$pkg/.osc/_apiurl" ] ; then
        return 1
    fi

    local pkg_name pkg_project
    read -r pkg_name < "$pkg/.osc/_package"
    read -r pkg_project < "$pkg/.osc/_project"

    for rpm in $(osc ls $pkg_project $pkg_name) ; do
        case $rpm in
            *.rpm) osc rm $rpm ;;
            *) : ;;
        esac
    done
}

osc_repo_baseurl() {
    local repofile_url
    for repofile_url in $(osc repourls "${1+$1}") ; do
        case $repofile_url in
            *${adaptation_repo_arch}*) break ;;
        esac
    done
    curl --netrc-optional --silent "$repofile_url"|grep baseurl| cut -d'=' -f2
}

gen_build_script() {
    cat > build.script <<EOF
cd ~/rpmbuild

for rpm in SOURCES/*.rpm* ;do
    case \$rpm in
         *noarch*) arch=noarch;;
         *aarch64*) arch=aarch64;;
         *armv7hl*) arch=armv7hl;;
         *i486*) arch=i486 ;;
    esac

    case \$rpm in
         *7z*)
           [ ! -e "\$rpm" ] && continue
           7zr e  -o SOURCES "\$rpm"
           rpm=\$(echo "\$rpm" |sed -e 's|.7z.*||')
           ;;
    esac

    mkdir -p RPMS/\$arch/

    echo "copying "\$rpm" to RPMS/\$arch/"
    mv \$rpm RPMS/\$arch/
done
EOF
}

gen_build_script_stub_spec() {
cat > $pkg.spec <<EOF
Summary:    $pkg upload package
License:    BSD-3-Clause
Name:       $pkg
Version:    $pkg_ver
Release:    0
%description
%{summary}.
EOF
}


usage_options() {
    # Override to list any new usage options
    :
}
usage() {
    cat <<EOF
usage: $0 [options] -P project -p package
$usage_description

options:

-P      OBS source Project
-p      OBS Package

-A      API url to the target obs, defaults to $obs_api_url
EOF
    # Call usage options to list any script specific options
    usage_options
cat <<EOF
-h      Show this help

EOF
}


write_pkg_meta() {
    cat > $1/pkg_meta <<EOF
pkg="$pkg"
pkg_ver="$pkg_ver"
require_ver="$require_ver"
EOF
}

parse_spec_stat() {
    # We need to pass dummy variables for variables that come from macros
    # that might not be installed so rpmspec is happy while we parse it.
    rpmspec -D"_obs_build_project 1" \
            -D"systemd_requires %nil" \
            -D"_oneshot_requires_post %nil" \
            -q --queryformat="%{$2}\n" "$1" ${3+"$3"}
}

should_build()
{
    local old_pkg_dir="$1"
    shift
    should_build=0

    __pkg="$1"
    shift

    if [ "$1" ] ; then
        require="$1"
        shift
    fi

    if [ -e "$old_pkg_dir"/pkg_meta ] ; then
        . "$old_pkg_dir"/pkg_meta
        old_pkg="$pkg"
        old_pkg_ver="$pkg_ver"
        old_require_ver="$require_ver"

        pkg=$__pkg
        pkg_ver=$(parse_spec_stat "$__pkg" "Version"|head -n1)
        require_ver=$(parse_spec_stat "$require" "Version"|head -n1)

        if [ "$old_pkg_ver" = "$pkg_ver" ] ; then
            if [ "$old_require_ver" = "$require_ver" ] ; then
                should_build=1
            else
                # If we need to rebuild because of the require version changes we
                # also need to bump the release, mark to should_build accordingly
                should_build=2
            fi
        fi
        (
            cd "$old_pkg_dir" || exit $?
            osc_pkg_clean_rpms
        )
    else
        pkg=$__pkg
        pkg_ver=$(parse_spec_stat "$pkg" "Version"|head -n1)
        require_ver=$(parse_spec_stat "$require" "Version"|head -n1)
    fi
    pkg=$(basename $__pkg)
}

if [ -e "$scriptdir"/env.sh ] ; then
    . "$scriptdir"/env.sh
fi
