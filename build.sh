#!/bin/sh

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
echo "ARCH=$ARCH" >> "$GITHUB_OUTPUT"

# install depedencies
manifest=$(docker manifest inspect arfshl/devuan:latest)
# Fetch image digest
digest=$(echo "$manifest" | jq -r ".manifests[] | select(.platform.architecture == \"$ARCH\") | .digest")
# Pull and Export image
docker pull "arfshl/devuan:latest@${digest}"
docker export $(docker create "arfshl/devuan:latest@${digest}") | xz -T 0 > "$GITHUB_WORKSPACE/devuan.tar.xz"

mkdir -p ./devuan
sudo tar -xJpf devuan.tar.xz -C ./devuan
cat <<-EOF | sudo unshare -mpf bash -e -
sudo mount --bind /dev ./devuan/dev
sudo mount --bind /proc ./devuan/proc
sudo mount --bind /sys ./devuan/sys
sudo rm -f ./devuan/etc/resolv.conf
sudo echo "nameserver 1.1.1.1" >> ./devuan/etc/resolv.conf

sudo chroot ./devuan apt update
#sudo chroot ./devuan apt purge -yq --allow-remove-essential coreutils-from-uutils
#sudo chroot ./devuan apt purge -yq --allow-remove-essential rust-coreutils
#sudo chroot ./devuan apt install -yq coreutils-from-gnu
#sudo chroot ./devuan apt install -yq gnu-coreutils
sudo chroot ./devuan apt install -yq locales passwd ca-certificates sudo libpam-systemd dbus systemd mesa-utils systemd-sysv
sudo chroot ./devuan apt clean

sudo chroot ./devuan sed -i 's/^# \(en_US.UTF-8\)/\1/' /etc/locale.gen
sudo chroot ./devuan /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales'

sudo rm -rf ./devuan/var/lib/apt/lists/*
sudo rm -rf ./devuan/var/tmp*
sudo rm -rf ./devuan/tmp*
EOF

sudo cp ./wslconf/oobe.sh ./devuan/etc/oobe.sh
sudo chmod 644 ./devuan/etc/oobe.sh
sudo chmod +x ./devuan/etc/oobe.sh
sudo cp ./wslconf/oobe.sh ./devuan/etc/wsl.conf
sudo chmod 644 ./devuan/etc/wsl.conf
sudo cp ./wslconf/wsl-distribution.conf ./devuan/etc/wsl-distribution.conf
sudo chmod 644 ./devuan/etc/wsl-distribution.conf
sudo mkdir -p ./devuan/usr/lib/wsl/
sudo cp ./wslconf/icon.ico ./devuan/usr/lib/wsl/icon.ico

cd ./devuan
sudo tar --numeric-owner --absolute-names -c  * | gzip --best > ../install.tar.gz
mv ../install.tar.gz ../devuan-$ARCH.wsl