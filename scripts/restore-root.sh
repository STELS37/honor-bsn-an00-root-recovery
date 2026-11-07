#!/system/bin/sh
# HONOR BSN-AN00: boot-aware wrapper around the unmodified upstream Root App.
# Intended for a Shizuku (uid 2000) / ADB shell after Root App assets are staged.
# Does not modify any boot/system partition, kill parked tasks, or try on unknown kernels.
set -u

D=/data/local/tmp/cveapp
EXPECTED_MODEL=BSN-AN00
EXPECTED_KERNEL=6.12.58-android16-6-g3a7ac1674240-abogki541502914-4k
die() { printf 'ROOT_RESTORE_FAIL=%s\n' "$1" >&2; exit 1; }
model=$(getprop ro.product.model 2>/dev/null)
kernel=$(uname -r 2>/dev/null)
uid=$(id -u 2>/dev/null)
[ "$model" = "$EXPECTED_MODEL" ] || die "unexpected_model:$model"
[ "$kernel" = "$EXPECTED_KERNEL" ] || die "unexpected_kernel:$kernel"
case "$uid" in 0|2000) ;; *) die "requires_adb_or_shizuku_shell_uid:$uid" ;; esac

printf 'MODEL=%s KERNEL=%s SHELL_UID=%s\n' "$model" "$kernel" "$uid"
# No duplicate use-after-free exploitation in an already-rooted boot.
if grep -q '^kernelsu ' /proc/modules 2>/dev/null; then
    printf 'KERNELSU_MODULE=loaded\n'
    out=$(su -c id 2>&1)
    if [ "$?" -eq 0 ] && printf '%s\n' "$out" | grep -q 'uid=0'; then
        printf '%s\n' "$out"
        printf 'ROOT_RESTORE=already_active\n'
        exit 0
    fi
    # The module is already in the running kernel. A second UAF chain here
    # would target the same boot and is not a userspace-repair mechanism.
    die "kernelsu_loaded_but_su_unavailable:inspect_kernelsu_userspace"
fi

[ -f "$D/run.sh" ] || die "assets_missing:open_root_app_and_deploy_assets"
[ -x "$D/magicroot" ] || die "native_launcher_missing:deploy_assets"
[ -r "$D/libmagicroot.so" ] || die "native_library_missing:deploy_assets"
boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
[ -n "$boot_id" ] || die "boot_id_unavailable"
if [ -f "$D/PARKED" ] && [ "$(cat "$D/PARKED" 2>/dev/null)" = "$boot_id" ]; then
    die "PARKED_same_boot:do_not_restart_or_kill_held_worker"
fi

# Atomic inter-process lock, separate from the app's in-process JobState.
# An interrupted attempt leaves a same-boot lock rather than risking a second run.
lock="$D/.root-restore.$boot_id.lock"
if ! mkdir "$lock" 2>/dev/null; then
    die "same_boot_recovery_already_in_progress_or_interrupted"
fi
unlock() { rmdir "$lock" 2>/dev/null || true; }
# Only normal completion removes the lock. SIGKILL/abnormal exit keeps the
# same-boot lock, preventing a blind retry.
printf 'ROOT_RESTORE=starting_upstream_run_sh\n'
sh "$D/run.sh" "$D/libmagicroot.so"
rc=$?
if [ "$rc" -ne 0 ]; then
    # A returned failure can still leave a parked UAF worker. Keep the
    # boot-scoped lock so an unattended callback never retries blindly.
    printf 'ROOT_RESTORE_FAIL=upstream_exit_%s; lock_retained_same_boot\n' "$rc" >&2
    exit "$rc"
fi
if ! grep -q '^kernelsu ' /proc/modules 2>/dev/null; then
    die "upstream_returned_without_kernelsu:lock_retained_same_boot"
fi
out=$(su -c id 2>&1)
if [ "$?" -ne 0 ] || ! printf '%s\n' "$out" | grep -q 'uid=0'; then
    die "upstream_returned_without_root_su:lock_retained_same_boot"
fi
printf '%s\n' "$out"
printf 'ROOT_RESTORE=verified_kernelsu_and_uid0\n'
unlock
exit 0
