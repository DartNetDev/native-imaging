// Copyright (c) 2020 Famedly GmbH
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

final libImaging = Platform.isIOS
    ? DynamicLibrary.process()
    : DynamicLibrary.open(Platform.isAndroid
        ? 'libImaging.so'
        : Platform.isWindows
            ? 'libImaging.dll'
            : Platform.isMacOS
                ? 'libImaging.dylib'
                : 'libImaging.so');

abstract class BaseOperation<T, U> {
  SendPort resultPort;
  T run();
  U convert(T ret);

  static void _run(BaseOperation op) {
    op.resultPort.send(op.run());
  }

  Future<U> exec() async {
    final resultPort = ReceivePort();
    try {
      this.resultPort = resultPort.sendPort;
      Isolate.spawn(BaseOperation._run, this);
      return convert(await resultPort.first);
    } finally {
      this.resultPort = null;
      resultPort.close();
    }
  }
}

abstract class Operation<T> extends BaseOperation<T, T> {
  T convert(T ret) => ret;
}

abstract class PtrOperation<T extends NativeType>
    extends BaseOperation<int, Pointer<T>> {
  Pointer<T> convert(int ret) => Pointer.fromAddress(ret);
}
