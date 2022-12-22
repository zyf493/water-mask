// import 'package:get/get_state_manager/get_state_manager.dart';

import 'package:get/get.dart';
import 'package:camera/camera.dart';

class WaterMarkLogic extends GetxController{
  var aspectRatio = 0.75.obs;
  var time = ''.obs;
  var address = '未知位置'.obs;


  late CameraController cameraController;

  void setTime (val){
    time.value = val;
  }

  void setAddress (val){
    address.value = val;
  }

  void setCameraController (val){
    cameraController.value = val;
  }

  @override
  void onClose() {
    // TODO: implement onClose
    cameraController.dispose();
    super.onClose();
  }
}