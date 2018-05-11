#!/bin/sh

set -e

# Since this script is called by update-workspaces.sh, we want to quickly
# avoid doing any work if SpiderMonkey is already built and up-to-date.
# Running SM's Makefile is a bit slow and noisy, so instead we'll make a
# special file and only rebuild if it's older than SVN.
# README.txt should be updated whenever we update SM, so use that as
# a time comparison.
if [ -e .already-built -a .already-built -nt README.txt ]
then
    echo "SpiderMonkey is already up to date"
    exit
fi

echo "Building SpiderMonkey..."
echo

# Use Mozilla make on Windows
if [ "${OS}" = "Windows_NT" ]
then
  MAKE="mozmake"
else
  MAKE=${MAKE:="make"}
fi

MAKE_OPTS="${JOBS}"

CONF_OPTS="--enable-shared-js --disable-tests --without-intl-api"

# Bug 1269319
# When compiled with GCC 6 (or later), SpiderMonkey 38 (and versions up to 49) is
# subject to segfaults. Disabling a few optimizations fixes that.
# See also #4053
if [ "${OS}" != "Windows_NT" ]
then
  if [ "`${CXX:=g++} -dumpversion | cut -f1 -d.`" -ge "6" ]
  then
    CXXFLAGS="${CXXFLAGS} -fno-schedule-insns2 -fno-delete-null-pointer-checks"
  fi
fi

# Change the default location where the tracelogger should store its output.
# The default location is . on Windows and /tmp/ on *nix.
TLCXXFLAGS='-DTRACE_LOG_DIR="\"../../source/tools/tracelogger/\""'

# We bundle prebuilt binaries for Windows and the .libs for nspr aren't included.
# If you want to build on Windows, check README.txt and edit the absolute paths 
# to match your environment.
if [ "${OS}" = "Windows_NT" ]
then
  NSPR_INCLUDES="-IC:/Projects/nspr/nspr-4.12/nspr/dist/include/nspr"
  NSPR_LIBS=" \
  C:/Projects/nspr/nspr-4.12/nspr/dist/lib/nspr4 \
  C:/Projects/nspr/nspr-4.12/nspr/dist/lib/plds4 \
  C:/Projects/nspr/nspr-4.12/nspr/dist/lib/plc4"
else
  NSPR_INCLUDES="`pkg-config nspr --cflags`"
  NSPR_LIBS="`pkg-config nspr --libs`"
fi

# If Valgrind looks like it's installed, then set up SM to support it
# (else the JITs will interact poorly with it)
if [ -e /usr/include/valgrind/valgrind.h ]
then
  CONF_OPTS="${CONF_OPTS} --enable-valgrind"
fi

# We need to be able to override CHOST in case it is 32bit userland on 64bit kernel
CONF_OPTS="${CONF_OPTS} \
  ${CBUILD:+--build=${CBUILD}} \
  ${CHOST:+--host=${CHOST}} \
  ${CTARGET:+--target=${CTARGET}}"

echo "SpiderMonkey build options: ${CONF_OPTS}"
echo ${CONF_OPTS}

FOLDER=mozjs-38.0.0

# Delete the existing directory to avoid conflicts and extract the tarball
rm -rf $FOLDER
tar xjf mozjs-38.2.1.rc0.tar.bz2

# Clean up header files that may be left over by earlier versions of SpiderMonkey
rm -rf include-unix-*

cd $FOLDER

# Apply patches
. ../patch.sh

cd js/src

# Clean up data generated by previous builds that could cause problems
rm -rf build-debug
rm -rf build-release

# We want separate debug/release versions of the library, so we have to change
# the LIBRARY_NAME for each build.
# (We use perl instead of sed so that it works with MozillaBuild on Windows,
# which has an ancient sed.)
perl -i.bak -pe 's/(SHARED_LIBRARY_NAME\s+=).*/$1 '\''mozjs38-ps-debug'\''/' moz.build
mkdir -p build-debug
cd build-debug
CXXFLAGS="${CXXFLAGS} ${TLCXXFLAGS}" ../configure ${CONF_OPTS} --with-nspr-libs="$NSPR_LIBS" --with-nspr-cflags="$NSPR_INCLUDES" --enable-debug --disable-optimize --enable-js-diagnostics --enable-gczeal
${MAKE} ${MAKE_OPTS}
cd ..

perl -i.bak -pe 's/(SHARED_LIBRARY_NAME\s+=).*/$1 '\''mozjs38-ps-release'\''/' moz.build
mkdir -p build-release
cd build-release
CXXFLAGS="${CXXFLAGS} ${TLCXXFLAGS}" ../configure ${CONF_OPTS} --with-nspr-libs="$NSPR_LIBS" --with-nspr-cflags="$NSPR_INCLUDES" --enable-optimize  # --enable-gczeal --enable-debug-symbols
${MAKE} ${MAKE_OPTS}
cd ..

cd ../../..

if [ "${OS}" = "Windows_NT" ]
then
  INCLUDE_DIR_DEBUG=include-win32-debug
  INCLUDE_DIR_RELEASE=include-win32-release
  DLL_SRC_SUFFIX=.dll
  DLL_DST_SUFFIX=.dll
  LIB_PREFIX=
  LIB_SRC_SUFFIX=.lib
  LIB_DST_SUFFIX=.lib
else
  INCLUDE_DIR_DEBUG=include-unix-debug
  INCLUDE_DIR_RELEASE=include-unix-release
  DLL_SRC_SUFFIX=.so
  DLL_DST_SUFFIX=.so
  LIB_PREFIX=lib
  LIB_SRC_SUFFIX=.so
  LIB_DST_SUFFIX=.so
  if [ "`uname -s`" = "OpenBSD" ]
  then
    DLL_SRC_SUFFIX=.so.1.0
    DLL_DST_SUFFIX=.so.1.0
    LIB_SRC_SUFFIX=.so.1.0
    LIB_DST_SUFFIX=:so.1.0
  fi
fi

if [ "${OS}" = "Windows_NT" ]
then
  # Bug #776126
  # SpiderMonkey uses a tweaked zlib when building, and it wrongly copies its own files to include dirs
  # afterwards, so we have to remove them to not have them conflicting with the regular zlib
  cd ${FOLDER}/js/src/build-release/dist/include
  rm mozzconf.h zconf.h zlib.h
  cd ../../../../../..
  cd ${FOLDER}/js/src/build-debug/dist/include
  rm mozzconf.h zconf.h zlib.h
  cd ../../../../../..
fi

# Copy files into the necessary locations for building and running the game

# js-config.h is different for debug and release builds, so we need different include directories for both
mkdir -p ${INCLUDE_DIR_DEBUG}
mkdir -p ${INCLUDE_DIR_RELEASE}
cp -R -L ${FOLDER}/js/src/build-release/dist/include/* ${INCLUDE_DIR_RELEASE}/
cp -R -L ${FOLDER}/js/src/build-debug/dist/include/* ${INCLUDE_DIR_DEBUG}/

mkdir -p lib/
cp -L ${FOLDER}/js/src/build-debug/dist/lib/${LIB_PREFIX}mozjs38-ps-debug${LIB_SRC_SUFFIX} lib/${LIB_PREFIX}mozjs38-ps-debug${LIB_DST_SUFFIX}
cp -L ${FOLDER}/js/src/build-release/dist/lib/${LIB_PREFIX}mozjs38-ps-release${LIB_SRC_SUFFIX} lib/${LIB_PREFIX}mozjs38-ps-release${LIB_DST_SUFFIX}
cp -L ${FOLDER}/js/src/build-debug/dist/bin/${LIB_PREFIX}mozjs38-ps-debug${DLL_SRC_SUFFIX} ../../../binaries/system/${LIB_PREFIX}mozjs38-ps-debug${DLL_DST_SUFFIX}
cp -L ${FOLDER}/js/src/build-release/dist/bin/${LIB_PREFIX}mozjs38-ps-release${DLL_SRC_SUFFIX} ../../../binaries/system/${LIB_PREFIX}mozjs38-ps-release${DLL_DST_SUFFIX}

# On Windows, also copy debugging symbols files
if [ "${OS}" = "Windows_NT" ]
then
  cp -L ${FOLDER}/js/src/build-debug/js/src/${LIB_PREFIX}mozjs38-ps-debug.pdb ../../../binaries/system/${LIB_PREFIX}mozjs38-ps-debug.pdb
  cp -L ${FOLDER}/js/src/build-release/js/src/${LIB_PREFIX}mozjs38-ps-release.pdb ../../../binaries/system/${LIB_PREFIX}mozjs38-ps-release.pdb
fi

# Flag that it's already been built successfully so we can skip it next time
touch .already-built
