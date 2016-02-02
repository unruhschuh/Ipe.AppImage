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

mkdir $APP_DIR
mkdir $APP_DIR/usr
mkdir $APP_DIR/usr/bin
mkdir $APP_DIR/usr/bin/platforms
mkdir $APP_DIR/usr/lib
mkdir $APP_DIR/usr/lib/qt5
mkdir $APP_DIR/usr/lib/qt5/plugins

cp AppImageKit/AppRun Ipe.AppDir/

cp ipe.png Ipe.AppDir/
cp Ipe.desktop $APP_DIR
cp $IPE_SOURCE_DIR/build/bin/* $APP_DIR/usr/bin
cp $IPE_SOURCE_DIR/src/ipe/lua/* $APP_DIR/usr/bin
cp $IPE_SOURCE_DIR/build/lib/* $APP_DIR/usr/lib
#cp /usr/lib64/qt5/plugins/platforms/libqxcb.so $APP_DIR/usr/bin/platforms
cp /usr/lib64/qt5/plugins/platforms/libqxcb.so $APP_DIR/usr/lib/qt5/plugins

cp /usr/lib64/libicudata.so.42 $APP_DIR/usr/lib
cp /usr/lib64/libicui18n.so.42 $APP_DIR/usr/lib
cp /usr/lib64/libicuuc.so.42 $APP_DIR/usr/lib
cp /usr/local/lib/libjpeg.so.8 $APP_DIR/usr/lib
cp /usr/lib64/libpng12.so.0 $APP_DIR/usr/lib

cp /usr/lib64/libQt5Core.so.5 $APP_DIR/usr/lib
cp /usr/lib64/libQt5Gui.so.5 $APP_DIR/usr/lib
cp /usr/lib64/libQt5Widgets.so.5 $APP_DIR/usr/lib
cp /usr/lib64/libQt5DBus.so.5 $APP_DIR/usr/lib
cp /usr/lib64/libQt5XcbQpa.so.5 $APP_DIR/usr/lib
cp /usr/lib64/libstdc++.so.6 $APP_DIR/usr/lib 

find . -name "*.so*" | xargs ldd | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib
#ldd /usr/lib64/*.so* | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib
#ldd /usr/lib64/libQt5XcbQpa.so.5 | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $APP_DIR/usr/lib

# This application failed to start because it could not find or load the Qt platform plugin "xcb".
# Setting export QT_DEBUG_PLUGINS=1 revealed the cause.
#
# QLibraryPrivate::loadPlugin failed on "/usr/lib64/qt5/plugins/platforms/libqxcb.so" : "Cannot load library /usr/lib64/qt5/plugins/platforms/libqxcb.so: (libxcb-sync.so.0: cannot open shared object file: No such file or directory)"
#
# ... and then some

#cp /usr/lib64/libxcb-sync.so.0 Ipe.AppDir/usr/lib/
#cp /lib64/libudev.so.0 Ipe.AppDir/usr/lib/

######################################################
# Create AppImage
######################################################
# Convert the AppDir into an AppImage
AppImageKit/AppImageAssistant.AppDir/package ./$APP_DIR/ ./$APP_IMAGE


