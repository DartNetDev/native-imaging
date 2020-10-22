#!/usr/bin/env -S jq -nrRf
# Copyright (c) 2020 Famedly GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later

def clean: gsub("/\\*.*\\*/"; "") | sub("/\\*.*$"; "/*");
def count(pat): [scan(pat)] | length;
def balanced: clean | until(count("\\(") == count("\\)") and count("/\\*") == count("\\*/"); . + " " + input | clean);
def included(a): . as $i | a | any(. == $i);

def translate_native:
   ltrimstr("const ")
 | rtrimstr(" const")
 | (capture("(?<x>.*[^ ]) *\\*$") | "Pointer<\(.x | translate_native | sub("^Void$"; "Uint8"))>")
// (capture("^void$") | "Void")
// (capture("^char$") | "Utf8")
// (capture("^int$") | "Int32")
// (capture("^size_t$") | "IntPtr")
// (capture("^ssize_t$") | "IntPtr")
// (capture("^float$") | "Float")
// (capture("^double$") | "Double")
// (capture("^uint(?<w>[0-9]+)_t$") | "Uint" + .w)
// (capture("^int(?<w>[0-9]+)_t$") | "Int" + .w)
// "NativeType";

def translate:
  .type = (.type | sub("^ +"; "") | sub(" +$"; ""))
| .ntype = (.type | translate_native)
| .dtype = (.ntype | sub("^((Uint|Int)([0-9]+|Ptr))$"; "int") | sub("^Void$"; "void") | sub("^(Float|Double)$"; "double"))
| .ptype = ((.dtype | capture("^Pointer<(?<x>.*)>$") | .x) // null)
| .atype = if .ptype then "int" else .dtype end
| .name |= if . == "in" or . == "out" then "c_" + . else . end;

def error_func:
  if type == "string" then
    capture("(const )?(?<type>.*[^ ]) *\\*$")
  | .type
  | rtrimstr(" const")
  | gsub("(?<ch>[A-Z]+)"; "_\(.ch | ascii_downcase)")
  | ltrimstr("_")
  | "\(.)_last_error"
  else
    null
  end;

def printfun: "
final \(.name) = libImaging.lookupFunction<
  \(.ntype) Function(\(.args | map("\(.ntype) \(.name)") | join(", "))),
  \(.dtype) Function(\(.args | map("\(.dtype) \(.name)") | join(", ")))
>('\(.name)');";

def printfun_async: "
final _\(.name) = libImaging.lookup<NativeFunction<
  \(.ntype) Function(\(.args | map("\(.ntype) \(.name)") | join(", ")))
>>('\(.name)');

final \(.name) = _\(.name).asFunction<
  \(.dtype) Function(\(.args | map("\(.dtype) \(.name)") | join(", ")))
>();

class \(.name)Op extends \(if .ptype then "PtrOperation<\(.ptype)>" else "Operation<\(.atype)>" end) {
  final _funcAddr = _\(.name).address;
  \(.args | map("\(.atype) \(.name);") | join("\n  "))
  \(.name)Op(\(.args | map("\(.dtype) \(.name)") | join(", ")))
    \( .args
     | if length > 0 then .[0] |= (.first = true) else . end
     | map("\(if .first then ":" else "," end) \(.name) = \(.name)\(if .ptype then ".address" else "" end)")
     | join("\n    "));
  \(.dtype) Function(\(.args | map("\(.dtype) \(.name)") | join(", "))) get func => Pointer<NativeFunction<
      \(.ntype) Function(\(.args | map("\(.ntype) \(.name)") | join(", ")))
    >>.fromAddress(_funcAddr).asFunction();
  \(.atype) run() => func(\(
      .args
    | map(if .ptype then "Pointer.fromAddress(\(.name))" else .name end)
    | join(", ")
  ))\(if .ptype then ".address" else "" end);
}";

def namt:
  (.name | capture("(?<n>.*)\\[.*\\]") // null) as $tmp
  | if $tmp then
      .type += "*" | .name = $tmp.n
    else
      .
    end;

"// Auto-generated file.
// ignore_for_file: non_constant_identifier_names

import 'ffi_base.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';",

( inputs
| balanced
| capture("(extern +)?IMAGING_EXPORT (?<type>[^(]*[ *])(?<name>(Imaging|image|jpeg|blurHash)[^ ()*]+) *\\((?<args>|[^(].*[^)])\\);")
| .args |= (sub("^ *void *$"; "") | split(",") | map(capture("(?<type>.*[ *])(?<name>[^ *]+)") | namt | translate))
| translate
| if .args + [.] | map(.ntype | select(. == "NativeType")) | length != 0 then empty else . end
| if .name | included($async_functions) then printfun_async else printfun end
)
