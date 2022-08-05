# Default directories
# Override at least obs_build_rootdir if needed

obs_api_url="https://build.sailfishos.org"
obs_default_opts="-A $obs_api_url"

obs_build_rootdir=/srv/build/buildservice
obs_cache_dir=${obs_build_rootdir}/cache
obs_build_root=${obs_build_rootdir}/buildroot
osc_build_cache_pkgs=${obs_cache_dir}/pkgs

error() {
    echo "$@" >&2
}

die() {
    error "$@"
    exit 1
}

osc_parse_env()
# Parse the %device variable from the prjconf so we now which droid-src package
# we build for.
{
    local device=$(osc meta prjconf ${OSC_PRJ} |grep 'define device'| cut -d ' ' -f3)
    vendor=$(echo $device| cut -d '-' -f1)
    family=$(echo $device| cut -d '-' -f2)

    # Detect the arch for the of the adaptation repo from device_rpm_architecture_string
    adaptation_repo_arch=$(osc meta prjconf ${OSC_PRJ} |grep device_rpm_architecture_string |
                           cut -d ' ' -f2)
}

osc_build() {

    # Clean up old build.script package that could block building the spec file
    # besides running build.script
    rm -f build.script

    mkdir -p $obs_cache_dir \
          $osc_build_cache_pkgs

    if [ $# -eq 0 ] ; then
        set -- latest_$adaptation_repo_arch i586
    fi

    osc build --root=$obs_build_root --no-verify \
        "${@}" \
        -x p7zip -x bzip2 \
        --keep-pkgs="$PWD" \
        --prefer-pkgs=$osc_build_cache_pkgs \
        --no-service \
        --trust-all-projects  \
        --ccache \
        --clean "${osc_build_args[@]}"

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

obs_checkout_prj() {
    local obs_project="$1"

    if [ ! -d "$obs_project" ] ; then
        osc $obs_default_opts co "$obs_project"
    fi
}

obs_checkout_prj_pkg() {
    local obs_project="$1"
    local obs_package="$2"

    (
        obs_checkout_prj "$obs_project"
        cd "$obs_project" || exit $?

        if [ ! -e "$obs_package" ] ; then
            osc $obs_default_opts co "$obs_package"
        else
            cd "$obs_package" || exit $?
            osc $obs_default_opts up
        fi
    )
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
            osc rm -- *"$old_pkg_ver"*.rpm
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
