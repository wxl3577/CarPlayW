#include "ASTCBridge.h"
#include "../../ThirdParty/astcenc/astcenc.h"

static bool valid(unsigned w, unsigned h, size_t pixels, size_t blocks) {
    return w > 0 && h > 0 && w <= 4096 && h <= 4096 &&
        pixels == size_t(w) * h * 4 && blocks == size_t((w + 3) / 4) * ((h + 3) / 4) * 16;
}

int CCDecodeASTC(const uint8_t *input, size_t inputSize, unsigned width, unsigned height,
                 uint8_t *rgba, size_t rgbaSize) {
    if (!input || !rgba || !valid(width, height, rgbaSize, inputSize)) return -1;
    astcenc_config config;
    auto result = astcenc_config_init(ASTCENC_PRF_LDR, 4, 4, 1, ASTCENC_PRE_FAST,
                                      ASTCENC_FLG_DECOMPRESS_ONLY, &config);
    if (result != ASTCENC_SUCCESS) return result;
    astcenc_context *context = nullptr;
    result = astcenc_context_alloc(&config, 1, &context);
    if (result != ASTCENC_SUCCESS) return result;
    // Reject invalid blocks explicitly; a decoder can otherwise render these as magenta.
    for (size_t offset = 0; offset < inputSize; offset += 16) {
        astcenc_block_info info {};
        result = astcenc_get_block_info(context, input + offset, &info);
        if (result != ASTCENC_SUCCESS || info.is_error_block || info.is_hdr_block) {
            astcenc_context_free(context);
            return -2;
        }
    }
    void *slice = rgba;
    astcenc_image image {width, height, 1, ASTCENC_TYPE_U8, &slice};
    astcenc_swizzle swizzle {ASTCENC_SWZ_R, ASTCENC_SWZ_G, ASTCENC_SWZ_B, ASTCENC_SWZ_A};
    result = astcenc_decompress_image(context, input, inputSize, &image, &swizzle, 0);
    astcenc_context_free(context);
    return result;
}

int CCEncodeASTC(const uint8_t *rgba, size_t rgbaSize, unsigned width, unsigned height,
                 uint8_t *output, size_t outputSize) {
    if (!rgba || !output || !valid(width, height, rgbaSize, outputSize)) return -1;
    astcenc_config config;
    auto result = astcenc_config_init(ASTCENC_PRF_LDR, 4, 4, 1, ASTCENC_PRE_FAST, 0, &config);
    if (result != ASTCENC_SUCCESS) return result;
    astcenc_context *context = nullptr;
    result = astcenc_context_alloc(&config, 1, &context);
    if (result != ASTCENC_SUCCESS) return result;
    void *slice = const_cast<uint8_t *>(rgba);
    astcenc_image image {width, height, 1, ASTCENC_TYPE_U8, &slice};
    astcenc_swizzle swizzle {ASTCENC_SWZ_R, ASTCENC_SWZ_G, ASTCENC_SWZ_B, ASTCENC_SWZ_A};
    result = astcenc_compress_image(context, &image, &swizzle, output, outputSize, 0);
    astcenc_context_free(context);
    return result;
}

const char *CCASTCError(int code) {
    if (code == -1) return "invalid buffer size or dimensions";
    if (code == -2) return "invalid ASTC block or unsupported HDR block";
    return astcenc_get_error_string(static_cast<astcenc_error>(code));
}
