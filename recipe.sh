#!/bin/bash

# Halt on errors
set -e

#wget http://download.qt.io/official_releases/qt/5.5/5.5.1/qt-opensource-linux-x64-5.5.1.run

######################################################
# download packages
######################################################
# epel-release for newest Qt and stuff
sudo yum -y install epel-release
sudo yum -y install readline-devel zlib-devel libpng-devel cairo-devel
sudo yum -y install cmake binutils fuse glibc-devel glib2-devel fuse-devel gcc zlib-devel libpng12 # AppImageKit dependencies

# Need a newer gcc, getting it from Developer Toolset 2
sudo wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
sudo yum -y install devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
# /opt/rh/devtoolset-2/root/usr/bin/gcc
# now holds gcc and c++ 4.8.2
#scl enable devtoolset-2
source /opt/rh/devtoolset-2/enable

######################################################
# Install Qt
######################################################
#wget http://download.qt.io/official_releases/online_installers/qt-unified-linux-x86-online.run
#chmod +x qt-unified-linux-x86-online.run
#./qt-unified-linux-x86-online.run --script qt-installer-noninteractive.qs
# wget http://download.qt.io/official_releases/qt/5.5/5.5.1/qt-opensource-linux-x64-5.5.1.run
# chmod +x qt-opensource-linux-x64-5.5.1.run
# ./qt-opensource-linux-x64-5.5.1.run --script qt-installer-noninteractive.qs

sudo yum -y install qt5-qtbase-devel qt5-qtbase-gui
sudo ln -s /usr/bin/moc-qt5 /usr/bin/moc
# qt5-qtlocation-devel qt5-qtscript-devel qt5-qtwebkit-devel qt5-qtsvg-devel qt5-linguist qt5-qtconnectivity-devel

######################################################
# build libraries from source
######################################################
# Change directory to build. Everything happens in build.
mkdir build
cd build

# libjpeg
wget http://www.ijg.org/files/jpegsrc.v8d.tar.gz
tar xfvz jpegsrc.v8d.tar.gz
cd jpeg-8d
./configure && make && sudo make install
cd ..

# lua
wget http://www.lua.org/ftp/lua-5.2.4.tar.gz
tar xfvz lua-5.2.4.tar.gz
cd lua-5.2.4/src
sed -i 's/^CFLAGS=/CFLAGS= -fPIC /g' Makefile
cd ..
make linux && sudo make install
cd ..
cp ../lua5.2.pc /tmp
export PKG_CONFIG_PATH=/tmp


######################################################
# Build Ipe
######################################################
wget https://dl.bintray.com/otfried/generic/ipe/7.2/ipe-7.2.2-src.tar.gz

tar xfvz ipe-7.2.2-src.tar.gz
cd ipe-7.2.2
cd src
export QT_SELECT=5
make IPEPREFIX=.
make install IPEPREFIX=/tmp/ipe/usr

cd ../../..

######################################################
# Build AppImageKit
######################################################
if [ ! -d AppImageKit ] ; then
  git clone https://github.com/probonopd/AppImageKit.git
fi
cd AppImageKit/
cmake .
make clean
make
cd ..

######################################################
# create AppDir
######################################################
APP=Ipe
APP_DIR=$APP.AppDir
APP_IMAGE=$APP.AppImage
IPE_SOURCE_DIR=build/ipe-7.2.2

mv /tmp/ipe/usr $APP_DIR

mkdir $APP_DIR
mkdir $APP_DIR/usr
#mkdir $APP_DIR/usr/bin
mkdir $APP_DIR/usr/bin/platforms
#mkdir $APP_DIR/usr/lib
mkdir $APP_DIR/usr/lib/qt5

cp AppImageKit/AppRun Ipe.AppDir/

cp ipe.png Ipe.AppDir/
cp Ipe.desktop $APP_DIR

cp -R /usr/lib64/qt5/plugins $APP_DIR/usr/lib/qt5/

ldd $APP_DIR/usr/lib/qt5/plugins/platforms/libqxcb.so | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib
ldd $APP_DIR/usr/bin/* | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib
find $APP_DIR/usr/lib -name "*.so*" | xargs ldd | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib

# The following are assumed to be part of the base system
rm -f $APP_DIR/usr/lib/libcom_err.so.2 || true
rm -f $APP_DIR/usr/lib/libcrypt.so.1 || true
rm -f $APP_DIR/usr/lib/libdl.so.2 || true
rm -f $APP_DIR/usr/lib/libexpat.so.1 || true
rm -f $APP_DIR/usr/lib/libfontconfig.so.1 || true
rm -f $APP_DIR/usr/lib/libgcc_s.so.1 || true
rm -f $APP_DIR/usr/lib/libglib-2.0.so.0 || true
rm -f $APP_DIR/usr/lib/libgpg-error.so.0 || true
rm -f $APP_DIR/usr/lib/libgssapi_krb5.so.2 || true
rm -f $APP_DIR/usr/lib/libgssapi.so.3 || true
rm -f $APP_DIR/usr/lib/libhcrypto.so.4 || true
rm -f $APP_DIR/usr/lib/libheimbase.so.1 || true
rm -f $APP_DIR/usr/lib/libheimntlm.so.0 || true
rm -f $APP_DIR/usr/lib/libhx509.so.5 || true
rm -f $APP_DIR/usr/lib/libICE.so.6 || true
rm -f $APP_DIR/usr/lib/libidn.so.11 || true
rm -f $APP_DIR/usr/lib/libk5crypto.so.3 || true
rm -f $APP_DIR/usr/lib/libkeyutils.so.1 || true
rm -f $APP_DIR/usr/lib/libkrb5.so.26 || true
rm -f $APP_DIR/usr/lib/libkrb5.so.3 || true
rm -f $APP_DIR/usr/lib/libkrb5support.so.0 || true
# rm -f $APP_DIR/usr/lib/liblber-2.4.so.2 || true # needed for debian wheezy
# rm -f $APP_DIR/usr/lib/libldap_r-2.4.so.2 || true # needed for debian wheezy
rm -f $APP_DIR/usr/lib/libm.so.6 || true
rm -f $APP_DIR/usr/lib/libp11-kit.so.0 || true
rm -f $APP_DIR/usr/lib/libpcre.so.3 || true
rm -f $APP_DIR/usr/lib/libpthread.so.0 || true
rm -f $APP_DIR/usr/lib/libresolv.so.2 || true
rm -f $APP_DIR/usr/lib/libroken.so.18 || true
rm -f $APP_DIR/usr/lib/librt.so.1 || true
rm -f $APP_DIR/usr/lib/libsasl2.so.2 || true
rm -f $APP_DIR/usr/lib/libSM.so.6 || true
rm -f $APP_DIR/usr/lib/libusb-1.0.so.0 || true
rm -f $APP_DIR/usr/lib/libuuid.so.1 || true
rm -f $APP_DIR/usr/lib/libwind.so.0 || true
rm -f $APP_DIR/usr/lib/libz.so.1 || true

######################################################
# Create AppImage
######################################################
# Convert the AppDir into an AppImage
AppImageKit/AppImageAssistant.AppDir/package ./$APP_DIR/ ./$APP_IMAGE


