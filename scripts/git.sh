#!/bin/bash -e
#
# Copyright (c) 2009-2013 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

DIR=$PWD

git_kernel_stable () {
	echo "-----------------------------"
	echo "scripts/git: fetching from: ${linux_stable}"
	git fetch ${linux_stable} master --tags || true
}

git_kernel_torvalds () {
	echo "-----------------------------"
	echo "scripts/git: pulling from: ${torvalds_linux}"
	git pull ${GIT_OPTS} ${torvalds_linux} master --tags || true
	git tag | grep v${KERNEL_TAG} &>/dev/null || git_kernel_stable
}

check_and_or_clone () {
	if [ ! "${LINUX_GIT}" ] ; then
		if [ -f "${HOME}/linux-src/.git/config" ] ; then
			echo "-----------------------------"
			echo "scripts/git: Warning: LINUX_GIT not defined in system.sh"
			echo "using default location: ${HOME}/linux-src"
		else
			echo "-----------------------------"
			echo "scripts/git: Warning: LINUX_GIT not defined in system.sh"
			echo "cloning ${torvalds_linux} to default location: ${HOME}/linux-src"
			git clone ${torvalds_linux} ${HOME}/linux-src
		fi
		LINUX_GIT="${HOME}/linux-src"
	fi
}

git_kernel () {
	check_and_or_clone

	#In the past some users set LINUX_GIT = DIR, fix that...
	if [ -f "${LINUX_GIT}/version.sh" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is set as DIR:"
		check_and_or_clone
	fi

	#is the git directory user writable?
	if [ ! -w "${LINUX_GIT}" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is not writable:"
		check_and_or_clone
	fi

	#is it actually a git repo?
	if [ ! -f "${LINUX_GIT}/.git/config" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is an invalid tree:"
		check_and_or_clone
	fi

	cd ${LINUX_GIT}/
	echo "-----------------------------"
	echo "scripts/git: Debug: LINUX_GIT is setup as..."
	pwd
	echo "-----------------------------"
	cat .git/config
	echo "-----------------------------"
	echo "scripts/git: Updating LINUX_GIT tree via: git fetch"
	git fetch || true
	cd -

	if [ ! -f "${DIR}/KERNEL/.git/config" ] ; then
		rm -rf ${DIR}/KERNEL/ || true
		git clone --shared ${LINUX_GIT} ${DIR}/KERNEL
	fi

	#Automaticly, just recover the git repo from a git crash
	if [ -f "${DIR}/KERNEL/.git/index.lock" ] ; then
		rm -rf ${DIR}/KERNEL/ || true
		git clone --shared ${LINUX_GIT} ${DIR}/KERNEL
	fi

	cd ${DIR}/KERNEL/

	if [ "${RUN_BISECT}" ] ; then
		git bisect reset || true
	fi

	#So we are now going to assume the worst, and create a new master branch
	git am --abort || echo "git tree is clean..."
	git add .
	git commit --allow-empty -a -m 'empty cleanup commit'

	git checkout origin/master -b tmp-master
	git branch -D master &>/dev/null || true

	git checkout origin/master -b master
	git branch -D tmp-master &>/dev/null || true

	git pull ${GIT_OPTS} || true

	git tag | grep v${KERNEL_TAG} | grep -v rc &>/dev/null || git_kernel_torvalds

	if [ "${KERNEL_SHA}" ] ; then
		git_kernel_torvalds
	fi

	git branch -D v${KERNEL_TAG}-${BUILD} &>/dev/null || true
	if [ ! "${KERNEL_SHA}" ] ; then
		git checkout v${KERNEL_TAG} -b v${KERNEL_TAG}-${BUILD}
	else
		git checkout ${KERNEL_SHA} -b v${KERNEL_TAG}-${BUILD}
	fi

	git describe

	cd ${DIR}/

	if [ "${IMX_BOOTLETS}" ] ; then
		if [ ! -f "${DIR}"/ignore/imx-bootlets/.git/config ] ; then
			rm -rf "${DIR}"/ignore/imx-bootlets || true
			mkdir -p "${DIR}"/ignore/imx-bootlets
			git clone ${imx_bootlets_repo} "${DIR}"/ignore/imx-bootlets
		fi

		if [ "${imx_bootlets_tag}" ] ; then
			cd "${DIR}"/ignore/imx-bootlets/
			git checkout origin/master -b tmp-master
			git branch -D master &>/dev/null || true
			git branch -D tmp &>/dev/null || true

			git checkout origin/master -b master
			git branch -D tmp-master &>/dev/null || true

			git pull ${GIT_OPTS} || true
			git checkout origin/${imx_bootlets_tag} -b tmp
			cd ${DIR}/
		fi
	fi

}

source ${DIR}/version.sh
source ${DIR}/system.sh

if [ "${GIT_OVER_HTTP}" ] ; then
	torvalds_linux="http://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
	linux_stable="http://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
	imx_bootlets_repo="https://github.com/RobertCNelson/imx-bootlets.git"
else
	torvalds_linux="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
	linux_stable="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
	imx_bootlets_repo="git://github.com/RobertCNelson/imx-bootlets.git"
fi

unset ON_MASTER
if [ "${DISABLE_MASTER_BRANCH}" ] ; then
	git branch | grep "*" | grep master &>/dev/null && ON_MASTER=1
fi

if [ ! "${ON_MASTER}" ] ; then
	git_kernel
else
	echo "-----------------------------"
	echo "Please checkout one of the active branches, building from the master branch has been disabled..."
	echo "-----------------------------"
	cat ${DIR}/branches.list | grep -v INACTIVE
	echo "-----------------------------"
	exit 1
fi
