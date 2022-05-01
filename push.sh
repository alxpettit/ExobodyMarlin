#!/usr/bin/env bash

# VERY IMPORTANT! Strict mode. See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

source push.conf

# configs
: "${control_path_prefix:=${HOME}/.ssh/ctl}"
: "${control_path:=${control_path_prefix}/%L-%r@%h:%p}"
: "${build_env:=STM32F103RET6_creality}"
: "${remote_mountpoint:=/mnt/target}"
: "${bin_path:=.pio/build/${build_env}}"
: "${target_partition:=}"
: "${host:=}"

latest_firmware=$(echo "${bin_path}/firmware-"*.bin | choose -1)

function check_exists() {
  var_name="$1"
  var_val="$2"

  if [ -z "${var_val}" ]; then
    echo "\"${var_name}\" is not defined" 1>&2
    exit 1
  fi
}

check_exists target_partition "${target_partition}"
check_exists host "${host}"

# make sure this path exists
mkdir -p "${control_path_prefix}"

# open SSH session
ssh -nNf -o ControlMaster=yes -o ControlPath="${control_path}" "${host}"

ssh root@yuri-mech bash << EOF
  mkdir -p "${remote_mountpoint}" && \
  mount "${target_partition}" "${remote_mountpoint}" && \
  rm "${remote_mountpoint}"/*.bin
EOF


rsync -e "ssh -o ControlPath='${control_path}'" -P "${latest_firmware}"  "${host}":/mnt/target/

# shellcheck disable=SC2087 # local expansion is intended behavior
ssh "${host}" bash << EOF
  while true; do
    umount "${target_partition}" || exit
  done
EOF

# Close SSH session
ssh -O exit -o ControlPath="${control_path}"  "${host}"
