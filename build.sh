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
echo "RELEASE=$RELEASE" >> "$GITHUB_ENV"
echo "ARCH=$ARCH" >> "$GITHUB_ENV"

# install depedencies
sudo apt update && sudo apt install -yq curl libarchive-tools
curl -L -o /tmp/mmdebstrap.deb http://ftp.us.debian.org/debian/pool/main/m/mmdebstrap/mmdebstrap_1.5.7-3_all.deb
sudo apt install -yq /tmp/mmdebstrap.deb
curl -L -o /tmp/keyring.deb http://ftp.us.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb
sudo apt install -yq /tmp/keyring.deb
curl -L -o /tmp/devuankey.deb http://deb.devuan.org/merged/pool/DEVUAN/main/d/devuan-keyring/devuan-keyring_2025.08.09_all.deb
sudo apt install -yq /tmp/devuankey.deb

# start build with mmdebstrap
dist_version="$RELEASE"
sudo mmdebstrap \
    --arch=$ARCH \
    --variant=minbase \
    --components="main,contrib,non-free" \
    --include=ca-certificates,locales,devuan-keyring \
    --format=tar \
    --customize-hook="chroot \$1 sed -i 's/^# \(en_US.UTF-8\)/\1/' /etc/locale.gen" \
    --customize-hook="chroot \$1 /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales'" \
    ${dist_version} \
    rootfs.tar..gz \
    "deb http://deb.devuan.org/merged ${dist_version} main contrib non-free" \
    "deb http://deb.devuan.org/merged ${dist_version}-updates main contrib non-free" \
    "deb http://deb.devuan.org/merged ${dist_version}-security main contrib non-free"

# combine wsldl and rootfs (with matching arch as machine)
if [ $ARCH = amd64 ]; then 
    curl -L https://github.com/yuk7/wsldl/releases/download/26032000/icons.zip -o icons.zip
    bsdtar -xf icons.zip
    mv Devuan.exe devuan.exe
    bsdtar -a -cf devuan.zip rootfs.tar.gz devuan.exe
else
    curl -L https://github.com/yuk7/wsldl/releases/download/26032000/icons_arm64.zip -o icons.zip
    bsdtar -xf icons.zip
    mv Devuan.exe devuan.exe
    bsdtar -a -cf devuan.zip rootfs.tar.gz devuan.exe
fi