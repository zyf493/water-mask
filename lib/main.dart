import 'package:flutter/material.dart';
import 'package:watermark/watermark_view.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '自定义相机',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WatermarkPhoto(),
    );
  }
}