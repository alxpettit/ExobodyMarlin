#!/usr/bin/env bash

# I HATE BASH
# BASH IS TRASH
# FUCK YOU ALL
# -Alexandria Pettit, 2022
# GNU GPLv3
# FISH shell people, pls make a linter u dummies

# VERY IMPORTANT! Strict mode. See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Nullglob needed for gracefully checking if anything matched
shopt -s nullglob


echo "Loading config..."
source push.conf

# configs
: "${control_path_prefix:=${HOME}/.ssh/ctl}"
: "${control_path:=${control_path_prefix}/push-%L-%r@%h:%p}"
: "${build_env:=STM32F103RET6_creality}"
: "${remote_mountpoint:=/mnt/target}"
: "${bin_path:=.pio/build/${build_env}}"
: "${target_partition:=}"
: "${host:=}"

echo "Configs loaded."

latest_firmware=$(echo "${bin_path}/firmware-"*.bin | choose -1)
echo "I believe the latest firmware is: ${latest_firmware}"

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

echo "Making sure control path prefix exists..."
mkdir -vp "${control_path_prefix}"

echo "Closing old SSH sessions..."
old_session_files=( "${control_path_prefix}/push-"* )

if (( ${#old_session_files[@]} )); then
  for session in "${old_session_files[@]}"; do
    echo "Old session detected: ${session}"
    ssh -O exit -o ControlPath="${control_path}"  "${host}" || {
      echo "Exit of old session failed. Oh well."
    }
  done
else
  echo "No old sessions exist. Yay!"
fi

echo "Opening SSH session..."
ssh -nNf -o ControlMaster=yes -o ControlPath="${control_path}" "${host}"

ssh root@yuri-mech bash << EOF
  mkdir -p "${remote_mountpoint}"
  umount "${target_partition}"
  mount "${target_partition}" "${remote_mountpoint}" && \
  rm -fv "${remote_mountpoint}"/*.bin
EOF

echo "Copying file to remote microSD card..."
rsync -e "ssh -o ControlPath='${control_path}'" -P "${latest_firmware}"  "${host}":/mnt/target/

# shellcheck disable=SC2087 # local expansion is intended behavior
ssh "${host}" bash << EOF
  while true; do
    umount "${target_partition}" || {
      echo "Unmount of remote partition failed. Mountpoints must be exhausted. This is normal."
      break
    }
  done
EOF

echo "Closing SSH session..."
ssh -O exit -o ControlPath="${control_path}"  "${host}"
