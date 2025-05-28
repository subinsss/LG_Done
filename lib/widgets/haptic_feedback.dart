import 'dart:io';

import 'package:gaimon/gaimon.dart';

class ThinQHaptic {
  ThinQHaptic._();

  static Future<bool> canSupportHaptic() async => (await Gaimon.canSupportsHaptic) && Platform.isIOS;

  static void selection() async {
    if (await canSupportHaptic()) Gaimon.selection();
  }

  static void error() async {
    if (await canSupportHaptic()) Gaimon.error();
  }

  static void success() async {
    if (await canSupportHaptic()) Gaimon.success();
  }

  static void warning() async {
    if (await canSupportHaptic()) Gaimon.warning();
  }

  static void heavy() async {
    if (await canSupportHaptic()) Gaimon.heavy();
  }

  static void medium() async {
    if (await canSupportHaptic()) Gaimon.medium();
  }

  static void light() async {
    if (await canSupportHaptic()) Gaimon.light();
  }

  static void rigid() async {
    if (await canSupportHaptic()) Gaimon.rigid();
  }

  static void soft() async {
    if (await canSupportHaptic()) Gaimon.soft();
  }
}
