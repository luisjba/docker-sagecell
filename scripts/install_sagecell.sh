#!/bin/bash
# !!!NOTE!!! This script is intended to be run with root privileges
# It will run as the 'sage' user when the time is right.
SAGECELL_SRC_TARGET=${1%/}
BRANCH=$2

if [ -z $SAGECELL_SRC_TARGET ]; then
  >&2 echo "Must specify a target directory for the sagecell source checkout"
  exit 1
fi

if [ -z $BRANCH ]; then
  >&2 echo "Must specify a branch to install"
  exit 1
fi

N_CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
export SAGE_INSTALL_GCC="no"
export MAKE="make -j${N_CORES}"

# Sage can't be built as root, for reasons...
# Here -E inherits the environment from root, however it's important to
# include -H to set HOME=/home/sage, otherwise DOT_SAGE will not be set
# correctly and the build will fail!
sudo -H -E -u sage /usr/bin/sage -pip install lockfile paramiko sockjs-tornado sqlalchemy || exit 1

cd "$SAGECELL_SRC_TARGET" \
&& git clone https://github.com/sagemath/sagecell.git \
&& cd sagecell \
&& git submodule update --init --recursive \
&& chown -R sage:sage ./ || exit 1

ls -al $SAGECELL_SRC_TARGET/sage/local/lib/python2.7/site-packages/notebook/static/components/jquery-ui/

sudo -H -E -u sage sage -sh -c make || exit 1

# Clean up sagecell artifacts
#
rm -rf contrib
rm -rf doc
rm -rf tests
rm -rf .git

# remove sage artifacts
cd "$SAGECELL_SRC_TARGET"/sage

make misc-clean
make -C src/ clean

rm -rf upstream/
rm -rf src/doc/output/doctrees/
rm -rf .git

# Strip binaries
LC_ALL=C find local/lib local/bin -type f -exec strip '{}' ';' 2>&1 | grep -v "File format not recognized" |  grep -v "File truncated" || true
