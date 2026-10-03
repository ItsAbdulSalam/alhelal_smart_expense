import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndLaunchCsv(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  final xFile = XFile(file.path);
  await Share.shareXFiles(
    [xFile],
    text: 'كشف المصاريف والنفقات المالية - Alhelal Smart Expense',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 5),
  );
}
