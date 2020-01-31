#!/usr/bin/env bash

########################################################################
# Package the binaries built on Travis-CI as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
# Report issues to https://github.com/Beep6581/RawTherapee/issues
########################################################################

# Fail handler
die () {
    printf '%s\n' "" "Aborting!" ""
    set +x
    exit 1
}

trap die HUP INT QUIT ABRT TERM

printf '%s\n' "SELFIDENT begin: appimage-centos7.sh"

# Enable debugging output until this is ready for merging
#set -x

# Program name
APP="RawTherapee"
LOWERAPP=${APP,,}

# TODO was: PREFIX=app .......?!
# PREFIX must be set to a 3-character string that represents the path where all compiled code,
# including RT, is installed. For example, if PREFIX=zyx it means that RT is installed under /zyx

# Prefix (without the leading "/") in which RawTherapee and its dependencies are installed:
export PREFIX="$AIPREFIX"
export AI_SCRIPTS_DIR="/sources/ci"

# Get the latest version of the AppImage helper functions,
# or use a fallback copy if not available:
#if ! wget "https://github.com/probonopd/AppImages/raw/master/functions.sh" --output-document="./functions.sh"; then
#    cp -a "${TRAVIS_BUILD_DIR}/ci/functions.sh" ./functions.sh || exit 1
#fi

mkdir -p /work || exit 1
cd /work || exit 1
rm -rf appimage-helper-scripts
git clone https://github.com/aferrero2707/appimage-helper-scripts.git  || exit 1
cd appimage-helper-scripts || exit 1
# Source the script:
source ./functions.sh


#rm -f "./functions.sh"
#wget "https://github.com/aferrero2707/appimage-helper-scripts/raw/master/functions.sh" --output-document="./functions.sh" || exit 1
#cat "./functions.sh"
#cp /sources/ci/functions.sh "./functions.sh"
# Source the script:
#. ./functions.sh

echo ""
echo "########################################################################"
echo ""
echo "AppImage configuration:"
echo "  APP: \"$APP\""
echo "  LOWERAPP: \"$LOWERAPP\""
echo "  PREFIX: \"$PREFIX\""
echo "  AI_SCRIPTS_DIR: \"${AI_SCRIPTS_DIR}\""
echo ""

########################################################################
# Additional helper functions:
########################################################################


# Remove absolute paths from pango modules cache (if existing)
patch_pango()
{
    pqm="$(which pango-querymodules)"
    if [[ ! -z $pqm ]]; then
        version="$(pango-querymodules --version | tail -n 1 | tr -d " " | cut -d':' -f 2)"
        cat "/${PREFIX}/lib/pango/${version}/modules.cache" | sed "s|/${PREFIX}/lib/pango/${version}/modules/||g" > "usr/lib/pango/${version}/modules.cache"
    fi
}

# Remove debugging symbols from AppImage binaries and libraries
strip_binaries()
{
    chmod u+w -R "${APPDIR}"
    {
        find "${APPDIR}/usr" -type f -name "${LOWERAPP}*" -print0
        find "${APPDIR}" -type f -regex '.*\.so\(\.[0-9.]+\)?$' -print0
    } | xargs -0 --no-run-if-empty --verbose -n1 strip
}


# Set environment variables to allow finding the dependencies that are
# compiled from sources
export PATH="/${PREFIX}/bin:/work/inst/bin:${PATH}"
export LD_LIBRARY_PATH="/${PREFIX}/lib:/${PREFIX}/lib64:/work/inst/lib:/work/inst/lib64:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/${PREFIX}/lib/pkgconfig://${PREFIX}/lib64/pkgconfig:/work/inst/lib/pkgconfig:${PKG_CONFIG_PATH}"

locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"


# Add some required packages
yum install -y https://centos7.iuscommunity.org/ius-release.rpm #|| exit 1
yum update -y #|| exit 1
yum install -y wget curl lcms2-devel gtk-doc libcroco-devel which python36u python36u-libs python36u-devel python36u-pip gnome-common || exit 1
sudo yum -y install  https://centos7.iuscommunity.org/ius-release.rpm
sudo yum -y install  git2u-all

cd /usr/bin
ln -f -s python3.6 python3
ln -f -s python3.6-config python3-config
#exit 0

DO_BUILD=0
if [ ! -e /work/build.done ]; then
	DO_BUILD=1
fi

if [ x"$DO_BUILD" = "x1" ]; then

echo ""
echo "########################################################################"
echo ""
echo "Installing additional system packages"
echo ""

(cd /work && rm -rf libiptcdata* && wget https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/libiptcdata/1.0.4-6ubuntu1/libiptcdata_1.0.4.orig.tar.gz && tar xzvf libiptcdata_1.0.4.orig.tar.gz && cd libiptcdata-1.0.4 && ./configure --prefix=/$AIPREFIX && make -j 2 install) || exit 1


# Install missing six python module
cd /work || exit 1
rm -f get-pip.py
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install six || exit 1
#python3 get-pip.py
#pip install six || exit 1
#exit




echo ""
echo "########################################################################"
echo ""
echo "Building and installing zenity"
echo ""

(cd /work && rm -rf zenity && git clone https://github.com/aferrero2707/zenity.git && \
cd zenity && ./autogen.sh && ./configure --prefix=/${PREFIX} && make install) || exit 1

#exit


echo ""
echo "########################################################################"
echo ""
echo "Building and installing expat 2.2.5"
echo ""

cd /work || exit 1
rm -rf expat*
wget https://github.com/libexpat/libexpat/releases/download/R_2_2_5/expat-2.2.5.tar.bz2
tar xvf expat-2.2.5.tar.bz2
cd "expat-2.2.5" || exit 1
(./configure --prefix=/$AIPREFIX && make -j 2 install) || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Building and installing libtiff 4.0.9"
echo ""

cd /work || exit 1
rm -rf tiff*
wget http://download.osgeo.org/libtiff/tiff-4.0.9.tar.gz || exit 1
tar xvf tiff-4.0.9.tar.gz || exit 1
(cd "tiff-4.0.9" && ./configure --prefix=/$AIPREFIX && make -j 2 install) || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Building and installing librsvg"
echo ""

cd /work || exit 1
curl https://sh.rustup.rs -sSf > ./r.sh && bash ./r.sh -y
export PATH=$HOME/.cargo/bin:$PATH
(rm -rf librsvg* && wget http://ftp.gnome.org/pub/gnome/sources/librsvg/2.40/librsvg-2.40.16.tar.xz && tar xvf librsvg-2.40.16.tar.xz && cd librsvg-2.40.16 && ./configure --prefix=/$AIPREFIX && make -j 2 install) || exit 1


LFV=0.3.2
echo ""
echo "########################################################################"
echo ""
echo "Building and installing LensFun $LFV"
echo ""

# Lensfun build and install
cd /work || exit 1
rm -rf lensfun*
#wget "https://sourceforge.net/projects/lensfun/files/$LFV/lensfun-${LFV}.tar.gz"
#tar xzvf "lensfun-${LFV}.tar.gz"
wget https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/lensfun/0.3.2-4/lensfun_0.3.2.orig.tar.gz
tar xzvf "lensfun_0.3.2.orig.tar.gz"
cd "lensfun-${LFV}" || exit 1
patch -p1 < $AI_SCRIPTS_DIR/lensfun-glib-libdir.patch
mkdir -p build
cd build || exit 1
rm -f CMakeCache.txt
cmake \
    -DCMAKE_BUILD_TYPE="release" \
    -DCMAKE_INSTALL_PREFIX="/${PREFIX}" \
    ../ || exit 1
make --jobs=2 VERBOSE=1 || exit 1
make install || exit 1

echo ""
echo "########################################################################"
echo ""
echo "Install Hicolor and Adwaita icon themes"

(cd /work && rm -rf hicolor-icon-theme-0.* && \
wget http://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.17.tar.xz && \
tar xJf hicolor-icon-theme-0.17.tar.xz && cd hicolor-icon-theme-0.17 && \
./configure --prefix=/${PREFIX} && make install && rm -rf hicolor-icon-theme-0.*) || exit 1
echo "icons after hicolor installation:"
ls /${PREFIX}/share/icons
echo ""

(cd /work && rm -rf adwaita-icon-theme-3.* && \
wget http://ftp.gnome.org/pub/gnome/sources/adwaita-icon-theme/3.26/adwaita-icon-theme-3.26.0.tar.xz && \
tar xJf adwaita-icon-theme-3.26.0.tar.xz && cd adwaita-icon-theme-3.26.0 && \
./configure --prefix=/${PREFIX} && make install && rm -rf adwaita-icon-theme-3.26.0*) || exit 1
echo "icons after adwaita installation:"
ls /${PREFIX}/share/icons
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Building and installing RawTherapee"
echo ""

cd /sources
export GIT_DESCRIBE=$(git describe)
#patch -N -p0 < /sources/ci/rt-lensfundbdir.patch || exit 1

# RawTherapee build and install
if [ x"${RT_BRANCH}" = "xreleases" ]; then
    CACHE_SUFFIX=""
else
    CACHE_SUFFIX="5-${RT_BRANCH}-ai"
fi
echo "RT cache suffix: \"${CACHE_SUFFIX}\""
mkdir -p /work/build/rt
cd /work/build/rt || exit 1
rm -f /work/build/rt/CMakeCache.txt
cmake \
    -DCMAKE_BUILD_TYPE="release"  \
    -DCACHE_NAME_SUFFIX="${CACHE_SUFFIX}" \
    -DPROC_TARGET_NUMBER="0" \
    -DBUILD_BUNDLE="ON" \
    -DCMAKE_INSTALL_PREFIX="/${PREFIX}/rt" \
    -DBUNDLE_BASE_INSTALL_DIR="/${PREFIX}/rt/bin" \
    -DDATADIR=".." \
    -DLENSFUNDBDIR="share/lensfun/version_1" \
    -DOPTION_OMP="ON" \
    -DWITH_LTO="OFF" \
    -DWITH_PROF="OFF" \
    -DWITH_SAN="OFF" \
    -DWITH_SYSTEM_KLT="OFF" \
    /sources || exit 1
make --jobs=2 || exit 1
make install || exit 1

touch /work/build.done

fi


echo ""
echo "########################################################################"
echo ""
echo "Creating and cleaning AppImage folder"

# Create a folder in the shared area where the AppImage structure will be copied
mkdir -p /work/appimage
cd /work/appimage || exit 1
#cp "${AI_SCRIPTS_DIR}"/excludelist . || exit 1
wget -q https://raw.githubusercontent.com/aferrero2707/appimage-helper-scripts/master/excludelist -O ./excludelist
export APPIMAGEBASE="$(pwd)"

# Remove old AppDir structure (if existing)
rm -rf "${APP}.AppDir"
mkdir -p "${APP}.AppDir/usr/"
cd "${APP}.AppDir" || exit 1
export APPDIR="$(pwd)"
echo "  APPIMAGEBASE: \"$APPIMAGEBASE\""
echo "  APPDIR: \"$APPDIR\""
echo ""

#sudo chown -R "$USER" "/${PREFIX}/"

echo ""
echo "########################################################################"
echo ""
echo "Copy executable"

echo ""
echo "########################################################################"
echo ""
echo "Copy RT folders"
echo ""

# Copy RT folders
mkdir -p usr/share
echo "cp -a \"/$PREFIX/rt\"/* usr"
cp -a "/$PREFIX/rt"/* usr || exit 1

cp -a /${PREFIX}/bin/zenity usr/bin
cp -a /${PREFIX}/share/zenity usr/share

# Copy main RT executable into $APPDIR/usr/bin/rawtherapee
#mkdir -p ./usr/bin
#echo "cp -a \"/${PREFIX}/rt/bin/${LOWERAPP}\" \"./usr/bin/${LOWERAPP}\""
#cp -a "/${PREFIX}/rt/bin/${LOWERAPP}" "./usr/bin/${LOWERAPP}" || exit 1
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Copy dependencies"
echo ""

# Bundle GTK2 stuff
/work/appimage-helper-scripts/bundle-gtk2.sh



# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps2; copy_deps2; copy_deps2;



if [ "x" = "y" ]; then
echo ""
echo "########################################################################"
echo ""
echo "Copy MIME files"
echo ""

# Copy MIME files
mkdir -p usr/share/image
cp -a /usr/share/mime/image/x-*.xml usr/share/image || exit 1
fi



echo ""
echo "########################################################################"
echo ""
echo 'Move all libraries into $APPDIR/usr/lib'
echo ""

# Move all libraries into $APPDIR/usr/lib
move_lib


echo ""
echo "########################################################################"
echo ""
echo "Delete blacklisted libraries"
echo ""

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted2
#exit

echo ""
echo "########################################################################"
echo ""
echo "Copy libfontconfig into the AppImage"
echo ""

# Copy libfontconfig into the AppImage
# It will be used if they are newer than those of the host
# system in which the AppImage will be executed
mkdir -p usr/optional/fontconfig
#echo "ls /${PREFIX}/lib:"
#ls /${PREFIX}/lib
fc_prefix="$(pkg-config --variable=libdir fontconfig)"
cp -a "${fc_prefix}/libfontconfig"* usr/optional/fontconfig || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Copy libstdc++.so.6 and libgomp.so.1 into the AppImage"
echo ""

copy_gcc_libs


echo ""
echo "########################################################################"
echo ""
echo "Copy desktop file and application icon"

# Copy desktop and icon file to AppDir for AppRun to pick them up
#mkdir -p usr/share/applications/
#echo "cp \"/${PREFIX}/share/applications/rawtherapee.desktop\" \"usr/share/applications\""
#cp "/${PREFIX}/share/applications/rawtherapee.desktop" "usr/share/applications" || exit 1

# Copy hicolor icon theme
mkdir -p usr/share/icons
echo "cp -r \"/${PREFIX}/share/icons/\"* \"usr/share/icons\""
cp -r "/${PREFIX}/share/icons/"* "usr/share/icons" || exit 1
#echo ""


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

# TODO Might want to "|| exit 1" these, and generate_status
#get_apprun || exit 1
cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
#cp -a "${AI_SCRIPTS_DIR}/fixes.sh" . || exit 1
cp -a /work/appimage-helper-scripts/apprun-helper.sh "./apprun-helper.sh" || exit 1
cp -a "${AI_SCRIPTS_DIR}/check_updates.sh" . || exit 1
cp -a "${AI_SCRIPTS_DIR}/zenity.sh" usr/bin || exit 1
#wget -q https://raw.githubusercontent.com/aferrero2707/appimage-helper-scripts/master/apprun-helper.sh -O "./apprun-helper.sh" || exit 1
get_desktop || exit 1
get_icon || exit 1

#exit


echo ""
echo "########################################################################"
echo ""
echo "Copy locale messages"
echo ""

# The fonts configuration should not be patched, copy back original one
if [[ -e /$PREFIX/share/locale ]]; then
    mkdir -p usr/share/locale
    cp -a "/$PREFIX/share/locale/"* usr/share/locale || exit 1
fi


echo ""
echo "########################################################################"
echo ""
echo "Run get_desktopintegration"
echo ""

# desktopintegration asks the user on first run to install a menu item
get_desktopintegration "$LOWERAPP"
cp -a "/sources/ci/$LOWERAPP.wrapper" "$APPDIR/usr/bin/$LOWERAPP.wrapper"

#DESKTOP_NAME=$(cat "$APPDIR/$LOWERAPP.desktop" | grep "^Name=.*")
#sed -i -e "s|${DESKTOP_NAME}|${DESKTOP_NAME} (AppImage)|g" "$APPDIR/$LOWERAPP.desktop"


echo ""
echo "########################################################################"
echo ""
echo "Update LensFun database"
echo ""

# Update the Lensfun database and put the newest version into the bundle
export PYTHONPATH=/$PREFIX/lib/python3.6/site-packages:$PYTHONPATH
"/$PREFIX/bin/lensfun-update-data"
mkdir -p usr/share/lensfun/version_1
if [ -e /var/lib/lensfun-updates/version_1 ]; then
	cp -a /var/lib/lensfun-updates/version_1/* usr/share/lensfun/version_1
else
	cp -a "/$PREFIX/share/lensfun/version_1/"* usr/share/lensfun/version_1
fi
printf '%s\n' "" "==================" "Contents of lensfun database:"
ls usr/share/lensfun/version_1
echo ""

# Workaround for:
# ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors
cp "$(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/
cp "$(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/


(cd /work/appimage-helper-scripts/appimage-exec-wrapper2 && make && cp -a exec.so "$APPDIR/usr/lib/exec_wrapper2.so") || exit 1



echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

export GIT_DESCRIBE=$(cd /sources && git describe)
echo "RT_BRANCH: ${RT_BRANCH}"
echo "GIT_DESCRIBE: ${GIT_DESCRIBE}"



# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
cd "$APPIMAGEBASE"
glibcVer="$(glibc_needed)"
#ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')-glibc${glibcVer}"
if [ "x${RT_BRANCH}" = "xreleases" ]; then
	rtver=$(cat AboutThisBuild.txt | grep "Version:" | head -n 1 | cut -d" " -f 2)
	ver="${rtver}-$(date '+%Y%m%d_%H%M')"
else
	ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')"
fi
export ARCH="x86_64"
export VERSION="${ver}"
export VERSION2="${RT_BRANCH}-${GIT_DESCRIBE}"
echo "VERSION:  $VERSION"
echo "VERSION2: $VERSION2"

echo "${APP}-${RT_BRANCH}" > "$APPDIR/VERSION.txt"
echo "${GIT_DESCRIBE}" >> "$APPDIR/VERSION.txt"
echo "${APP}-${VERSION}-${ARCH}.AppImage" >> "$APPDIR/VERSION.txt"

wd="$(pwd)"
mkdir -p ../out/
export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true
AI_OUT="../out/${APP}-${VERSION}-${ARCH}.AppImage"
generate_type2_appimage

if [ "x" = "y" ]; then
#generate_appimage
# Download AppImageAssistant
URL="https://github.com/AppImage/AppImageKit/releases/download/6/AppImageAssistant_6-x86_64.AppImage"
rm -f AppImageAssistant
wget -c "$URL" -O AppImageAssistant
chmod a+x ./AppImageAssistant
(rm -rf /tmp/squashfs-root && mkdir /tmp/squashfs-root && cd /tmp/squashfs-root && bsdtar xfp $wd/AppImageAssistant) || exit 1
#./AppImageAssistant --appimage-extract
mkdir -p ../out || true
GLIBC_NEEDED=$(glibc_needed)
rm "${AI_OUT}" 2>/dev/null || true
/tmp/squashfs-root/AppRun ./$APP.AppDir/ "${AI_OUT}"
fi

ls ../out/*

rm -f ../out/${APP}-${VERSION2}.AppImage
mv "${AI_OUT}" ../out/${APP}-${VERSION2}.AppImage


########################################################################
# Upload the AppDir
########################################################################

pwd
ls ../out/*
#transfer ../out/*
#echo ""
#echo "AppImage has been uploaded to the URL above; use something like GitHub Releases for permanent storage"
mkdir -p /sources/out
cp ../out/${APP}-${VERSION2}.AppImage /sources/out

printf '%s\n' "SELFIDENT end: appimage-centos7.sh"
