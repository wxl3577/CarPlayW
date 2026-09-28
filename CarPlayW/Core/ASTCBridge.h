#ifndef CC_ASTC_BRIDGE_H
#define CC_ASTC_BRIDGE_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
int CCDecodeASTC(const uint8_t *input, size_t inputSize, unsigned width, unsigned height,
                 uint8_t *rgba, size_t rgbaSize);
int CCEncodeASTC(const uint8_t *rgba, size_t rgbaSize, unsigned width, unsigned height,
                 uint8_t *output, size_t outputSize);
const char *CCASTCError(int code);
#ifdef __cplusplus
}
#endif
#endif
