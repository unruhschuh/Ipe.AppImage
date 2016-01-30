#!/bin/bash

# Halt on errors
set -e

#wget http://download.qt.io/official_releases/qt/5.5/5.5.1/qt-opensource-linux-x64-5.5.1.run

# Change directory to build. Everything happens in build.
mkdir build
cd build

######################################################
# download packages
######################################################
# epel-release for newest Qt and stuff
#sudo yum -y install epel-release
sudo yum -y install readline-devel zlib-devel libpng-devel cairo-devel

# Need a newer gcc, getting it from Developer Toolset 2
sudo wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
sudo yum -y install devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
# /opt/rh/devtoolset-2/root/usr/bin/gcc
# now holds gcc and c++ 4.8.2
#scl enable devtoolset-2
source /opt/rh/devtoolset-2/enable

######################################################
# build libraries from source
######################################################
# libjpeg
wget http://www.ijg.org/files/jpegsrc.v8d.tar.gz
tar xfvz jpegsrc.v8d.tar.gz
cd jpeg-8d
./configure && make && sudo make install
cd ..

# lua
wget http://www.lua.org/ftp/lua-5.2.4.tar.gz
tar xfvz lua-5.2.4.tar.gz
cd lua-5.2.4
make linux && sudo make install
cd ..
cp ../lua5.2.pc /tmp
export PKG_CONFIG_PATH=/tmp

######################################################
# Install Qt
######################################################
wget http://download.qt.io/official_releases/online_installers/qt-unified-linux-x86-online.run
chmod +x qt-unified-linux-x86-online.run
./qt-unified-linux-x86-online.run --script qt-installer-noninteractive.qs
# wget http://download.qt.io/official_releases/qt/5.5/5.5.1/qt-opensource-linux-x64-5.5.1.run
# chmod +x qt-opensource-linux-x64-5.5.1.run
# ./qt-opensource-linux-x64-5.5.1.run --script qt-installer-noninteractive.qs

#sudo yum -y install qt5-qtbase-devel
# qt5-qtlocation-devel qt5-qtscript-devel qt5-qtwebkit-devel qt5-qtsvg-devel qt5-linguist qt5-qtconnectivity-devel

######################################################
# Building Ipe
######################################################
wget https://dl.bintray.com/otfried/generic/ipe/7.2/ipe-7.2.2-src.tar.gz

tar xfvz ipe-7.2.2-src.tar.gz
cd ipe-7.2.2
cd src
export QT_SELECT=5
make IPEPREFIX=.


