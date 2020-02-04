#! /bin/bash

msg () {
    printf '%s\n' \
        "" "" "" "" \
        "----------------------------------------" \
        "$@" \
        "----------------------------------------" \
        ""
}

# Prefix (without the leading "/") in which RawTherapee and its dependencies are installed:
LOWERAPP=${APP,,}
export PATH="/usr/local/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}"

msg "AppImage configuration:" \
    "    APP: \"$APP\"" \
    "    LOWERAPP: \"$LOWERAPP\"" \
    "    AI_SCRIPTS_DIR: \"$AI_SCRIPTS_DIR\""

source /work/appimage-helper-scripts/functions.sh

#locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"




msg "Creating and cleaning AppImage folder"

#cp "${AI_SCRIPTS_DIR}"/excludelist . || exit 1
cp /work/appimage-helper-scripts/excludelist "$APPROOT/excludelist"

# Remove old AppDir structure (if existing)
export APPDIR="${APPROOT}/${APP}.AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/"
echo "  APPROOT: \"$APPROOT\""
echo "  APPDIR: \"$APPDIR\""
echo ""

run_hooks

cp -a /usr/local/bin/zenity "$APPDIR/usr/bin" || exit 1
cp -a /usr/local/share/zenity "$APPDIR/usr/share" || exit 1

cd "$APPDIR" || exit 1

# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps2; copy_deps2; copy_deps2;




msg "Copy MIME files"
mkdir -p usr/share/image
cp -a /usr/share/mime/image/x-*.xml usr/share/image || exit 1




msg 'Move all libraries into $APPDIR/usr/lib'
move_lib




msg "Delete blacklisted libraries"
# See: https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted2




msg "Copy libfontconfig into the AppImage"
# libfontconfig will be used if they are newer than those of the host
# system in which the AppImage will be executed
mkdir -p usr/optional/fontconfig
fc_prefix="$(pkg-config --variable=libdir fontconfig)"
cp -a "${fc_prefix}/libfontconfig"* usr/optional/fontconfig || exit 1




msg "Copy libstdc++.so.6 and libgomp.so.1 into the AppImage"
copy_gcc_libs




msg "Copy desktop file and application icon"
mkdir -p usr/share/icons
echo "cp -r \"/usr/local/share/icons/\"* \"usr/share/icons\""
cp -r "/usr/local/share/icons/"* "usr/share/icons" || exit 1




msg "Creating top-level desktop and icon files, and application launcher"
cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
#cp -a "${AI_SCRIPTS_DIR}/fixes.sh" . || exit 1
cp -a /work/appimage-helper-scripts/apprun-helper.sh "./apprun-helper.sh" || exit 1
cp -a "${AI_SCRIPTS_DIR}/check_updates.sh" . || exit 1
cp -a "${AI_SCRIPTS_DIR}/zenity.sh" usr/bin || exit 1
#wget -q https://raw.githubusercontent.com/aferrero2707/appimage-helper-scripts/master/apprun-helper.sh -O "./apprun-helper.sh" || exit 1
get_desktop || exit 1
get_icon || exit 1




msg "Copy locale messages"
# The fonts configuration should not be patched, copy back original one
if [[ -e /usr/local/share/locale ]]; then
    mkdir -p usr/share/locale
    cp -a "/usr/local/share/locale/"* usr/share/locale || exit 1
fi




msg "Run get_desktopintegration"
# desktopintegration asks the user on first run to install a menu item
get_desktopintegration "$LOWERAPP"
cp -a "/sources/ci/$LOWERAPP.wrapper" "$APPDIR/usr/bin/$LOWERAPP.wrapper"

#DESKTOP_NAME=$(cat "$APPDIR/$LOWERAPP.desktop" | grep "^Name=.*")
#sed -i -e "s|${DESKTOP_NAME}|${DESKTOP_NAME} (AppImage)|g" "$APPDIR/$LOWERAPP.desktop"




msg "Update LensFun database"
#export PYTHONPATH=/$PREFIX/lib/python3.6/site-packages:$PYTHONPATH
LFDIR=$(find /usr/local/lib/python*/site-packages/ -name lensfun)
if [ -n "$LFDIR" ]; then
    export PYTHONPATH="$(dirname "$LFDIR")":$PYTHONPATH
    echo "PYTHONPATH: $PYTHONPATH"
fi
"/usr/local/bin/lensfun-update-data"
mkdir -p usr/share/lensfun/version_1
if [ -e /var/lib/lensfun-updates/version_1 ]; then
    cp -a /var/lib/lensfun-updates/version_1/* usr/share/lensfun/version_1
else
    cp -a "/usr/local/share/lensfun/version_1/"* usr/share/lensfun/version_1
fi
printf '%s\n' "" "==================" "Contents of lensfun database:"
ls usr/share/lensfun/version_1




msg "Workaround for:" "ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors"
cp "$(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/
cp "$(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/


(cd /work/appimage-helper-scripts/appimage-exec-wrapper2 &&
    make &&
    cp -a exec.so "$APPDIR/usr/lib/exec_wrapper2.so") || exit 1




msg "Stripping binaries"
strip_binaries




export GIT_DESCRIBE="$(cd /sources && git describe --tags --always)"
msg "RT_BRANCH: ${RT_BRANCH}" "GIT_DESCRIBE: ${GIT_DESCRIBE}"




msg "Prepare to generate AppImage"
# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
cd "$APPROOT"
# See "Rename AppImage" section for info on desired final filename format
curr_date="$(date '+%Y%m%d')"
if [[ $RT_BRANCH = releases ]]; then
    ver="${GIT_DESCRIBE}"
else
    ver="${RT_BRANCH}_${GIT_DESCRIBE}_${curr_date}"
fi
export ARCH="x86_64"
export VERSION="$ver"
printf '%s\n' "VERSION: $VERSION"

cat <<EOF > "$APPDIR/VERSION.txt"
$APP
$VERSION
${APP}_${VERSION}.AppImage
EOF

export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true

pwd
mkdir -p ../out/




msg "Generate AppImage"
generate_type2_appimage
ls -lah ../out/





msg "Rename AppImage and move to /sources/out" \
    "Desired filename format for a tagged release:" \
    "    RawTherapee_tag.AppImage (gitdescribe in this case will print the tag)" \
    "Desired filename format for a development build:" \
    "    RawTherapee_branch_gitdescribe_date.AppImage"

if [[ $RT_BRANCH = releases ]]; then
    # Generated filename: APP-tag-arch.AppImage
    ai_filename="${APP}-${GIT_DESCRIBE}-${ARCH}.AppImage"
    mv -v ../out/"$ai_filename" "../out/RawTherapee_${VERSION}.AppImage"
else
    # Generated filename: APP-BRANCH_GITDESCRIBE_DATE-ARCH.AppImage
    ai_filename="${APP}-${RT_BRANCH}_${GIT_DESCRIBE}_${curr_date}-${ARCH}.AppImage"
    mv -v ../out/"$ai_filename" "../out/RawTherapee_${VERSION}.AppImage"
fi

mkdir -p /sources/out
cp -v "../out/RawTherapee_${VERSION}.AppImage" /sources/out/
cd /sources/out
sha256sum "RawTherapee_${VERSION}.AppImage" > "RawTherapee_${VERSION}.AppImage.sha256sum"
