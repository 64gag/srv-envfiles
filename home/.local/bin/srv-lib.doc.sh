#!/usr/bin/env bash

srv_lib_add_line_to_file_if_not_present() {
  local line="$1"
  local file="$2"
  grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

srv_lib_remove_line_from_file() {
  local line="$1"
  local file="$2"
  grep -vxF "$line" "$file" > temp_file && mv temp_file "$file"
}

# === USERS ===
#
# - Users 0-99 are reserved by Linux
# - I consider 100-999 to be reserved by distros (it is the case in Debian...?)
# - I use an offset of 10000 for normal users
# - I use an offset of 20000 for LXC containers + their unique 'vmid'

srv_lib_add_group_and_user() {
    local id="$1"
    local name="$2"

    if ((id >= 10000 && id < 20000)); then
        groupadd -g ${id} ${name} && useradd -s /bin/bash -u ${id} -g ${id} ${name}
    else
        groupadd -g ${id} ${name} && useradd -M -s /usr/sbin/nologin -u ${id} -g ${id} ${name}
    fi
}

srv_lib_remove_group_and_user() {
    local name="$1"
    userdel "${name}"
    groupdel "${name}"
}

srv_lib_add_normal_user() {
    local id=$1
    local name=$2
    srv_lib_add_group_and_user $((${id} + 10000)) "${name}"
}

# I create a user in the host per venv id
# Since venv ids are unique by definition I just apply an offset to avoid conflict
srv_lib_venv_id_to_host_venv_user_id() {
    local venv_id=$1
    echo "$((${venv_id} + 20000))"
}
srv_lib_host_venv_user_id_to_venv_id() {
    local host_venv_user_id=$1
    echo "$((${host_venv_user_id} - 20000))"
}

srv_lib_map_guest_root_to_host_venv_user_id()
{
    local venv_id=$1
    local venv_user_id=$2
    local venv_user_name=$3

    srv_lib_add_line_to_file_if_not_present "lxc.idmap = u 0 ${venv_user_id} 1" "/etc/pve/lxc/${venv_id}.conf"
    srv_lib_add_line_to_file_if_not_present "lxc.idmap = g 0 ${venv_user_id} 1" "/etc/pve/lxc/${venv_id}.conf"
    srv_lib_add_line_to_file_if_not_present "lxc.idmap = u 1 100001 65535" "/etc/pve/lxc/${venv_id}.conf"
    srv_lib_add_line_to_file_if_not_present "lxc.idmap = g 1 100001 65535" "/etc/pve/lxc/${venv_id}.conf"

    srv_lib_add_line_to_file_if_not_present "root:${venv_user_id}:1" "/etc/subuid"
    srv_lib_add_line_to_file_if_not_present "root:${venv_user_id}:1" "/etc/subgid"

    pct mount ${venv_id}
    find "/var/lib/lxc/${venv_id}/rootfs" -user 100000 -exec chown ${venv_user_name} {} \;
    find "/var/lib/lxc/${venv_id}/rootfs" -group 100000 -exec chgrp ${venv_user_name} {} \;
    pct unmount ${venv_id}

    echo "LEAKED FILES START (should be empty):" # TODO GAG study/investigate this issue
    find / -user ${venv_user_id}
    find / -group ${venv_user_id}
    echo "Will now fix ownership..."
    find / -user ${venv_user_id} -exec chown root {} \;
    find / -group ${venv_user_id} -exec chgrp root {} \;
    echo "Print leaked files again"
    find / -user ${venv_user_id}
    find / -group ${venv_user_id}
    echo "LEAKED FILES END"
    # TODO GAG exclude mp to avoid fixing persmissions later
}

srv_lib_start_and_create_guest()
{
    local venv_id=$1
    local script_name=$2

    local script_basename="$(basename "${script_name}")"

    pct start ${venv_id}
    echo "Waiting 10 seconds for container to start and get an IP address..."
    sleep 10
    pct push ${venv_id} "${script_name}" "/tmp/${script_basename}"
    pct exec ${venv_id} -- bash "/tmp/${script_basename}" guest-create
}

srv_lib_venv_mp_create()
{
    local venv_user_name=$1
    local host_mp_dir=$2

    mkdir -p "${host_mp_dir}"
    chown "${venv_user_name}:${venv_user_name}" "${host_mp_dir}"
}
