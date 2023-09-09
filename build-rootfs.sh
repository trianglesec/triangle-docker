#!/bin/bash

set -e
set -u

image=$1
architecture=$2
mirror=${3:-http://trianglesec.github.io/triangle}

rootfsDir=rootfs-$image-$architecture
tarball=$image-$architecture.tar.gz
versionFile=$image-$architecture.release.version

rootfs_chroot() {
    PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
        chroot "$rootfsDir" "$@"
}

case $image in
    triangle-dev|triangle-rolling)
        distro=$image
        ;;
    triangle-last-release)
        distro=triangle-last-snapshot
        ;;
    *)
        echo "ERROR: unsupported image '$image'" >&2
        exit 1
        ;;
esac

if [ ! -e /usr/share/debootstrap/scripts/"$distro" ]; then
    echo "ERROR: debootstrap has no script for $distro" >&2
    echo "ERROR: use a newer debootstrap" >&2
    exit 1
fi

if [ ! -e /usr/share/keyrings/triangle-archive-keyring.gpg ]; then
    echo "ERROR: you need /usr/share/keyrings/triangle-archive-keyring.gpg" >&2
    echo "ERROR: install triangle-archive-keyring" >&2
    exit 1
fi

rm -rf "$rootfsDir" "$tarball"

ret=0
debootstrap --variant=minbase --components=main,contrib,non-free,non-free-firmware \
    --arch="$architecture" --include=triangle-archive-keyring \
    "$distro" "$rootfsDir" "$mirror" || ret=$?
if [ $ret != 0 ]; then
    [ -e "$rootfsDir"/debootstrap/debootstrap.log ] && \
        tail -v "$rootfsDir"/debootstrap/debootstrap.log
    exit $ret
fi

rootfs_chroot apt-get -y --no-install-recommends install triangle-defaults

rootfs_chroot apt-get clean

# Inspired by /usr/share/docker.io/contrib/mkimage/debootstrap
cat > "$rootfsDir/usr/sbin/policy-rc.d" <<-'EOF'
	#!/bin/sh
	exit 101
EOF
chmod +x "$rootfsDir/usr/sbin/policy-rc.d"

echo 'force-unsafe-io' > "$rootfsDir"/etc/dpkg/dpkg.cfg.d/docker-apt-speedup

aptGetClean='"rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true";'
cat > "$rootfsDir"/etc/apt/apt.conf.d/docker-clean <<-EOF
	DPkg::Post-Invoke { ${aptGetClean} };

	Dir::Cache::pkgcache "";
	Dir::Cache::srcpkgcache "";
EOF

echo 'Acquire::Languages "none";' >"$rootfsDir"/etc/apt/apt.conf.d/docker-no-languages

cat > "$rootfsDir"/etc/apt/apt.conf.d/docker-gzip-indexes <<-'EOF'
	Acquire::GzipIndexes "true";
	Acquire::CompressionTypes::Order:: "gz";
EOF

echo 'Apt::AutoRemove::SuggestsImportant "false";' >"$rootfsDir"/etc/apt/apt.conf.d/docker-autoremove-suggests

rm -f "$rootfsDir"/var/cache/ldconfig/aux-cache
rm -rf "$rootfsDir"/var/lib/apt/lists/*
mkdir -p "$rootfsDir"/var/lib/apt/lists/partial
find "$rootfsDir"/var/log -depth -type f -print0 | xargs -0 truncate -s 0

# https://github.com/debuerreotype/debuerreotype/pull/32
rmdir "$rootfsDir/run/mount" 2>/dev/null || :

echo "Creating $tarball"
tar -C "$rootfsDir" --exclude "./dev/**" -pczf "$tarball" .

if [ "$image" = "triangle-last-release" ]; then
    (. "$rootfsDir"/etc/os-release && echo "$VERSION") > "$versionFile"
fi
