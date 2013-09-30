# OPAM packages needed to build tests.
OPAM_PACKAGES="shared-memory-ring lwt xenstore ipaddr tuntap"

function setup_arm_chroot {
  echo Setting up qemu chroot for ARM
  sudo apt-get install -qq debootstrap qemu-user-static binfmt-support sbuild
  df -h
  DIR=/arm-chroot
  MIRROR=http://ftp.us.debian.org/debian/
  sudo mkdir $DIR
  sudo debootstrap --variant=buildd --include=fakeroot,build-essential --arch=armel --foreign wheezy $DIR $MIRROR
  sudo cp /usr/bin/qemu-arm-static $DIR/usr/bin/
  sudo chroot $DIR ./debootstrap/debootstrap --second-stage
  sudo sbuild-createchroot --arch=armel --foreign --setup-only wheezy $DIR $MIRROR
  export LANG=c
  export OPAMYES=1
  export OPAMVERBOSE=1
  sudo chroot $DIR apt-get --allow-unauthenticated install -y debian-archive-keyring build-essential m4 git curl
  # Add GPG key for anil@recoil.org which the ARM OPAM repo is signed with
  sudo chroot $DIR apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5896E99F
  echo 'deb [arch=armel] http://www.recoil.org/~avsm/debian-arm wheezy main' > /tmp/opamapt
  sudo mv /tmp/opamapt $DIR/etc/apt/sources.list.d/opam.list
  sudo chroot $DIR apt-get update
  sudo mkdir -p $DIR/$TRAVIS_BUILD_DIR
  echo sync:
  sudo rsync -av $TRAVIS_BUILD_DIR/ $DIR/$TRAVIS_BUILD_DIR/
  echo debug:
  ls -la $DIR/$TRAVIS_BUILD_DIR
  sudo touch $DIR/.chroot_is_done
  sudo chroot $DIR $TRAVIS_BUILD_DIR/.travis-ci.sh
} 

if [ "$XARCH" = "arm" ]; then
  cd $TRAVIS_BUILD_DIR
  echo Check if we are already in the chroot
  if [ ! -e "/.chroot_is_done" ]; then
    setup_arm_chroot
  fi
else
# not arm, so do standard ppa setup
case "$OCAML_VERSION,$OPAM_VERSION" in
3.12.1,1.0.0) ppa=avsm/ocaml312+opam10 ;;
3.12.1,1.1.0) ppa=avsm/ocaml312+opam11 ;;
4.00.1,1.0.0) ppa=avsm/ocaml40+opam10 ;;
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.01.0,1.0.0) ppa=avsm/ocaml41+opam10 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac
echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
fi

sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
export OPAMYES=1
export OPAMVERBOSE=1
echo OCaml version
ocaml -version
echo OPAM versions
opam --version
opam --git-version

opam init 

opam install ${OPAM_PACKAGES}

eval `opam config -env`
make unix-build && make xen-build
