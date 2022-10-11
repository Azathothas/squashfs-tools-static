#!/bin/bash

export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apt 2>/dev/null)" ]
    then
        apt update && apt install -y \
            build-essential clang pkg-config git squashfs-tools fuse help2man \
            libzstd-dev liblz4-dev liblzo2-dev liblzma-dev zlib1g-dev \
            libfuse-dev libsquashfuse-dev libsquashfs-dev autoconf libtool upx
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
pushd build

# download squashfs-tools
git clone https://github.com/plougher/squashfs-tools.git
# squashfs_tools_version="$(cd squashfs-tools && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
squashfs_tools_version="$(cd squashfs-tools && git tag --list|tac|grep '^[0-9]'|head -1|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
mv squashfs-tools "squashfs-tools-${squashfs_tools_version}"
echo "= downloading squashfs-tools v${squashfs_tools_version}"

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building squashfs-tools"
pushd squashfs-tools-${squashfs_tools_version}/squashfs-tools
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" \
    XZ_SUPPORT=1 LZO_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1 \
    make INSTALL_DIR="$(pwd)/install" LDFLAGS="$LDFLAGS -Wl,--gc-sections" install
popd # squashfs-tools-${squashfs_tools_version}/squashfs-tools

popd # build

shopt -s extglob

echo "= extracting squashfs-tools binary"
mv build/squashfs-tools-${squashfs_tools_version}/squashfs-tools/install/* release 2>/dev/null

echo "= striptease"
for file in release/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
tar --xz -acf squashfs-tools-static-v${squashfs_tools_version}-${platform_arch}.tar.xz release
# cp squashfs-tools-static-*.tar.xz /root 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= squashfs-tools v${squashfs_tools_version} done"
