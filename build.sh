#!/bin/sh

# export the env
export RELEASE=excalibur
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH=amd64 ;;
    amd64) ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    arm64) ARCH=arm64 ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac
echo "RELEASE=$RELEASE" >> "$GITHUB_OUTPUT"
echo "ARCH=$ARCH" >> "$GITHUB_OUTPUT"

# install depedencies
curl -L -o /tmp/mmdebstrap.deb http://ftp.us.debian.org/debian/pool/main/m/mmdebstrap/mmdebstrap_1.5.7-3_all.deb
sudo apt install -yq /tmp/mmdebstrap.deb
curl -L -o /tmp/keyring.deb http://ftp.us.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb
sudo apt install -yq /tmp/keyring.deb
curl -L -o /tmp/devuankey.deb http://deb.devuan.org/merged/pool/DEVUAN/main/d/devuan-keyring/devuan-keyring_2025.08.09_all.deb
sudo apt install -yq /tmp/devuankey.deb

# start build with mmdebstrap and sprays some WD-40 to get rid of rust on coreutils
dist_version="$RELEASE"
export $components="main,contrib,non-free"
sudo mmdebstrap \
    --arch=$ARCH \
    --variant=minbase \
    --components="$components" \
    --include=locales,passwd,ca-certificates,sudo,dbus,mesa-utils \
    --format=directory \
    ${dist_version} \
    devuan \
    "deb http://deb.devuan.org/merged ${dist_version} $components" \
    "deb http://deb.devuan.org/merged ${dist_version}-updates $components" \
    "deb http://deb.devuan.org/merged ${dist_version}-security $components" \
    "deb http://deb.devuan.org/merged ${dist_version}-backports $components"

cat <<-EOF | sudo unshare -mpf bash -e -
sudo mount --bind /dev ./devuan/dev
sudo mount --bind /proc ./devuan/proc
sudo mount --bind /sys ./devuan/sys
sudo echo 'nameserver 1.1.1.1' >> ./devuan/etc/resolv.conf
sudo chroot ./devuan sed -i 's/^# \(en_US.UTF-8\)/\1/' /etc/locale.gen
sudo chroot ./devuan /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales'
sudo rm -rf ./devuan/var/lib/apt/lists/*
sudo rm -rf ./devuan/var/tmp*
sudo rm -rf ./devuan/tmp*
EOF

sudo cp ./wslconf/oobe.sh ./devuan/etc/oobe.sh
sudo chmod 644 ./devuan/etc/oobe.sh
sudo chmod +x ./devuan/etc/oobe.sh
sudo cp ./wslconf/wsl-distribution.conf ./devuan/etc/wsl-distribution.conf
sudo chmod 644 ./devuan/etc/wsl-distribution.conf
sudo mkdir -p ./devuan/usr/lib/wsl/
sudo cp ./wslconf/icon.ico ./devuan/usr/lib/wsl/icon.ico

cd ./devuan
sudo tar --numeric-owner --absolute-names -c  * | gzip --best > ../install.tar.gz
mv ../install.tar.gz ../devuan-$ARCH.wsl