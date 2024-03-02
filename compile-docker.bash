#!/bin/bash
VERSION=0.1
MOBY_BRANCH=25.0
CLI_BRANCH=25.0
MOBY_PATCH_COMMIT=ec89e7cde1ff1bcbd9b09f9139c770d6dde7ffcb
# CLI_COMMIT=e1f24d3c93df6752d3c27c8d61d18260f141310c
BUILDX_VERSION=v0.12.1
CTOP_VERSION=0.7.7

# 通用日志打印，格式为：[2021-08-25 10:00:00] [INFO] 信息
function log() {
  echo -e "\033[32m[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] $1\033[0m"
}


echo ""
echo "$0 version $VERSION"
echo "Docker compiler (client and server) for CoreELEC systems"
while getopts ":h" opt; do
  case ${opt} in
    h )
      echo "Usage:"
      echo "    $0 -h                      Display this help message."
      echo "    $0 build                   Build docker for local architecture."
      echo "    $0 buildx                  Build docker using buildx for other architecture."
      exit 0
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      echo "Usage:"
      echo "    $0 -h                      Display help message."
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

bold=$(tput bold)
normal=$(tput sgr0)

function print_error_arg_buildx () {
  echo "Invalid architecture"
  echo "Usage:"
  echo "    $0 buildx -a <arch>"
  echo "    <arch> must be ${bold}arm64${normal}, ${bold}armv7${normal} or ${bold}armv6${normal}"
}

BUILDX_PREFIX="buildx-$BUILDX_VERSION."
CTOP_PREFIX="ctop-$CTOP_VERSION-"
ARCH=""
arch_uname=$(uname -m)
if [ -z "${arch_uname##*aarch64*}" ]; then
  ARCH="linux/arm64"
  ARCH_TAR="arm64"
  BUILDX_SUFFIX="linux-arm64"
  CTOP_SUFFIX="linux-arm64"
elif [ -z "${arch_uname##*hf*}" ]; then
  ARCH="linux/arm/v7"
  ARCH_TAR="armv7"
  BUILDX_SUFFIX="linux-arm-v7"
  CTOP_SUFFIX="linux-arm"
elif [ -z "${arch_uname##*v7*}" ]; then
  ARCH="linux/arm/v7"
  ARCH_TAR="armv7"
  BUILDX_SUFFIX="linux-arm-v7"
  CTOP_SUFFIX="linux-arm"
elif [ -z "${arch_uname##*v6*}" ]; then
  ARCH="linux/arm/v6"
  ARCH_TAR="armv6"
  BUILDX_SUFFIX="linux-arm-v6"
  CTOP_SUFFIX="linux-arm"
fi

subcommand=$1; shift
case "$subcommand" in
  build )
    BUILD_METHOD="build"
    if [ "$ARCH" == "" ]; then
      echo "Your architecture is not compatible. Try using \"$0 buildx\" instead \"$0 build\""
      exit 1
    fi
    ;;
  buildx )
    BUILD_METHOD="buildx"
    if [ $# -eq 0 ]; then
      print_error_arg_buildx
      exit 1
    fi
    while getopts ":a" opt; do
      case ${opt} in
        a )
          if [ $# -eq 0 ]; then
	    print_error_arg_buildx
          fi
	  shift $((OPTIND -1))
          architecturespecified=$1; shift
          case "$architecturespecified" in
	    "arm64" )
	      ARCH="linux/arm64"
              ARCH_TAR="arm64"
	      BUILDX_SUFFIX="linux-arm64"
	      CTOP_SUFFIX="linux-arm64"
              ;;
	    "armv7" )
	      ARCH="linux/arm/v7"
              ARCH_TAR="armv7"
	      BUILDX_SUFFIX="linux-arm-v7"
	      CTOP_SUFFIX="linux-arm"
              ;;
	    "armv6" )
	      ARCH="linux/arm/v6"
              ARCH_TAR="armv6"
	      BUILDX_SUFFIX="linux-arm-v6"
	      CTOP_SUFFIX="linux-arm"
              ;;
	    * )
	      print_error_arg_buildx
	      exit 1
	      ;;
	  esac
          ;;
        * )
          echo "Invalid option"
          echo "Usage:"
          echo "    $0 buildx -a <arch>"
	  exit 1
          ;;
      esac
    done
    ;;
  *)
    echo "Invalid option $subcommand"
    echo "Usage:"
    echo "    $0 -h                      Display help message."
    exit 1
    ;;
esac
if [ "$ARCH" == "" ]; then
  print_error_arg_buildx
  exit 1
fi
echo "BUILD_METHOD: $BUILD_METHOD"
echo "ARCH: $ARCH"
echo "BUILDX_SUFFIX: $BUILDX_SUFFIX"
docker_buildx_found=$(docker info 2>/dev/null | grep buildx)
if [ "$BUILD_METHOD" == "buildx" ]; then
  if [ -z "${docker_buildx_found##*buildx*}" ]; then
    echo "Support for buildx detected"
  else
    echo "Support for buildx not detected"
    exit 1
  fi
fi

#
# Preparing environment
#
log "Preparing environment"
rm -rf ./build_tmp && rm -f ./storage/.docker/bin/* && rm -f ./storage/.docker/cli-plugins/*

# 为了避免后续操作中出现文件不存在的情况，这里创建了一些目录
# 打印都创建了哪些目录
# storage/.docker/bin
# storage/.docker/cli-plugins
# storage/.docker/data-root
# build_tmp
log "Creating directories storage/.docker/bin storage/.docker/cli-plugins storage/.docker/data-root build_tmp"

mkdir -p storage/.docker/bin storage/.docker/cli-plugins storage/.docker/data-root build_tmp

# 验证是否创建成功
# 1. storage/.docker/bin
# 2. storage/.docker/cli-plugins
# 3. storage/.docker/data-root
# 4. build_tmp
log "Directories created: $(ls -l | grep storage | awk '{print $9}') $(ls -l | grep build_tmp | awk '{print $9}')"

#
# Download from github
#
log "Downloading from github"

curl -L --fail https://github.com/docker/buildx/releases/download/$BUILDX_VERSION/$BUILDX_PREFIX$BUILDX_SUFFIX -o ./storage/.docker/cli-plugins/docker-buildx && chmod a+x ./storage/.docker/cli-plugins/docker-buildx
curl -L --fail https://github.com/bcicen/ctop/releases/download/v$CTOP_VERSION/$CTOP_PREFIX$CTOP_SUFFIX -o ./storage/.docker/bin/ctop && chmod a+x ./storage/.docker/bin/ctop
curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-docker-compose/master/run.sh -o ./storage/.docker/bin/docker-compose && chmod a+x ./storage/.docker/bin/docker-compose

log "Downloaded from github: $(ls -l ./storage/.docker/cli-plugins/docker-buildx | awk '{print $9}') $(ls -l ./storage/.docker/bin/ctop | awk '{print $9}') $(ls -l ./storage/.docker/bin/docker-compose | awk '{print $9}')"
cd build_tmp

# 下载moby和cli源码
# 1. moby
# 2. cli
log "Downloading moby and cli source code"

git clone https://github.com/moby/moby.git
#  解释一下下面的含义
#  1. 进入moby目录
#  2. 切换到22.06分支
#  3. 切换到ec89e7cde1ff1bcbd9b09f9139c770d6dde7ffcb提交
#  4. 返回上一级目录
#  5. 打补丁
log "进入moby目录,并切换分支，切换提交"
cd moby && git checkout -t origin/$MOBY_BRANCH && cd ..

git clone https://github.com/docker/cli.git
# cd cli && git checkout -t origin/20.10 && cd ..
cd cli && git checkout -t origin/$CLI_BRANCH && cd ..
if [ "$BUILD_METHOD" == "buildx" ]; then
  cd moby
  MOBY_VERSION=$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)
  VERSION="$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)" USE_BUILDX=1 BUILDX="docker buildx" BUILDX_BUILD_EXTRA_OPTS="--platform $ARCH" make
  cd ../cli
  VERSION="$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)" docker buildx bake --set binary.platform=$ARCH
  cd ../..
else
  cd moby
  MOBY_VERSION=$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)
  VERSION="$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)"  make
  cd ../cli
  VERSION="$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags)" docker buildx bake
  cd ../..
fi
cp -p build_tmp/moby/bundles/binary-daemon/{containerd,containerd-shim-runc-v2,ctr,docker-init,docker-proxy,dockerd,dockerd-rootless-setuptool.sh,dockerd-rootless.sh,rootlesskit,rootlesskit-docker-proxy,runc,vpnkit} ./storage/.docker/bin
cp -p build_tmp/cli/build/docker* ./storage/.docker/bin
TIME_NOW=$(date +"%Y%m%d%H%M%S")
tar zcvf docker_${MOBY_VERSION}_coreelec_${ARCH_TAR}_${TIME_NOW}.tar.gz storage
