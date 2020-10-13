#include <thread>
#include "dart_api_dl.h"

extern "C" {

#include "extra.h"

static int inited;

void ImagingInitAsync(void* data)
{
        if (inited == 0) {
                Dart_InitializeApiDL(data);
                inited = 1;
        }
}

} // extern "C"

extern "C" void ImagingResampleAsync(Imaging imIn, int xsize, int ysize, int filter, float box[4], Dart_Port_DL port)
{
	std::thread([=] {
		Imaging result = ImagingResample(imIn, xsize, ysize, filter, box);
		Dart_PostInteger_DL(port, reinterpret_cast<int64_t>(result));
	}).detach();
}

extern "C" void blurHashForImageAsync(Imaging im, int xComponents, int yComponents, int64_t port)
{
	std::thread([=] {
		const char* result = blurHashForImage(im, xComponents, yComponents);
		Dart_PostInteger_DL(port, reinterpret_cast<int64_t>(result));
	}).detach();
}

#ifdef JPEG_ENCODE
extern "C" IMAGING_EXPORT void jpegEncodeAsync(Imaging im, int quality, uint8_t** data, size_t* size, int64_t port)
{
	std::thread([=] {
		jpegEncode(im, quality, data, size);
		Dart_PostInteger_DL(port, 1);
	}).detach();
}
#endif
