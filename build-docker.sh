#! /bin/bash

export RT_BRANCH=dev
rm -rf RawTherapee
git clone https://github.com/Beep6581/RawTherapee.git --branch $RT_BRANCH --single-branch
rm -rf RawTherapee/ci
cp -a ci RawTherapee
cd RawTherapee
docker run -it -v $(pwd):/sources -e "RT_BRANCH=dev" photoflow/docker-centos7-gtk3 bash #/sources/ci/appimage-centos6.sh

