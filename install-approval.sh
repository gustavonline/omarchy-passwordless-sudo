#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
[[ $(id -u) == 0 ]] || { echo 'Run through sudo as the intended owner' >&2; exit 1; }
plugin_dir=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
approval_owner=${SUDO_USER:-${1:-}}
[[ $approval_owner =~ ^[a-z_][a-z0-9_-]{0,31}$ && $(id -u "$approval_owner") != 0 ]] || {
  echo 'A non-root owner is required' >&2; exit 1;
}
for dependency in python3 sudo visudo qrencode; do
  command -v "$dependency" >/dev/null || { echo "Install missing dependency: $dependency" >&2; exit 1; }
done
visudo -c
if [[ -e /etc/omarchy-sudo-approval-owner ]]; then
  [[ $(cat /etc/omarchy-sudo-approval-owner) == "$approval_owner" ]] || {
    echo 'A different owner is configured; refusing ownership change' >&2; exit 1;
  }
fi
install -d -o root -g root -m 0700 /var/lib/z13-admin
staging=$(mktemp -d /var/lib/z13-admin/.install-XXXXXX)
paths=(/etc/omarchy-sudo-approval-owner /usr/local/sbin/z13-admin /usr/local/sbin/z13-admin-enroll /etc/sudoers.d/90-z13-admin)
transaction=0
finish() {
  local result=$? index
  trap - EXIT
  if (( result != 0 && transaction )); then
    for index in "${!paths[@]}"; do
      rm -f -- "${paths[$index]}"
      if [[ -e $staging/backup-$index || -L $staging/backup-$index ]]; then
        cp -a -- "$staging/backup-$index" "${paths[$index]}"
      fi
    done
    visudo -c || echo 'Recovery policy validation failed; keep this administrator terminal open' >&2
    echo 'Installation failed; previous files restored' >&2
  fi
  rm -rf -- "$staging"
  exit "$result"
}
trap finish EXIT
for index in "${!paths[@]}"; do
  if [[ -e ${paths[$index]} || -L ${paths[$index]} ]]; then
    cp -a -- "${paths[$index]}" "$staging/backup-$index"
  fi
done
printf '%s\n' "$approval_owner" >"$staging/owner"
printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/z13-admin *\n%s ALL=(root) PASSWD: /usr/local/sbin/z13-admin-enroll enroll\n' \
  "$approval_owner" "$approval_owner" >"$staging/policy"
visudo -cf "$staging/policy"
install -m 0600 "$plugin_dir/approval/z13-admin" "$staging/broker"
python3 -I -m py_compile "$staging/broker"
transaction=1
install -o root -g root -m 0644 "$staging/owner" /etc/omarchy-sudo-approval-owner
for target in z13-admin z13-admin-enroll; do
  temporary=$(mktemp /usr/local/sbin/.agent-access-XXXXXX)
  if ! install -o root -g root -m 0755 "$staging/broker" "$temporary"; then
    rm -f -- "$temporary"
    exit 1
  fi
  mv -f -- "$temporary" "/usr/local/sbin/$target"
done
install -o root -g root -m 0440 "$staging/policy" /etc/sudoers.d/90-z13-admin
visudo -c
transaction=0
echo 'Omarchy Agent Access installed. Existing phone enrollment is preserved.'
