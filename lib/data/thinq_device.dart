import 'package:cloud_firestore/cloud_firestore.dart';

class ThinQDevice {
  final String id;
  final String name;
  final String deviceType; // 에어컨, 냉장고, 세탁기 등
  final String modelNumber;
  final bool isConnected; // 연결 상태
  final Map<String, dynamic> status; // 기기 상태 정보 (온도, 모드 등)
  final Map<String, dynamic> capabilities; // 기기가 할 수 있는 기능
  final DateTime lastUpdated; // 마지막 업데이트 시간

  ThinQDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.modelNumber,
    required this.isConnected,
    required this.status,
    required this.capabilities,
    required this.lastUpdated,
  });

  ThinQDevice copyWith({
    String? id,
    String? name,
    String? deviceType,
    String? modelNumber,
    bool? isConnected,
    Map<String, dynamic>? status,
    Map<String, dynamic>? capabilities,
    DateTime? lastUpdated,
  }) {
    return ThinQDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      modelNumber: modelNumber ?? this.modelNumber,
      isConnected: isConnected ?? this.isConnected,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deviceType': deviceType,
      'modelNumber': modelNumber,
      'isConnected': isConnected,
      'status': status,
      'capabilities': capabilities,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory ThinQDevice.fromMap(Map<String, dynamic> map, String docId) {
    return ThinQDevice(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      deviceType: map['deviceType'] ?? '',
      modelNumber: map['modelNumber'] ?? '',
      isConnected: map['isConnected'] ?? false,
      status: Map<String, dynamic>.from(map['status'] ?? {}),
      capabilities: Map<String, dynamic>.from(map['capabilities'] ?? {}),
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'])
          : DateTime.now(),
    );
  }

  // 샘플 기기 목록 생성
  static List<ThinQDevice> getSampleDevices() {
    return [
      // 에어컨
      ThinQDevice(
        id: 'ac_001',
        name: '거실 에어컨',
        deviceType: 'AIR_CONDITIONER',
        modelNumber: 'LG-AC2023-X',
        isConnected: true,
        status: {
          'power': true,
          'temperature': 24,
          'mode': 'COOL',
          'fanSpeed': 'AUTO',
        },
        capabilities: {
          'modes': ['COOL', 'HEAT', 'DRY', 'FAN'],
          'fanSpeeds': ['LOW', 'MEDIUM', 'HIGH', 'AUTO'],
          'tempRange': {'min': 18, 'max': 30},
        },
        lastUpdated: DateTime.now(),
      ),
      
      // 냉장고
      ThinQDevice(
        id: 'ref_001',
        name: '주방 냉장고',
        deviceType: 'REFRIGERATOR',
        modelNumber: 'LG-RF2023-X',
        isConnected: true,
        status: {
          'power': true,
          'refrigeratorTemp': 3,
          'freezerTemp': -18,
          'ecoMode': false,
          'doorOpen': false,
        },
        capabilities: {
          'refrigeratorTempRange': {'min': 1, 'max': 7},
          'freezerTempRange': {'min': -23, 'max': -15},
        },
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      
      // 세탁기
      ThinQDevice(
        id: 'wash_001',
        name: '세탁실 세탁기',
        deviceType: 'WASHER',
        modelNumber: 'LG-WM2023-X',
        isConnected: true,
        status: {
          'power': false,
          'cycle': 'NORMAL',
          'timeRemaining': 0,
          'waterTemp': 'WARM',
          'spinSpeed': 'MEDIUM',
        },
        capabilities: {
          'cycles': ['NORMAL', 'HEAVY', 'DELICATE', 'QUICK', 'ECO'],
          'waterTemps': ['COLD', 'WARM', 'HOT'],
          'spinSpeeds': ['LOW', 'MEDIUM', 'HIGH'],
        },
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      
      // TV
      ThinQDevice(
        id: 'tv_001',
        name: '거실 TV',
        deviceType: 'TV',
        modelNumber: 'LG-TV2023-X',
        isConnected: false,
        status: {
          'power': false,
          'volume': 15,
          'channel': 7,
          'input': 'HDMI1',
        },
        capabilities: {
          'inputs': ['TV', 'HDMI1', 'HDMI2', 'USB'],
        },
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      ),
      
      // 로봇 청소기
      ThinQDevice(
        id: 'robot_001',
        name: '로봇 청소기',
        deviceType: 'ROBOT_CLEANER',
        modelNumber: 'LG-RC2023-X',
        isConnected: true,
        status: {
          'power': true,
          'mode': 'AUTO',
          'battery': 75,
          'cleaning': false,
          'docked': true,
        },
        capabilities: {
          'modes': ['AUTO', 'SPOT', 'EDGE', 'TURBO'],
        },
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ];
  }
} 