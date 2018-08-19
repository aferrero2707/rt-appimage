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
if ! wget "https://github.com/probonopd/AppImages/raw/master/functions.sh" --output-document="./functions.sh"; then
    cp -a "${TRAVIS_BUILD_DIR}/ci/functions.sh" ./functions.sh || exit 1
fi

# Source the script:
. ./functions.sh

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

# Delete blacklisted libraries
delete_blacklisted_custom()
{
    printf '%s\n' "APPIMAGEBASE: ${APPIMAGEBASE}"
    ls "${APPIMAGEBASE}"

    while IFS= read -r line; do
        find . -type f -name "${line}" -delete
    done < <(cat "$APPIMAGEBASE/excludelist" | sed '/^[[:space:]]*$/d' | sed '/^#.*$/d')
    # TODO Try this, its cleaner if it works:
    #done < "$APPIMAGEBASE/excludelist" | sed '/^[[:space:]]*$/d' | sed '/^#.*$/d'
}


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


echo ""
echo "########################################################################"
echo ""
echo "Installing additional system packages"
echo ""

# Add some required packages
yum install -y wget curl git lcms2-devel || exit 1

(cd /work && rm -rf libiptcdata* && wget https://sourceforge.net/projects/libiptcdata/files/libiptcdata/1.0.4/libiptcdata-1.0.4.tar.gz && tar xzvf libiptcdata-1.0.4.tar.gz && cd libiptcdata-1.0.4 && ./configure --prefix=/$AIPREFIX && make -j 2 install) || exit 1

# Set environment variables to allow finding the dependencies that are
# compiled from sources
export PATH="/${PREFIX}/bin:/work/inst/bin:${PATH}"
export LD_LIBRARY_PATH="/${PREFIX}/lib:/${PREFIX}/lib64:/work/inst/lib:/work/inst/lib64:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/${PREFIX}/lib/pkgconfig://${PREFIX}/lib64/pkgconfig:/work/inst/lib/pkgconfig:${PKG_CONFIG_PATH}"

locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"



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

LFV=0.3.2
echo ""
echo "########################################################################"
echo ""
echo "Building and installing LensFun $LFV"
echo ""

# Lensfun build and install
cd /work || exit 1
rm -rf lensfun*
wget "https://sourceforge.net/projects/lensfun/files/$LFV/lensfun-${LFV}.tar.gz"
tar xzvf "lensfun-${LFV}.tar.gz"
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


# RawTherapee build and install
if [ x"${RT_BRANCH}" = "xreleases" ]; then
    CACHE_SUFFIX=""
else
    CACHE_SUFFIX="5-${RT_BRANCH}-ai"
fi
echo "RT cache suffix: \"${CACHE_SUFFIX}\""
mkdir -p /work/build/rt
cd /work/build/rt || exit 1
cmake \
    -DCMAKE_BUILD_TYPE="release"  \
    -DCACHE_NAME_SUFFIX="${CACHE_SUFFIX}" \
    -DPROC_TARGET_NUMBER="0" \
    -DBUILD_BUNDLE="OFF" \
    -DCMAKE_INSTALL_PREFIX="/${PREFIX}" \
    -DBUNDLE_BASE_INSTALL_DIR="/${PREFIX}" \
    -DOPTION_OMP="ON" \
    -DWITH_LTO="OFF" \
    -DWITH_PROF="OFF" \
    -DWITH_SAN="OFF" \
    -DWITH_SYSTEM_KLT="OFF" \
    /sources || exit 1
make --jobs=2 || exit 1
make install || exit 1

echo ""
echo "########################################################################"
echo ""
echo "Creating and cleaning AppImage folder"

# Create a folder in the shared area where the AppImage structure will be copied
mkdir -p /work/appimage
cd /work/appimage || exit 1
cp "${AI_SCRIPTS_DIR}"/excludelist . || exit 1
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

# Copy main RT executable into $APPDIR/usr/bin/rawtherapee
mkdir -p ./usr/bin
echo "cp -a \"/${PREFIX}/bin/${LOWERAPP}\" \"./usr/bin/${LOWERAPP}\""
cp -a "/${PREFIX}/bin/${LOWERAPP}" "./usr/bin/${LOWERAPP}" || exit 1
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Copy dependencies"
echo ""

# Manually copy librsvg, because it is not picked automatically by copy_deps
mkdir -p ./usr/lib
echo "cp -a /$PREFIX/lib/librsvg-2.so* ./usr/lib"
cp -a /$PREFIX/lib/librsvg-2.so* ./usr/lib
echo "ls ./usr/lib:"
ls ./usr/lib

# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps; copy_deps; copy_deps;

cp -L ./lib/x86_64-linux-gnu/*.* ./usr/lib
rm -rf ./lib/x86_64-linux-gnu

cp -L ./lib/*.* ./usr/lib
rm -rf ./lib

cp -L ./lib64/*.* ./usr/lib
rm -rf ./lib64

cp -L ./usr/lib/x86_64-linux-gnu/*.* ./usr/lib
rm -rf ./usr/lib/x86_64-linux-gnu

cp -L ./usr/lib64/*.* ./usr/lib
rm -rf ./usr/lib64

cp -L "./$PREFIX/lib/x86_64-linux-gnu/"*.* ./usr/lib
rm -rf "./$PREFIX/lib/x86_64-linux-gnu"

cp -L "./$PREFIX/lib/"*.* ./usr/lib
rm -rf "./$PREFIX/lib"

cp -L "./$PREFIX/lib64/"*.* ./usr/lib
rm -rf "./$PREFIX/lib64"


echo ""
echo "########################################################################"
echo ""
echo "Compile Glib schemas"
echo ""

# Compile Glib schemas
glib_prefix="$(pkg-config --variable=prefix glib-2.0)"
(mkdir -p usr/share/glib-2.0/schemas/ && \
cp -a ${glib_prefix}/share/glib-2.0/schemas/* usr/share/glib-2.0/schemas && \
cd usr/share/glib-2.0/schemas/ && \
glib-compile-schemas .) || exit 1

# Copy gconv
cp -a /usr/lib64/gconv usr/lib


echo ""
echo "########################################################################"
echo ""
echo "Copy gdk-pixbuf modules and cache file"
echo ""

# Copy gdk-pixbuf modules and cache file, and patch the cache file
# so that modules are picked from the AppImage bundle
gdk_pixbuf_moduledir="$(pkg-config --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0)"
gdk_pixbuf_cache_file="$(pkg-config --variable=gdk_pixbuf_cache_file gdk-pixbuf-2.0)"
gdk_pixbuf_libdir_bundle="lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0"
gdk_pixbuf_cache_file_bundle="usr/${gdk_pixbuf_libdir_bundle}/loaders.cache"

mkdir -p "usr/${gdk_pixbuf_libdir_bundle}"
cp -a "$gdk_pixbuf_moduledir" "usr/${gdk_pixbuf_libdir_bundle}"
cp -a "$gdk_pixbuf_cache_file" "usr/${gdk_pixbuf_libdir_bundle}"

# TODO Check this, was:
#for m in $(ls "usr/${gdk_pixbuf_libdir_bundle}"/loaders/*.so); do
for m in "usr/${gdk_pixbuf_libdir_bundle}/loaders/"*.so; do
    sofile="$(basename "$m")"
    sed -i -e "s|${gdk_pixbuf_moduledir}/${sofile}|./${gdk_pixbuf_libdir_bundle}/loaders/${sofile}|g" "$gdk_pixbuf_cache_file_bundle"
done

printf '%s\n' "" "==================" "gdk-pixbuf cache:"
cat "$gdk_pixbuf_cache_file_bundle"
printf '%s\n' "==================" "gdk-pixbuf loaders:"
ls "usr/${gdk_pixbuf_libdir_bundle}/loaders"
printf '%s\n' "=================="


echo ""
echo "########################################################################"
echo ""
echo "Copy the pixmap theme engine"
echo ""

# Copy the pixmap theme engine
mkdir -p usr/lib/gtk-2.0/engines
gtk_libdir="$(pkg-config --variable=libdir gtk+-2.0)"
pixmap_lib="$(find "${gtk_libdir}/gtk-2.0" -name libpixmap.so)"
if [[ x"${pixmap_lib}" != "x" ]]; then
    cp -L "${pixmap_lib}" usr/lib/gtk-2.0/engines
fi


echo ""
echo "########################################################################"
echo ""
echo "Copy MIME files"
echo ""

# Copy MIME files
mkdir -p usr/share
cp -a /usr/share/mime usr/share || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Copy RT's share folder"
echo ""

# Copy RT's share folder
mkdir -p usr/share
cp -a "/$PREFIX/share/rawtherapee" usr/share || exit 1


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
echo "Fix path of pango modules"
echo ""

# Fix path of pango modules
patch_pango

# Delete stuff that should not go into the AppImage
rm -rf usr/include usr/libexec usr/_jhbuild usr/share/doc


echo ""
echo "########################################################################"
echo ""
echo "Delete blacklisted libraries"
echo ""

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted_custom


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

# Copy libstdc++.so.6 and libgomp.so.1 into the AppImage
# They will be used if they are newer than those of the host
# system in which the AppImage will be executed

stdcxxlib="$(ldconfig -p | grep 'libstdc++.so.6 (libc6,x86-64)'| awk 'NR==1{print $NF}')"
echo "stdcxxlib: $stdcxxlib"
if [[ x"$stdcxxlib" != "x" ]]; then
    mkdir -p usr/optional/libstdc++
    cp -L "$stdcxxlib" usr/optional/libstdc++ || exit 1
fi

gomplib="$(ldconfig -p | grep 'libgomp.so.1 (libc6,x86-64)'| awk 'NR==1{print $NF}')"
echo "gomplib: $gomplib"
if [[ x"$gomplib" != "x" ]]; then
    mkdir -p usr/optional/libstdc++
    cp -L "$gomplib" usr/optional/libstdc++ || exit 1
fi


echo ""
echo "########################################################################"
echo ""
echo "Patch away absolute paths"
echo ""

# Patch away absolute paths; it would be nice if they were relative
find usr/ -type f -exec sed -i -e 's|/usr/|././/|g' {} \; -exec echo -n "Patched /usr in " \; -exec echo {} \; >& patch1.log
find usr/ -type f -exec sed -i -e "s|/${PREFIX}/|././/|g" {} \; -exec echo -n "Patched /${PREFIX} in " \; -exec echo {} \; >& patch2.log


echo ""
echo "########################################################################"
echo ""
echo "Copy desktop file and application icon"

# Copy desktop and icon file to AppDir for AppRun to pick them up
mkdir -p usr/share/applications/
echo "cp \"/${PREFIX}/share/applications/rawtherapee.desktop\" \"usr/share/applications\""
cp "/${PREFIX}/share/applications/rawtherapee.desktop" "usr/share/applications" || exit 1

# Copy hicolor icon theme
mkdir -p usr/share/icons
echo "cp -r \"/${PREFIX}/share/icons/\"* \"usr/share/icons\""
cp -r "/${PREFIX}/share/icons/"* "usr/share/icons" || exit 1
echo ""


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

# TODO Might want to "|| exit 1" these, and generate_status
#get_apprun || exit 1
cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
get_desktop || exit 1
get_icon || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Copy fonts configuration"
echo ""

# The fonts configuration should not be patched, copy back original one
if [[ -e /$PREFIX/etc/fonts/fonts.conf ]]; then
    mkdir -p usr/etc/fonts
    cp "/$PREFIX/etc/fonts/fonts.conf" usr/etc/fonts/fonts.conf || exit 1
elif [[ -e /usr/etc/fonts/fonts.conf ]]; then
    mkdir -p usr/etc/fonts
    cp /usr/etc/fonts/fonts.conf usr/etc/fonts/fonts.conf || exit 1
fi


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


echo ""
echo "########################################################################"
echo ""
echo "Update LensFun database"
echo ""

# Update the Lensfun database and put the newest version into the bundle
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


echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

cd "$APPIMAGEBASE"
rm -f "${APP}.tgz"
tar czf "${APP}.tgz" "${APP}.AppDir"
ls -lh "${APP}.tgz"
transfer "${APP}.tgz"
printf '%s\n' "" "The .tgz has been uploaded to the URL above." ""




echo "RT_BRANCH: ${RT_BRANCH}"
# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
glibcVer="$(glibc_needed)"
#ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')-glibc${glibcVer}"
if [ "x${RT_BRANCH}" = "xreleases" ]; then
	rtver=$(cat AboutThisBuild.txt | grep "Version:" | head -n 1 | cut -d" " -f 2)
	ver="${rtver}-$(date '+%Y%m%d_%H%M')"
else
	ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')"
fi
ARCH="x86_64"
VERSION="${ver}"
VERSION2="${RT_BRANCH}-${GIT_DESCRIBE}"

yum install -y bsdtar || exit 1
wd="$(pwd)"
mkdir -p ../out/
ARCH="x86_64"
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
AI_OUT="../out/${APP}-${VERSION}.glibc${GLIBC_NEEDED}-${ARCH}.AppImage"
rm "${AI_OUT}" 2>/dev/null || true
/tmp/squashfs-root/AppRun ./$APP.AppDir/ "${AI_OUT}"
 
ls ../out/*

rm -f ../out/${APP}-${VERSION2}.AppImage
mv "${AI_OUT}" ../out/${APP}-${VERSION2}.AppImage


########################################################################
# Upload the AppDir
########################################################################

pwd
ls ../out/*
transfer ../out/*
echo ""
echo "AppImage has been uploaded to the URL above; use something like GitHub Releases for permanent storage"
cp ../out/${APP}-${VERSION2}.AppImage /sources
