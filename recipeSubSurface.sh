#!/bin/bash

# Compile Ipe and bundle it as an AppImage on CentOS 6
# By Thomas Leitz 01/2016
# based on the recipe for SubSurface by Simon Peter 11/2015
# at https://github.com/probonopd/AppImages

# Halt on errors
set -e

# Be verbose
set -x

# TODO: move to a library function
git_pull_rebase_helper()
{
	git reset --hard HEAD
        git pull
}

export PATH=/bin:/sbin:$PATH # For CentOS 6

if [ -z "$NO_DOWNLOAD" ] ; then
# Enable EPEL repository; needed for recent Qt and
# install dependencies
sudo yum -y install wget epel-release git make autoconf automake libtool \
        libzip-devel libxml2-devel libxslt-devel libsqlite3x-devel \
        libudev-devel libusbx-devel libcurl-devel libssh2-devel mesa-libGL-devel sqlite-devel \
        tar gzip which make autoconf automake gstreamer-devel mesa-libEGL coreutils grep wget

# Determine which architecture should be built
if [[ "$(/bin/arch)" = "i686" ||  "$(/bin/arch)" = "x86_64" ]] ; then
	ARCH=$(/bin/arch)
else
	echo "Architecture could not be determined"
	exit 1
fi

# Now we are inside CentOS 6
grep -r "CentOS release 6" /etc/redhat-release || exit 1

if [ ! -d AppImages ] ; then
  git clone https://github.com/probonopd/AppImages.git
fi
cd AppImages/
git_pull_rebase_helper
cd ..

# Need a newer gcc, getting it from Developer Toolset 2
sudo wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
sudo yum -y install devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
# /opt/rh/devtoolset-2/root/usr/bin/gcc
# now holds gcc and c++ 4.8.2

# Get newer version of cmake
# Install CMake 3.2.2 and Qt 5.5.x # https://github.com/vlc-qt/examples/blob/master/tools/ci/linux/install.sh
if [[ "$ARCH" = "x86_64" ]] ; then
	wget --no-check-certificate -c https://www.cmake.org/files/v3.2/cmake-3.2.2-Linux-x86_64.tar.gz
fi
if [[ "$ARCH" = "i686" ]] ; then
	wget --no-check-certificate -c https://cmake.org/files/v3.2/cmake-3.2.2-Linux-i386.tar.gz
fi
tar xf cmake-*.tar.gz

# EPEL is awesome - fresh Qt5 for old base systems
sudo yum -y install qt5-qtbase-devel qt5-qtlocation-devel qt5-qtscript-devel qt5-qtwebkit-devel qt5-qtsvg-devel qt5-linguist qt5-qtconnectivity-devel
fi

CMAKE_PATH=$(find $PWD/cmake-*/ -type d | head -n 1)bin
export LD_LIBRARY_PATH=/opt/rh/devtoolset-2/root/usr/lib:$LD_LIBRARY_PATH # Needed for bundling the libraries into AppDir below
export PATH=/opt/rh/devtoolset-2/root/usr/bin/:$CMAKE_PATH:$PATH # Needed at compile time to find Qt and cmake

if [ -z "$NO_DOWNLOAD" ] ; then
# Install AppImageKit build dependencies
sudo yum -y install binutils fuse glibc-devel glib2-devel fuse-devel gcc zlib-devel libpng12 # Fedora, RHEL, CentOS

# Build AppImageKit
if [ ! -d AppImageKit ] ; then
  git clone https://github.com/probonopd/AppImageKit.git
fi
cd AppImageKit/
git_pull_rebase_helper
cmake .
make clean
make
cd ..
fi

APP=Subsurface
rm -rf ./$APP/$APP.AppDir
mkdir -p ./$APP/$APP.AppDir
cd ./$APP

# Get latest subsurface project from git
if [ ! -d subsurface ] ; then
  git clone git://subsurface-divelog.org/subsurface
fi
cd subsurface/
git_pull_rebase_helper
cd ..

# this is a bit hackish as the build.sh script isn't setup in
# the best possible way for us
mkdir -p $APP.AppDir/usr
INSTALL_ROOT=$(cd $APP.AppDir/usr; pwd)
sed -i -e 's|SUBSURFACE_EXECUTABLE=MobileExecutable|SUBSURFACE_EXECUTABLE=DesktopExecutable|g' ./subsurface/scripts/build.sh
sed -i "s,INSTALL_ROOT=.*,INSTALL_ROOT=$INSTALL_ROOT," ./subsurface/scripts/build.sh
sed -i "s,cmake -DCMAKE_BUILD_TYPE=Debug.*,cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_ROOT .. \\\\," ./subsurface/scripts/build.sh
bash -ex ./subsurface/scripts/build.sh
( cd subsurface/build ; make install )

cp ./subsurface/subsurface.desktop $APP.AppDir/
# Workaround for:
# https://github.com/torvalds/subsurface/pull/124
sed -i -e 's|Name=subsurface|Name=Subsurface|g' $APP.AppDir/subsurface.desktop
cp ./subsurface/icons/subsurface-icon.svg $APP.AppDir/

# Bundle dependency libraries into the AppDir
cd $APP.AppDir/
cp ../../AppImageKit/AppRun .
chmod a+x AppRun
# FIXME: How to find out which subset of plugins is really needed? I used strace when running the binary
mkdir -p ./usr/lib/qt5/plugins/

if [ -e $(dirname /usr/li*/qt5/plugins/bearer) ] ; then
  PLUGINS=$(dirname /usr/li*/qt5/plugins/bearer)
else
  PLUGINS=../../5.5/gc*/plugins/
fi
echo $PLUGINS # /usr/lib64/qt5/plugins if build system Qt is found
cp -r $PLUGINS/bearer ./usr/lib/qt5/plugins/
cp -r $PLUGINS/iconengines ./usr/lib/qt5/plugins/
cp -r $PLUGINS/imageformats ./usr/lib/qt5/plugins/
cp -r $PLUGINS/platforminputcontexts ./usr/lib/qt5/plugins/
cp -r $PLUGINS/platforms ./usr/lib/qt5/plugins/
cp -r $PLUGINS/platformthemes ./usr/lib/qt5/plugins/
cp -r $PLUGINS/sensors ./usr/lib/qt5/plugins/
cp -r $PLUGINS/xcbglintegrations ./usr/lib/qt5/plugins/

if [ -e $(dirname /usr/li*/libicudata.so.42) ] ; then
  LIB=$(dirname /usr/li*/libicudata.so.42)
else
  LIB=../../5.5/gc*/lib
fi
echo $LIB
cp -a $LIB/libicu* usr/lib

export LD_LIBRARY_PATH=./usr/lib/:../../5.5/gc*/lib/:$LD_LIBRARY_PATH
ldd usr/bin/subsurface | grep "=>" | awk '{print $3}'  |  xargs -I '{}' cp -v '{}' ./usr/lib || true
ldd usr/lib/qt5/plugins/platforms/libqxcb.so | grep "=>" | awk '{print $3}'  |  xargs -I '{}' cp -v '{}' ./usr/lib || true

# The following are assumed to be part of the base system
rm -f usr/lib/libcom_err.so.2 || true
rm -f usr/lib/libcrypt.so.1 || true
rm -f usr/lib/libdl.so.2 || true
rm -f usr/lib/libexpat.so.1 || true
rm -f usr/lib/libfontconfig.so.1 || true
rm -f usr/lib/libgcc_s.so.1 || true
rm -f usr/lib/libglib-2.0.so.0 || true
rm -f usr/lib/libgpg-error.so.0 || true
rm -f usr/lib/libgssapi_krb5.so.2 || true
rm -f usr/lib/libgssapi.so.3 || true
rm -f usr/lib/libhcrypto.so.4 || true
rm -f usr/lib/libheimbase.so.1 || true
rm -f usr/lib/libheimntlm.so.0 || true
rm -f usr/lib/libhx509.so.5 || true
rm -f usr/lib/libICE.so.6 || true
rm -f usr/lib/libidn.so.11 || true
rm -f usr/lib/libk5crypto.so.3 || true
rm -f usr/lib/libkeyutils.so.1 || true
rm -f usr/lib/libkrb5.so.26 || true
rm -f usr/lib/libkrb5.so.3 || true
rm -f usr/lib/libkrb5support.so.0 || true
# rm -f usr/lib/liblber-2.4.so.2 || true # needed for debian wheezy
# rm -f usr/lib/libldap_r-2.4.so.2 || true # needed for debian wheezy
rm -f usr/lib/libm.so.6 || true
rm -f usr/lib/libp11-kit.so.0 || true
rm -f usr/lib/libpcre.so.3 || true
rm -f usr/lib/libpthread.so.0 || true
rm -f usr/lib/libresolv.so.2 || true
rm -f usr/lib/libroken.so.18 || true
rm -f usr/lib/librt.so.1 || true
rm -f usr/lib/libsasl2.so.2 || true
rm -f usr/lib/libSM.so.6 || true
rm -f usr/lib/libusb-1.0.so.0 || true
rm -f usr/lib/libuuid.so.1 || true
rm -f usr/lib/libwind.so.0 || true
rm -f usr/lib/libz.so.1 || true

# These seem to be available on most systems but not Ubuntu 11.04
# rm -f usr/lib/libffi.so.6 usr/lib/libGL.so.1 usr/lib/libglapi.so.0 usr/lib/libxcb.so.1 usr/lib/libxcb-glx.so.0 || true

# Accoring to the Subsurface upstream project, these are not needed in the AppImage
rm -f usr/lib/libdivecomputer.a || true
rm -f usr/lib/libdivecomputer.la || true
rm -f usr/lib/libdivecomputer.so || true
rm -f usr/lib/libdivecomputer.so.0 || true
rm -f usr/lib/libdivecomputer.so.0.0.0 || true
rm -f usr/lib/libGrantlee_TextDocument.so || true
rm -f usr/lib/libGrantlee_TextDocument.so.5.0.0 || true
rm -f usr/lib/libssrfmarblewidget.so || true
rm -f usr/lib/subsurface || true
rm -f usr/bin/universal || true
rm -f usr/bin/ostc-fwupdate || true
rm -f usr/bin/subsurface.debug || true

# Delete potentially dangerous libraries
rm -f usr/lib/libstdc* usr/lib/libgobject* usr/lib/libc.so.* || true
# Do NOT delete libX* because otherwise on Ubuntu 11.04:
# loaded library "Xcursor" malloc.c:3096: sYSMALLOc: Assertion (...) Aborted

# We don't bundle the developer stuff
rm -rf usr/include || true
rm -rf usr/lib/cmake || true
rm -rf usr/lib/pkgconfig || true

strip usr/bin/* usr/lib/* || true

# According to http://www.grantlee.org/apidox/using_and_deploying.html
# Grantlee looks for plugins in $QT_PLUGIN_DIR/grantlee/$grantleeversion/
mv ./usr/lib/grantlee/ ./usr/lib/qt5/plugins/
# Fix GDK_IS_PIXBUF errors on older distributions

# TODO: Move all cp lib things to using ldconfig because it is more robust 
# across different build system distributions and architectures.
# It is the equivalent for "find" for libraries.
cp $(ldconfig -p | grep libsasl2.so.2 | cut -d ">" -f 2 | xargs) ./usr/lib/
cp $(ldconfig -p | grep libpng12.so.0 | cut -d ">" -f 2 | xargs) ./usr/lib/
# cp $(ldconfig -p | grep libGL.so.1 | cut -d ">" -f 2 | xargs) ./usr/lib/ # otherwise segfaults!?
cp $(ldconfig -p | grep libGLU.so.1 | cut -d ">" -f 2 | xargs) ./usr/lib/ # otherwise segfaults!?
# Fedora 23 seemed to be missing SOMETHING from the Centos 6.7. The only message was:
# This application failed to start because it could not find or load the Qt platform plugin "xcb".
# Setting export QT_DEBUG_PLUGINS=1 revealed the cause.
# QLibraryPrivate::loadPlugin failed on "/usr/lib64/qt5/plugins/platforms/libqxcb.so" : 
# "Cannot load library /usr/lib64/qt5/plugins/platforms/libqxcb.so: (/lib64/libEGL.so.1: undefined symbol: drmGetNodeTypeFromFd)"
# Which means that we have to copy libEGL.so.1 in too
cp $(ldconfig -p | grep libEGL.so.1 | cut -d ">" -f 2 | xargs) ./usr/lib/ # Otherwise F23 cannot load the Qt platform plugin "xcb"
# cp $(ldconfig -p | grep libxcb.so.1 | cut -d ">" -f 2 | xargs) ./usr/lib/ 

# I have no clue why but on i386 systems this seems to be required
if [[ "$ARCH" = "i686" ]] ; then
	cp $(ldconfig -p | grep libgbm.so.1 | cut -d ">" -f 2 | xargs) ./usr/lib/ 
fi

# On openSUSE Qt is picking up the wrong libqxcb.so
# (the one from the system when in fact it should use the bundled one) - is this a Qt bug?
# Hence, we binary patch /usr/lib* to $CWD/lib* which works because at runtime,
# the current working directory is set to usr/ inside the AppImage before running the app
cd usr/ ; find . -type f -exec sed -i -e 's|/usr/lib|././/lib|g' {} \; ; cd ..

cp $(ldconfig -p | grep libfreetype.so.6 | cut -d ">" -f 2 | xargs) ./usr/lib/ # For Fedora 20

# Add desktop integration - TODO: move to a library function
XAPP=subsurface
wget -O ./usr/bin/$XAPP.wrapper https://raw.githubusercontent.com/probonopd/AppImageKit/master/desktopintegration
chmod a+x ./usr/bin/$XAPP.wrapper
sed -i -e "s|Exec=$XAPP|Exec=$XAPP.wrapper|g" $XAPP.desktop

# Remove blacklisted files - TODO: move to a library function
if [ ! -e "../../AppImages/excludelist" ] ; then
  echo "excludelist missing, please install it"
  exit 1
fi
BLACKLISTED_FILES=$(cat "../../AppImages/excludelist" | sed '/^\s*$/d' | sed '/^#.*$/d')
FOUND=""
for FILE in $BLACKLISTED_FILES ; do
  FOUND=$(find "${APPDIR}" -type f -name "${FILE}" 2>/dev/null)
  echo $FOUND
  if [ ! -z "$FOUND" ] ; then
    fatal "Blacklisted file ${FOUND} found"
  fi
done

cd ..
find $APP.AppDir/

# Figure out $VERSION
GITVERSION=$(cd subsurface ; git describe | sed -e 's/-g.*$// ; s/^v//')
GITREVISION=$(echo $GITVERSION | sed -e 's/.*-// ; s/.*\..*//')
VERSION=$(echo $GITVERSION | sed -e 's/-/./')
echo $VERSION

if [[ "$ARCH" = "x86_64" ]] ; then
	APPIMAGE=$APP"-"$VERSION"-x86_64.AppImage"
fi
if [[ "$ARCH" = "i686" ]] ; then
	APPIMAGE=$APP"-"$VERSION"-i386.AppImage"
fi

# Put this script into the AppImage for debugging
# FIXME: The follwing line does not work
# cp $(readlink --canonicalize $0) ./$APP.AppDir/$APP.recipe

mkdir -p ../out

rm -f ../out/*.AppImage || true

# Convert the AppDir into an AppImage
rm -rf $APPIMAGE
../AppImageKit/AppImageAssistant.AppDir/package ./$APP.AppDir/ ../out/$APPIMAGE

chmod a+rwx ../out/$APPIMAGE # So that we can edit the AppImage outside of the Docker container
ls -lh ../out/$APPIMAGE

