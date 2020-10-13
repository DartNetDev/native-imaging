#include "Imaging.h"
#include "imaging_export.h"

IMAGING_EXPORT Imaging imageFromRGBA(int width, int height, uint8_t* data);
IMAGING_EXPORT const char* imageMode(Imaging im);
IMAGING_EXPORT int imageWidth(Imaging im);
IMAGING_EXPORT int imageHeight(Imaging im);
IMAGING_EXPORT int imageLinesize(Imaging im);
IMAGING_EXPORT uint8_t* imageBlock(Imaging im);
IMAGING_EXPORT const char* blurHashForImage(Imaging im, int xComponents, int yComponents);

IMAGING_EXPORT void ImagingInitAsync(void* data);
IMAGING_EXPORT void ImagingResampleAsync(Imaging imIn, int xsize, int ysize, int filter, float box[4], int64_t port);
IMAGING_EXPORT void blurHashForImageAsync(Imaging im, int xComponents, int yComponents, int64_t port);

#ifdef JPEG_ENCODE
IMAGING_EXPORT void jpegEncode(Imaging im, int quality, uint8_t** data, size_t* size);
IMAGING_EXPORT void jpegEncodeAsync(Imaging im, int quality, uint8_t** data, size_t* size, int64_t port);
#endif
