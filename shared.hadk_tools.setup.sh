# -*- bash -*-

osc_hadk_setup_supported_devices()
{
    SUPPORTED_DEVICES=${1:-$(osc_parse_define "supported_devices")}

    cat > "$tmp_dir"/$vendor.$family.devices.hadk <<EOF
FAMILY=$family
SUPPORTED_DEVICES="$SUPPORTED_DEVICES"

EOF
}

hadk_setup_tmp_unit() {
    tmp_dir=$(mktemp -d)
    for signal in TERM HUP QUIT; do
        # shellcheck disable=2064
        # note: $tmp_dir is the same when the trap is set or executed
        # the warning is irelevant.
        trap "rm -rf $tmp_dir; exit 1" $signal
    done
    unset signal
    # shellcheck disable=2064
    # note: $tmp_dir is the same when the trap is set or executed
    # the warning is irelevant.
    trap "rm -rf $tmp_dir; exit 130" INT
    trap "rm -rf $tmp_dir; exit 0" EXIT


    cat > $tmp_dir/$TARGET_UNIT.wrapper.hadk <<EOF
VENDOR=$vendor
FAMILY=$family
TARGET_UNIT=$TARGET_UNIT
# We need to be able to find units in tmp_dir in the platform sdk
depend_path="\$depend_path:/parentroot/$tmp_dir"

depend sfos.build.fordevice.hadk
EOF
}

usage() {
    cat <<EOF
usage: $0 [options] -P project
$usage_description

options:

-P      OBS source Project
-t      Path to the directory containing your device templates

-A      API url to the target obs, defaults to $obs_api_url
EOF
    # Call usage options to list any script specific options
    usage_options
    cat <<EOF
-h      Show this help

EOF
}
