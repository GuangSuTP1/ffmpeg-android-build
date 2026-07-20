#!/usr/bin/env bash

case $ANDROID_ABI in
    x86)
        EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --disable-neon --disable-asm"
        ;;
    x86_64)
        EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --disable-neon --disable-asm"
        ;;
    armeabi-v7a)
        EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-neon --disable-asm --enable-inline-asm"
        ;;
    arm64-v8a)
        EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-neon --disable-asm --enable-inline-asm"
        ;;
esac

if [ "$FFMPEG_GPL_ENABLED" = true ]; then
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-gpl"
fi

ADDITIONAL_COMPONENTS=
for LIBARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}; do
    ADDITIONAL_COMPONENTS+=" --enable-$LIBARY_NAME"
    case $LIBARY_NAME in
        libx264)
            ADDITIONAL_COMPONENTS+=" --enable-encoder=libx264"
            ;;
        libmp3lame)
            ADDITIONAL_COMPONENTS+=" --enable-encoder=libmp3lame"
            ;;
        *)
            echo "Unknown ADDITIONAL_COMPONENTS LIBARY_NAME: $LIBARY_NAME"
            ;;
    esac
done
echo ADDITIONAL_COMPONENTS=${ADDITIONAL_COMPONENTS}

DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib $FFMPEG_EXTRA_LD_FLAGS"
EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 $DEP_LD_FLAGS"

./configure \
    --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \
    --enable-cross-compile \
    --target-os=android \
    --arch=${TARGET_TRIPLE_MACHINE_ARCH} \
    --sysroot=${SYSROOT_PATH} \
    --cc=${FAM_CC} \
    --cxx=${FAM_CXX} \
    --ld=${FAM_LD} \
    --ar=${FAM_AR} \
    --as=${FAM_CC} \
    --nm=${FAM_NM} \
    --ranlib=${FAM_RANLIB} \
    --strip=${FAM_STRIP} \
    --extra-cflags="-O3 -fPIC -lm -lz -landroid -lmediandk $DEP_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS" \
    --disable-shared \
    --enable-static \
    --enable-zlib \
    --enable-jni \
    --enable-nonfree \
    --enable-mediacodec \
    --enable-decoder=h264_mediacodec \
    --enable-decoder=hevc_mediacodec \
    --enable-encoder=h264_mediacodec \
    --enable-encoder=hevc_mediacodec \
    --enable-version3 \
    --pkg-config=${PKG_CONFIG_EXECUTABLE} \
    ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
    ${ADDITIONAL_COMPONENTS} || exit 1

${MAKE_EXECUTABLE} clean
${MAKE_EXECUTABLE} -j${HOST_NPROC}
${MAKE_EXECUTABLE} install

export STATIC_LIB_DIR=${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/lib
export EXTERNAL_LIB_DIR=${INSTALL_DIR}/lib

echo STATIC_LIB_DIR=${STATIC_LIB_DIR}
echo EXTERNAL_LIB_DIR=${EXTERNAL_LIB_DIR}
echo FAM_CC=${FAM_CC}

EXTERNAL_STATIC_LIB_PATH=""
for LIBARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}; do
    EXTERNAL_STATIC_LIB_PATH+="${EXTERNAL_LIB_DIR}/${LIBARY_NAME}.a "
done

echo EXTERNAL_STATIC_LIB_PATH=${EXTERNAL_STATIC_LIB_PATH}

# 关键修改：添加 -Wl,--allow-multiple-definition 以允许重复符号（如你之前所写）
${FAM_CC} -shared -Wl,--allow-multiple-definition -o ${STATIC_LIB_DIR}/${OUTPUT_SO_NAME} \
    -Wl,--whole-archive \
    ${EXTERNAL_STATIC_LIB_PATH} \
    ${STATIC_LIB_DIR}/libavdevice.a \
    ${STATIC_LIB_DIR}/libavutil.a \
    ${STATIC_LIB_DIR}/libavcodec.a \
    ${STATIC_LIB_DIR}/libavfilter.a \
    ${STATIC_LIB_DIR}/libswresample.a \
    ${STATIC_LIB_DIR}/libavformat.a \
    ${STATIC_LIB_DIR}/libswscale.a \
    -Wl,--no-whole-archive \
    -lm -lz -landroid -lmediandk

OUTPUT_CONFIG_HEADERS_DIR=${OUTPUT_DIR}/include/${ANDROID_ABI}
mkdir -p ${OUTPUT_CONFIG_HEADERS_DIR}
cp config.h ${OUTPUT_CONFIG_HEADERS_DIR}/config.h

# 只执行一次 strip，不带 ffmpeg configure/enable-* 参数
${FAM_STRIP} --strip-unneeded ${STATIC_LIB_DIR}/${OUTPUT_SO_NAME}
