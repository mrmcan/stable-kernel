#!/bin/bash
#
ARCH=$(uname -m)
DISABLE_MASTER_BRANCH=1

CORES=1
if [ "x${ARCH}" == "xx86_64" ] || [ "x${ARCH}" == "xi686" ] ; then
	CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
	let CORES=$CORES+1
fi

unset GIT_OPTS
unset GIT_NOEDIT
LC_ALL=C git help pull | grep -m 1 -e "--no-edit" &>/dev/null && GIT_NOEDIT=1

if [ "${GIT_NOEDIT}" ] ; then
	GIT_OPTS+="--no-edit"
fi

CCACHE=ccache

config="omap2plus_defconfig"
#FIXME: need to find a better way to support more then one...
#imx_bootlets_tag="imx233-olinuxino-10.05.02"
#imx_bootlets_target="imx23-olinuxino"

#Kernel/Build
KERNEL_REL=3.X
KERNEL_TAG=${KERNEL_REL}
BUILD=x0

#v3.X-rcX + upto SHA
#KERNEL_SHA=""

#git branch
#BRANCH="v3.X.x"

BUILDREV=1.0
DISTRO=cross
DEBARCH=armel
