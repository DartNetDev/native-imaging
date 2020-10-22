// Copyright (c) 2020 Famedly GmbH
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'src/ffi.dart';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:ffi/ffi.dart' as ffi;

Future<void> init() {
  // ensure the library is available by loading a function
  // ignore: unnecessary_statements
  imageFromRGBA;

  return Future.sync(() {});
}

// don't change the order!
enum Transform {
  nearest,
  lanczos,
  bilinear,
  bicubic,
  box,
  hamming,
}

class Image {
  Pointer<NativeType> _inst;

  Image();
  Image._(this._inst);

  void loadRGBA(int width, int height, List<int> data) {
    assert(data.length == width * height * 4);
    final mem = allocate<Uint8>(count: data.length);
    mem.asTypedList(data.length).setAll(0, data);
    _inst = imageFromRGBA(width, height, mem);
  }

  void free() {
    ImagingDelete(_inst);
    _inst = nullptr;
  }

  Pointer<Utf8> get _mode => imageMode(_inst);
  String get mode => Utf8.fromUtf8(_mode);
  int get width => imageWidth(_inst);
  int get height => imageHeight(_inst);
  int get linesize => imageLinesize(_inst);
  Pointer<Uint8> get block => imageBlock(_inst);

  Future<Image> copy() async {
    return Image._(await ImagingCopyOp(_inst).exec());
  }

  Image blend(Image other, double alpha) {
    return Image._(ImagingBlend(_inst, other._inst, alpha));
  }

  Image gaussianBlur(double radius, int passes) {
    final out = ImagingNewDirty(_mode, width, height);
    ImagingGaussianBlur(out, _inst, radius, passes);
    return Image._(out);
  }

  Image rotate90() {
    final out = ImagingNewDirty(_mode, height, width);
    ImagingRotate90(out, _inst);
    return Image._(out);
  }

  Image rotate180() {
    final out = ImagingNewDirty(_mode, width, height);
    ImagingRotate180(out, _inst);
    return Image._(out);
  }

  Image rotate270() {
    final out = ImagingNewDirty(_mode, height, width);
    ImagingRotate270(out, _inst);
    return Image._(out);
  }

  Image flipLeftRight() {
    final out = ImagingNewDirty(_mode, width, height);
    ImagingFlipLeftRight(out, _inst);
    return Image._(out);
  }

  Image flipTopBottom() {
    final out = ImagingNewDirty(_mode, width, height);
    ImagingFlipTopBottom(out, _inst);
    return Image._(out);
  }

  Image transpose() {
    final out = ImagingNewDirty(_mode, height, width);
    ImagingTranspose(out, _inst);
    return Image._(out);
  }

  Image transverse() {
    final out = ImagingNewDirty(_mode, height, width);
    ImagingTransverse(out, _inst);
    return Image._(out);
  }

  Future<Image> resample(int width, int height, Transform mode) async {
    final box = allocate<Float>(count: 4);
    try {
      box
          .asTypedList(4)
          .setAll(0, [0, 0, this.width.toDouble(), this.height.toDouble()]);
      return Image._(
          await ImagingResampleOp(_inst, width, height, mode.index, box)
              .exec());
    } finally {
      ffi.free(box);
    }
  }

  Future<String> toBlurhash(int xComponents, int yComponents) async {
    final ptr =
        await blurHashForImageOp(_inst, xComponents, yComponents).exec();
    try {
      return Utf8.fromUtf8(ptr);
    } finally {
      ffi.free(ptr);
    }
  }

  Future<void> loadEncoded(Uint8List bytes) {
    throw UnsupportedError(
        'native_imaging loadEncoded is available on Web only');
  }

  Future<Uint8List> toJpeg(int quality) async {
    final buf = allocate<Pointer<Uint8>>();
    buf.value = nullptr;
    final size = allocate<IntPtr>();
    size.value = 0;
    try {
      await jpegEncodeOp(_inst, quality, buf, size).exec();
      final result = Uint8List.fromList(buf.value.asTypedList(size.value));
      return Future.sync(() => result);
    } finally {
      if (buf.value != nullptr) ffi.free(buf.value);
      ffi.free(size);
      ffi.free(buf);
    }
  }
}
