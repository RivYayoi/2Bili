import 'dart:convert';

import 'package:crypto/crypto.dart';

const List<int> mixinKeyEncTab = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
  37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
  22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

String mixinKeyOf(String imgKey, String subKey) {
  final raw = '$imgKey$subKey';
  if (raw.length < 64) {
    throw StateError('wbi keys must be 32 chars each');
  }
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(raw[mixinKeyEncTab[i]]);
  }
  return buffer.toString();
}

String wbiEncode(String value) {
  final filtered = value.replaceAll(RegExp(r"[!'()*]"), '');
  return Uri.encodeComponent(filtered);
}

class WbiSigned {
  const WbiSigned({required this.params, required this.query});

  final Map<String, String> params;
  final String query;
}

WbiSigned signWbiQuery(
  Map<String, String> params,
  String mixinKey,
  int wts,
) {
  final all = <String, String>{...params, 'wts': '$wts'};
  all.remove('w_rid');
  final keys = all.keys.toList()..sort();
  final query = keys
      .map((key) => '${wbiEncode(key)}=${wbiEncode(all[key] ?? '')}')
      .join('&');
  final digest = md5.convert(utf8.encode('$query$mixinKey')).toString();
  all['w_rid'] = digest;
  return WbiSigned(params: all, query: '$query&w_rid=$digest');
}

Map<String, String> signWbi(
  Map<String, String> params,
  String mixinKey,
  int wts,
) {
  return signWbiQuery(params, mixinKey, wts).params;
}
