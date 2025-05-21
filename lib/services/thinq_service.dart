import 'dart:async';
import 'package:ThinQ/data/thinq_device.dart';

class ThinQService {
  // 싱글톤 패턴 구현
  static final ThinQService _instance = ThinQService._internal();
  factory ThinQService() => _instance;
  ThinQService._internal();

  // 현재 연결된 기기 목록
  List<ThinQDevice> _devices = [];
  
  // 기기 상태 업데이트 스트림 컨트롤러
  final _deviceStreamController = StreamController<List<ThinQDevice>>.broadcast();
  Stream<List<ThinQDevice>> get devicesStream => _deviceStreamController.stream;
  
  // 기기 목록 초기화 및 샘플 데이터 로드
  Future<void> initialize() async {
    // 실제 구현에서는 LG ThinQ API를 통해 실제 기기 정보를 가져와야 함
    // 현재는 샘플 데이터로 대체
    _devices = ThinQDevice.getSampleDevices();
    _deviceStreamController.add(_devices);
    
    // 주기적으로 기기 상태 업데이트 (실제로는 LG ThinQ API를 통해 폴링 또는 웹소켓으로 처리)
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateDeviceStatus();
    });
  }
  
  // 모든 기기 가져오기
  List<ThinQDevice> getAllDevices() {
    return List.unmodifiable(_devices);
  }
  
  // 기기 ID로 기기 가져오기
  ThinQDevice? getDeviceById(String deviceId) {
    try {
      return _devices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }
  
  // 기기 유형별로 기기 가져오기
  List<ThinQDevice> getDevicesByType(String deviceType) {
    return _devices.where((device) => device.deviceType == deviceType).toList();
  }
  
  // 기기 제어 함수 (예: 에어컨 온도 설정)
  Future<bool> setDeviceProperty(String deviceId, String property, dynamic value) async {
    try {
      // 기기 찾기
      final deviceIndex = _devices.indexWhere((device) => device.id == deviceId);
      if (deviceIndex == -1) {
        return false;
      }
      
      // 기기가 연결되어 있지 않으면 실패
      if (!_devices[deviceIndex].isConnected) {
        return false;
      }
      
      // 실제 구현에서는 LG ThinQ API를 통해 명령을 전송
      // 여기서는 로컬 데이터 수정으로 시뮬레이션
      
      // 기기 상태 복사 및 속성 업데이트
      final updatedStatus = Map<String, dynamic>.from(_devices[deviceIndex].status);
      updatedStatus[property] = value;
      
      // 새 기기 객체 생성 (불변성 유지)
      final updatedDevice = _devices[deviceIndex].copyWith(
        status: updatedStatus,
        lastUpdated: DateTime.now(),
      );
      
      // 기기 목록 업데이트
      _devices[deviceIndex] = updatedDevice;
      
      // 변경 통지
      _deviceStreamController.add(_devices);
      
      return true;
    } catch (e) {
      print('기기 제어 중 오류 발생: $e');
      return false;
    }
  }
  
  // 기기 전원 켜기/끄기
  Future<bool> togglePower(String deviceId) async {
    try {
      // 기기 찾기
      final deviceIndex = _devices.indexWhere((device) => device.id == deviceId);
      if (deviceIndex == -1) {
        return false;
      }
      
      // 기기가 연결되어 있지 않으면 실패
      if (!_devices[deviceIndex].isConnected) {
        return false;
      }
      
      // 현재 전원 상태 확인
      final currentStatus = _devices[deviceIndex].status;
      final bool currentPower = currentStatus['power'] ?? false;
      
      // 전원 상태 토글
      return await setDeviceProperty(deviceId, 'power', !currentPower);
    } catch (e) {
      print('전원 토글 중 오류 발생: $e');
      return false;
    }
  }
  
  // 기기 상태 업데이트 (실제로는 LG ThinQ API를 통해 폴링)
  void _updateDeviceStatus() {
    // 실제 구현에서는 LG ThinQ API를 통해 최신 상태를 가져와야 함
    // 여기서는 간단한 시뮬레이션만 수행
    
    try {
      // 랜덤하게 일부 기기의 상태를 업데이트 (시뮬레이션)
      if (_devices.isNotEmpty) {
        // 현재는 단순히 마지막 업데이트 시간만 갱신
        final updatedDevices = _devices.map((device) {
          if (device.isConnected) {
            return device.copyWith(lastUpdated: DateTime.now());
          }
          return device;
        }).toList();
        
        _devices = updatedDevices;
        _deviceStreamController.add(_devices);
      }
    } catch (e) {
      print('기기 상태 업데이트 중 오류 발생: $e');
    }
  }
  
  // 모든 리소스 해제
  void dispose() {
    _deviceStreamController.close();
  }
} 