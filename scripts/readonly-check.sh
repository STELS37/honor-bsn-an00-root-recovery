#!/system/bin/sh
# HONOR BSN-AN00: read-only Android build and module diagnostic.
# Run in a Shizuku/ADB shell; no exploit or partition modifications.
set +e
printf '%s\n' '=== ANDROID BUILD ==='
id
getprop ro.product.manufacturer
getprop ro.product.model
getprop ro.build.version.release
getprop ro.build.version.security_patch
uname -r
printf '%s\n' '=== BOOT STATE ==='
getprop ro.boot.flash.locked
getprop ro.boot.verifiedbootstate
getenforce 2>/dev/null || cat /sys/fs/selinux/enforce 2>/dev/null
printf '%s\n' '=== KERNELSU KERNEL MODULE ==='
if grep -q '^kernelsu ' /proc/modules 2>/dev/null; then
    grep '^kernelsu ' /proc/modules
else
    echo 'kernelsu module NOT observed in /proc/modules'
fi
printf '%s\n' '=== APPLICATIONS ==='
pm path com.rootcve.cve98260 2>/dev/null
pm path me.weishu.kernelsu 2>/dev/null
pm path com.rifsxd.ksunext 2>/dev/null
pm path moe.shizuku.privileged.api 2>/dev/null
printf '%s\n' '=== END ==='
