#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=grpc
UPSTREAM_REPO=grpc-java
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"

mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

PROTOBUF_DEV=/tmp/protobuf-dev
mkdir "${PROTOBUF_DEV}"
# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    # 源码
    git clone -b "${VERSION}" --depth 1 "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}" "${SRCS}/${VERSION}"

    # protoc-gen-grpc-java 编译所需的头文件 + 静态库
    local PROTOBUF_VER=$(sed -n 's/^PROTOBUF_VERSION=//p' "${SRCS}/${VERSION}/buildscripts/make_dependencies.sh")

    wget -O "${PROTOBUF_DEV}.zip" "https://github.com/loongarch64-releases/protobuf/releases/download/${PROTOBUF_VER}/protobuf-${PROTOBUF_VER}-loongarch64-dev.zip"
    unzip -q -d "${PROTOBUF_DEV}" "${PROTOBUF_DEV}.zip"
    sed -i "s#/dist_static#${PROTOBUF_DEV}#g" "${PROTOBUF_DEV}/lib/pkgconfig/"*.pc
    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    
    ABSL_LIBS=$(PKG_CONFIG_PATH=${PROTOBUF_DEV}/lib/pkgconfig pkg-config --libs --static protobuf \
      | tr ' ' '\n' | grep -E '^-labsl_|-lutf8_range' | tr '\n' ' ')

    pushd "${SRCS}/${VERSION}/compiler/src/java_plugin/cpp"
    g++ -std=c++20 -DGRPC_VERSION=${VERSION} \
        -I${PROTOBUF_DEV}/include \
        java_plugin.cpp java_generator.cpp \
        -Wl,-Bstatic -L${PROTOBUF_DEV}/lib -lprotoc -lprotobuf ${ABSL_LIBS} \
        -Wl,-Bdynamic -lpthread -s \
        -o "${DISTS}/${VERSION}/protoc-gen-grpc-java-${VERSION}-linux-loongarch_64.exe"
    popd

    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    chown -R "${HOST_UID}:${HOST_GID}" "${DISTS}" "${SRCS}"
    
    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    prepare
    build
    post_build
}

main


cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
