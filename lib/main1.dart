import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(const MyApp());
}

enum TakeStatus {
  /// 准备中
  preparing,
  /// 拍摄中
  taking,
  /// 待确认
  confirm,
  /// 已完成
  done
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自定义相机',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
       
        child: OutlinedButton(
            onPressed: (){
              takeWatermarkPhoto(context,aspectRatio: 4.0, pixelRatio: 3.0);
            }, 
            child: Text('打开相机'),
          ),
      ),
    );
  }
}

Future takeWatermarkPhoto(BuildContext context, {
  required double aspectRatio,
  required double pixelRatio,
}) async  {
  return await Navigator.of(context).push(PageRouteBuilder(
    opaque:false,
    pageBuilder: (BuildContext context, Animation<double> animation,Animation<double> secondaryAnimation) {
      return WatermarkPhoto(aspectRatio: aspectRatio, pixelRatio: pixelRatio);
    },
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  ));
}


class WatermarkPhoto extends StatefulWidget {
  static const String SAVE_DIR = 'tempImage';

  final double aspectRatio;
  final double pixelRatio;

  const WatermarkPhoto({super.key, required this.aspectRatio, required this.pixelRatio});

  @override
  _WatermarkPhotoState createState() => _WatermarkPhotoState();
}

class _WatermarkPhotoState extends State<WatermarkPhoto> with WidgetsBindingObserver {
  final GlobalKey _cameraKey = GlobalKey();
  late CameraController _cameraController;
  late String _time;
  late String _address;
  TakeStatus _takeStatus = TakeStatus.preparing;
  late XFile _curFile;
  // late Timer _timer;
  bool _isCapturing = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // AMapLocation.init(AMapLocationOption());
    _time = formatDate(DateTime.now(), [yyyy, '-', mm, '-' , dd, ' ', HH, ':', nn, ':', ss]);
    _address = '未知位置';
    _initCamera();
  }

  void _initCamera() async {
    try {
      setState(() {
        _takeStatus = TakeStatus.preparing;
      });
      List cameras = await availableCameras();
      _cameraController = CameraController(cameras.first, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _cameraController.addListener(() {
        if (mounted) setState(() {});
      });
      await _cameraController.initialize();
      if (mounted) {
        setState(() {
          _takeStatus = TakeStatus.taking;
        });
      }
    } on CameraException catch (e) {
      print(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //  || !_cameraController.value.isInitialized
    if (_cameraController == null) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        _initCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraArea(),
          _buildTopBar(),
          _buildAction(),
        ],
      ),
    );
  }
  
  Widget _buildCameraArea() {
    Widget area;
    if (_takeStatus == TakeStatus.confirm && _curFile != null) {
      area = Image.file(File(_curFile.path), fit: BoxFit.fitWidth,);
      // && _cameraController.value.isInitialized
    } else if (_cameraController != null ) {
      final double screenWidth = MediaQuery.of(context).size.width;
      final double screenHeight = MediaQuery.of(context).size.height;
      area = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Container(
              width: screenWidth,
              // height: screenWidth * _cameraController.value.aspectRatio,
              height: screenHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: Colors.red
                )
              ),
              child: CameraPreview(_cameraController),
            )
          )
        ),
      );
    } else {
      area = Container(color: Colors.black,);
    }

    return Center(
      child: RepaintBoundary(
        key: _cameraKey,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: area,
            ),
            Positioned(
                left: 10,
                right: 120,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_time, style: TextStyle(color: Colors.white, fontSize: 13),),
                    Text(_address, style: TextStyle(color: Colors.white, fontSize: 13),),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    String flashIcon = 'assets/icon-flash-auto.png';
    // && _cameraController.value.isInitialized
    if (_cameraController != null) {
      switch (_cameraController.value.flashMode) {
        case FlashMode.auto:
          flashIcon = 'assets/icon-flash-auto.png';
          break;
        case FlashMode.off:
          flashIcon = 'assets/icon-flash-off.png';
          break;
        case FlashMode.always:
        case FlashMode.torch:
          flashIcon = 'assets/icon-flash-on.png';
          break;
      }
    }

    if (_takeStatus == TakeStatus.confirm) {
      return Container();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            color: Colors.white,
            icon: Icon(Icons.arrow_back, size: 32,),
            onPressed: () => Navigator.of(context).pop()
          ),
          IconButton(
            color: Colors.white,
            icon: Image.asset(flashIcon, width: 32, height: 32,),
            onPressed: _toggleFlash
          )
        ],
      )
    );
  }

  Widget _buildAction() {
    Widget child;
    if (_takeStatus == TakeStatus.confirm) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          OutlinedButton(
            onPressed: _cancel, 
            child: Image.asset('assets/icon-close.png', width: 24, height: 24,),
          ),
          OutlinedButton(
            onPressed: _confirm, 
            child: Image.asset('assets/icon-confirm.png', width: 24, height: 24,),
          )
        ],
      );
    } else {
      child = OutlinedButton(
            onPressed: _takePicture, 
            child: Icon(Icons.camera, color: Colors.white, size: 48,),
          );
    }

    return Positioned(
      bottom: 50,
      left: 50,
      right: 50,
      child: child
    );
  }

  /// 切换闪光灯
  void _toggleFlash() {
    if (_cameraController == null) return;

    switch (_cameraController.value.flashMode) {
      case FlashMode.auto:
        _cameraController.setFlashMode(FlashMode.always);
        break;
      case FlashMode.off:
        _cameraController.setFlashMode(FlashMode.auto);
        break;
      case FlashMode.always:
      case FlashMode.torch:
        _cameraController.setFlashMode(FlashMode.off);
        break;
    }
  }

  /// 拍照
  void _takePicture() async {
    if (_cameraController == null || _cameraController.value.isTakingPicture) return;
    // _timer.cancel();

    XFile file = await _cameraController.takePicture();
    setState(() {
      _curFile = file;
      _takeStatus = TakeStatus.confirm;
    });
  }

  /// 取消。重新拍照
  void _cancel() {
    setState(() {
      _takeStatus = TakeStatus.preparing;
    });
    _cameraController.dispose();
    _initCamera();
  }

  /// 确认。返回图片数据
  void _confirm() async {
    if (_isCapturing) return;
    _isCapturing = true;
    try {
      print('=========================================成功');
      // RenderRepaintBoundary boundary = _cameraKey.currentContext.findRenderObject();
      // ui.Image image = await boundary.toImage(pixelRatio: widget.pixelRatio ?? 2.0);
      // ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      // Uint8List imgBytes = byteData.buffer.asUint8List();
      // String basePath = await findSavePath(WatermarkPhoto.SAVE_DIR);
      // File file = File('$basePath/${DateTime.now().millisecondsSinceEpoch}.jpg');
      // file.writeAsBytesSync(imgBytes);
      // Navigator.of(context).pop(file);
    } catch (e) {
      print(e);
    }
    _isCapturing = false;
  }
}


