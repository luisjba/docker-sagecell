#!/bin/bash -x
# !!!NOTE!!! This script is intended to be run with root privileges
# It will run as the 'sage' user when the time is right.
SAGECELL_SRC_TARGET=${1%/}

if [ -z $SAGECELL_SRC_TARGET ]; then
  >&2 echo "Must specify a target directory for the sagecell source checkout"
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
&& sudo -H -E -u sage git clone https://github.com/sagemath/sagecell.git \
&& cd sagecell \
&& sudo -H -E -u sage git submodule update --init --recursive \
&& chown -R sage:sage . || exit 1

sudo -H -E -u sage sage -sh -c make || exit 1

# Clean up sagecell artifacts
#
echo "Cleaning SageCell artifacts"
rm -rf contrib
rm -rf doc
rm -rf tests
rm -rf .git

# remove sage artifacts
# sage_root_d=$(sage --root)
# if [ -d $sage_root_d ]; then
#   echo "Cleaning sage artifacts in $sage_root_d "
#   cd $sage_root_d
#   make misc-clean
#   [ -d src ] && make -C src/ clean
#   [ -d upstream ] && rm -rf upstream/
#   [ -d src/doc/output/doctrees ] && rm -rf src/doc/output/doctrees/
#   [ -d .git ] && rm -rf .git
#   # Strip binaries
#   [ -d local/lib ] && LC_ALL=C find local/lib local/bin -type f -exec strip '{}' ';' 2>&1 | grep -v "File format not recognized" |  grep -v "File truncated" || true
# fi
true
