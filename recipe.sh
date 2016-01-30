#!/bin/bash

#wget http://download.qt.io/official_releases/qt/5.5/5.5.1/qt-opensource-linux-x64-5.5.1.run

# become root
sudo su

# Change directory to build. Everything happens in build.
mkdir build
cd build

######################################################
# download packages
######################################################
# epel-release for newest Qt
yum -y install epel-release git

# Need a newer gcc, getting it from Developer Toolset 2
wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
yum -y install devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
# /opt/rh/devtoolset-2/root/usr/bin/gcc
# now holds gcc and c++ 4.8.2
export PATH=$PATH:/opt/rh/devtoolset-2/root/usr/bin/


wget https://dl.bintray.com/otfried/generic/ipe/7.2/ipe-7.2.2-src.tar.gz

tar xfvz ipe-7.2.2-src.tar.gz
cd ipe-7.2.2
cd src
export QT_SELECT=5
make IPEPREFIX=.


