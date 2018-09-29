#! /bin/bash

export RT_BRANCH=dev
#rm -rf RawTherapee
if [ ! -e RawTherapee ]; then
	git clone https://github.com/Beep6581/RawTherapee.git --branch $RT_BRANCH --single-branch
fi
rm -rf RawTherapee/ci
cp -a ci RawTherapee
cd RawTherapee
#docker run -it -v $(pwd):/sources -e "RT_BRANCH=$RT_BRANCH" photoflow/docker-centos7-gtk bash
docker run -it -v $(pwd):/sources -e "RT_BRANCH=$RT_BRANCH" centos:7 bash #/sources/ci/appimage-centos7.sh

