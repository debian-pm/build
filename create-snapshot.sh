#!/bin/bash

BUILD_ROOT="$(dirname "$(readlink -f "${0}")")"

usage() {
	echo "This script creates a new snapshot from a git repository"
	echo "Usage example: ./create-snapshot.sh halium/libhybris https://github.com/libhybris/libhybris master"
	exit 1
}

error_namenotset() {
	echo "ERROR: The \$NAME and \$EMAIL variables need to be set to create a new changelog entry"
	exit 1
}

# Command line opts
PKG_PATH=$1
PACKAGE=$(dpkg-parsechangelog -SSource -l packages/${PKG_PATH}/debian/changelog)
GIT_REPO=$2
GIT_BRANCH=$3

[ -z $PACKAGE ] && usage
[ -z $GIT_REPO ] && usage
[ -z $GIT_BRANCH ] && usage

# Check if packaging is in place
! [ -d $BUILD_ROOT/packages/$PKG_PATH ] &&
	echo "ERROR: packaging doesn't exist. Did you forget to run './packages.sh packagelist'?" &&
	exit 1

# Extract version information
DATE=$(date +%Y%m%d)
PKG_VERSION=$(dpkg-parsechangelog -SVersion -l $BUILD_ROOT/packages/$PACKAGE/debian/changelog | cut -f1 -d"+" | sed "s/[-].*//")
PKG_GIT_VERSION="$PKG_VERSION+git$DATE"

# Check if snapshot already exists
[ -f $BUILD_ROOT/packages/$PKG_PATH/../${PACKAGE}_$PKG_GIT_VERSION.orig.tar.xz ] &&
	echo "ERROR: $BUILD_ROOT/packages/$PKG_PATH/../${PACKAGE}_$PKG_GIT_VERSION.orig.tar.xz already exists" &&
	exit 1

# Debug output
echo "I: date: $DATE"
echo "I: package: $PACKAGE"
echo "I: packaged version: $PKG_VERSION"
echo "I: target snapshot: $PKG_GIT_VERSION"
echo "I: git repository: $GIT_REPO"
echo "I: git branch: $GIT_BRANCH"

# Update or clone git repository
if [ -d "$BUILD_ROOT/sources/$PACKAGE" ]; then
	echo "I: fetching from git repository ..."

	git -C "$BUILD_ROOT/sources/$PACKAGE" remote set-url origin $GIT_REPO
	git -C "$BUILD_ROOT/sources/$PACKAGE" fetch origin
	git -C "$BUILD_ROOT/sources/$PACKAGE" checkout origin/$GIT_BRANCH
else
	git clone --depth 1 $GIT_REPO "$BUILD_ROOT/sources/$PACKAGE" -b $GIT_BRANCH
fi

# Export repository into tar
git -C "$BUILD_ROOT/sources/$PACKAGE" archive origin/$GIT_BRANCH \
	--prefix $PACKAGE-$PKG_VERSION/ \
	--format=tar | xz >"$BUILD_ROOT/sources/${PACKAGE}_$PKG_GIT_VERSION.orig.tar.xz"

# Check if the variables for dch are set
[ -z "$NAME" ] && error_namenotset
[ -z "$EMAIL" ] && error_namenotset

# Create new changelog entry and unpack tarball
(
	cd $BUILD_ROOT/packages/$PKG_PATH

	dch -v $PKG_GIT_VERSION-1 -b

	origtargz --tar-only --path $BUILD_ROOT/sources/
)
