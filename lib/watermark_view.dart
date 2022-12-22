import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:watermark/watermark_logic.dart';

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

class WatermarkPhoto extends StatefulWidget {
  // static const String SAVE_DIR = 'tempImage';

  // final double aspectRatio;
  // final double pixelRatio;
  // required this.aspectRatio, required this.pixelRatio
  const WatermarkPhoto({super.key, });

  @override
  _WatermarkPhotoState createState() => _WatermarkPhotoState();
}

class _WatermarkPhotoState extends State<WatermarkPhoto> with WidgetsBindingObserver {
  final GlobalKey _cameraKey = GlobalKey();
  late CameraController _cameraController;

  TakeStatus _takeStatus = TakeStatus.preparing;
  late XFile _curFile;
  // late Timer _timer;
  bool _isCapturing = false;
  // double dpr = ui.window.devicePixelRatio;

  final logic = Get.put(WaterMarkLogic());
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    var time = formatDate(DateTime.now(), [yyyy, '-', mm, '-' , dd, ' ', HH, ':', nn, ':', ss]);
    logic.setTime(time);

    Permission.storage.request();
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
      // logic.setCameraController(CameraController(cameras.first, ResolutionPreset.high,
      //   enableAudio: false,
      //   imageFormatGroup: ImageFormatGroup.jpeg,
      // ));
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
    // || !_cameraController.value.isInitialized
    if (_cameraController == null || !_cameraController.value.isInitialized) {
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
    // _cameraController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
    Widget waterMark = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(logic.time.value, style: TextStyle(color: Colors.white, fontSize: 13),),
                    Text(logic.address.value, style: TextStyle(color: Colors.white, fontSize: 13),),
                    Text('测试', style: TextStyle(color: Colors.white, fontSize: 13),),
                  ],
                );

    if (_takeStatus == TakeStatus.confirm && _curFile != null) {
      area = Image.file(File(_curFile.path), fit: BoxFit.fitWidth,);
      // && _cameraController.value.isInitialized
    } else if (_cameraController != null && _cameraController.value.isInitialized) {
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
              // aspectRatio: widget.aspectRatio,
              aspectRatio: 0.75,
              child: area,
            ),
            Positioned(
                left: 10,
                right: 120,
                bottom: 10,
                child: waterMark
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    String flashIcon = 'assets/icon-flash-auto.png';
    // && _cameraController.value.isInitialized
    if (_cameraController != null && _cameraController.value.isInitialized) {
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
            icon: Image.asset(flashIcon, width: 32, height: 32,),
            onPressed: _toggleFlash
          ),
          IconButton(
            color: Colors.black,
            icon: Icon(
              Icons.camera_alt
            ),
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
      child = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                color: Colors.red,
              ),
              Text('本地照片')
            ],
          ),
          OutlinedButton(
            onPressed: _takePicture, 
            child: Icon(Icons.camera, color: Colors.black, size: 48,),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.water,
                color: Colors.black54,
              ),
              Text('水印')
            ],
          ),
        ],
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
      RenderRepaintBoundary boundary = _cameraKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      double dpr = ui.window.devicePixelRatio; // 获取当前设备的像素比
      var image = await boundary.toImage(pixelRatio: dpr);
      // 将image转化成byte
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (Platform.isIOS) {
        if(await Permission.photos.request().isGranted) {
          Uint8List images = byteData!.buffer.asUint8List();
          await ImageGallerySaver.saveImage(images);
          print('保存成功');
          Fluttertoast.showToast(
            msg:"保存成功"
          );
        }
      } else {
        if (await Permission.storage.request().isGranted) {
          Uint8List images = byteData!.buffer.asUint8List();
          await ImageGallerySaver.saveImage(images);
          print('保存成功');
          Fluttertoast.showToast(
            msg:"保存成功"
          );        
        } else {
          // 没有存储权限时，弹出没有存储权限的弹窗
          print('权限拒绝');
          // 打开权限
          openAppSettings();
        }
      }
    } catch (e) {
      print(e);
    }
    _isCapturing = false;
    _initCamera();
  } 
}