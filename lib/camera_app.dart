import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

const String ssd = "SSDMobileNet";

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;
  List cameras;
  int selectedCameraIdx;
  String imagePath;
  bool isDetecting = false;
  String _model = ssd;
  int _imageWidth = 0;
  int _imageHeight = 0;
  bool _busy = false;
  List _recognitions;

  @override
  void initState() {
    super.initState();
    _loadModel();
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      print(cameras.length);
      if (cameras.length > 0) {
        setState(() {
          selectedCameraIdx = 0;
        });

        _initCameraController(cameras[selectedCameraIdx]).then((void v) {});
      } else {
        print("No camera Available");
      }
    }).catchError((err) {
      print("Error occured");
    });
  }

  Future _loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == ssd) {
        res = await Tflite.loadModel(
          model: "assets/tflite/detect.tflite",
          labels: "assets/tflite/labelmap.txt",
        );
      }
      print("oo yeah $res");
    } on PlatformException {
      print("Failed to load model");
    }
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }

    controller = CameraController(cameraDescription, ResolutionPreset.high);

    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }

      if (controller.value.hasError) {
        print("Camera error, controller not initialized");
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      print("This is Hilarous : $e");
    }

    if (mounted) {
      setState(() {});
    }
    await getPredictions();
  }

  Future getPredictions() async {
    controller.startImageStream((CameraImage img) async {
      if (!isDetecting) {
        isDetecting = true;

        int startTime = DateTime.now().millisecondsSinceEpoch;

        var recognitions = await Tflite.detectObjectOnFrame(
          bytesList: img.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          model: _model,
          imageHeight: img.height,
          imageWidth: img.width,
          imageMean: 127.5,
          imageStd: 127.5,
          rotation: 90,
          numResultsPerClass: 1,
          threshold: 0.4,
          asynch: true,
        );
        print(recognitions);
        recognitions.map((res) {
          print(res);
          _imageHeight = img.height;
          _imageWidth = img.width;
        });

        int endTime = DateTime.now().millisecondsSinceEpoch;
        print("Detection took ${endTime - startTime}");
        setState(() {
          _recognitions = recognitions;
        });
        isDetecting = false;
      }
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = math.min(580, screen.width);
    double factorY = math.max(580, screen.width);

    // double factorX = screen.width;
    // double factorY = _imageHeight / _imageWidth * screen.width;

    // var x = re['rect']['x'] * factorX;
    // var w = re['rect']['y'] * factorY;
    // var y;
    // var h;

    Color blue = Colors.blue;
    return _recognitions.map((re) {
      return Positioned(
        left: re['rect']['x'] * factorX,
        top: re['rect']['y'] * factorY,
        width: re['rect']['w'] * factorX,
        height: re['rect']['h'] * factorY,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: blue, width: 3),
          ),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return Text(
        "Loading",
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: CameraPreview(controller),
    );
  }

  Widget _cameraTogglesRowWidget() {
    if (cameras == null || cameras.isEmpty) {
      return Spacer();
    }

    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    CameraLensDirection lensDirection = selectedCamera.lensDirection;

    return Align(
      alignment: Alignment.centerLeft,
      child: FlatButton.icon(
        onPressed: _onSwitchCamera,
        icon: Icon(_getCameraLensIcon(lensDirection)),
        label: Text(
            "${lensDirection.toString().substring(lensDirection.toString().indexOf('.') + 1)}"),
      ),
    );
  }

  IconData _getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
      default:
        return Icons.device_unknown;
    }
  }

  void _onSwitchCamera() {
    selectedCameraIdx =
        selectedCameraIdx < cameras.length - 1 ? selectedCameraIdx + 1 : 0;
    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    _initCameraController(selectedCamera);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> _stackChildren = [];

    _stackChildren.add(
      Container(
        height: 580,
        width: size.width,
        child: _cameraPreviewWidget(),
      ),
    );

   _stackChildren.addAll(renderBoxes(size));

    return Scaffold(
      appBar: AppBar(
        title: Text("Camera app1"),
      ),
      body: Container(
        height: size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 580,
              width: size.width,
              color: Colors.green,
              child: Stack(children: _stackChildren),
            ),
            
            _cameraTogglesRowWidget(),
          ],
        ),
      ),
    );
  }
}
