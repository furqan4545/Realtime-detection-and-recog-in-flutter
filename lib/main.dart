import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import './camera_app.dart';

List<CameraDescription> cameras;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Camera One",
      debugShowCheckedModeBanner: false,
      home: CameraApp(),
    );
  }
}
