#!/bin/bash
set -e
set -x

# This script invoked by a cron job every X hours
# This script functions best when the following are installed:
#   git, python (with the "requests" module installed, for Travis-CI API), playtpus (must be in path)
#
# You must install Winston from source for proper bundling. This script assumes you have copied the
#  relevant .julia/ directory to the directory pointed to by $JULIA_PKGDIR below.



# define variables
JULIA_GIT_URL="https://github.com/JuliaLang/julia.git"
JULIA_GIT_BRANCH=master
BUILD_DIR=/tmp/julia-packaging
DMG_DIR=$BUILD_DIR/dmgroot

# This is the directory where my .julia directory is stored with cairo, tk, etc... all precompiled and ready
export JULIA_PKGDIR=${BUILD_DIR}/julia_packaging_home

# cd to the location of this script
cd $(dirname $0)
ORIG_DIR=$(pwd)

# Check if we've been downloaded as a git directory.  If so, update ourselves!
if [[ -d .git ]]; then
        git pull
fi

# Store everything in a temp dir
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Checkout julia
if test ! -d julia-${JULIA_GIT_BRANCH}; then
        git clone ${JULIA_GIT_URL} julia-${JULIA_GIT_BRANCH}
fi

# Go into our checkout of JULIA_GIT_URL
cd julia-${JULIA_GIT_BRANCH}
git reset --hard
git pull origin ${JULIA_GIT_BRANCH}

# Find the last commit that passed a Travis build
LAST_GOOD_COMMIT=$(${ORIG_DIR}/get_last_good_commit.py)
if [ -z "$LAST_GOOD_COMMIT" ]; then
        echo "ERROR: No good commits detected!"
        exit 1
fi

git checkout -B ${JULIA_GIT_BRANCH} $LAST_GOOD_COMMIT
if [[ "$?" != 0 ]]; then
        echo "Couldn't checkout last good commit, going with HEAD!"
        git checkout HEAD
fi

# Build julia
make cleanall
rm -rf deps/libuv # This is the most common failure mode
git submodule update
make OPENBLAS_DYNAMIC_ARCH=1 testall

if [[ "$?" != "0" ]]; then
    echo "ERROR: Julia did not test well, aborting!"
    exit -1
fi

# Begin packaging steps
cd contrib/mac/app

# Check that Winston is installed
if [ ! -d $JULIA_PKGDIR/.julia/Winston ]; then
    echo "ERROR: Winston not installed to ${JULIA_PKGDIR}/.julia; remedy this and try again!" 1>&2
    exit -1
fi

# Make special packaging makefile
make OPENBLAS_DYNAMIC_ARCH=1

# We force its name to be Julia-0.2-unstable.dmg
mv *.dmg "${BUILD_DIR}/Julia-0.2-unstable.dmg"

echo "Packaged .dmg available at $(ls ${BUILD_DIR}/*.dmg)"
