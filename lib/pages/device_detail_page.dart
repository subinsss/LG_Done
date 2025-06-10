import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dx_project/data/thinq_device.dart';
import 'package:dx_project/services/thinq_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';

class DeviceDetailPage extends StatefulWidget {
  final ThinQDevice device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final ThinQService _thinqService = ThinQService();
  late ThinQDevice _device;
  late StreamSubscription _deviceSubscription;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _subscribeToDeviceUpdates();
    
    // 분석 이벤트 기록
    FirebaseAnalytics.instance.logEvent(
      name: 'device_detail_viewed',
      parameters: {
        'device_id': _device.id,
        'device_type': _device.deviceType,
      },
    );
  }
  
  @override
  void dispose() {
    _deviceSubscription.cancel();
    super.dispose();
  }
  
  // 기기 업데이트 구독
  void _subscribeToDeviceUpdates() {
    _deviceSubscription = _thinqService.devicesStream.listen(
      (devices) {
        final updatedDevice = devices.firstWhere(
          (device) => device.id == _device.id,
          orElse: () => _device,
        );
        
        if (mounted) {
          setState(() {
            _device = updatedDevice;
          });
        }
      },
      onError: (error) {
        print('기기 스트림 오류: $error');
      },
    );
  }
  
  // 기기 속성 변경
  Future<void> _setDeviceProperty(String property, dynamic value) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _thinqService.setDeviceProperty(_device.id, property, value);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_device.name}의 설정을 변경하는데 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'device_property_changed',
        parameters: {
          'device_id': _device.id,
          'device_type': _device.deviceType,
          'property': property,
          'success': success,
        },
      );
    } catch (e) {
      print('기기 속성 변경 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기기 제어 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 기기 전원 토글
  Future<void> _togglePower() async {
    if (!_device.isConnected) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _thinqService.togglePower(_device.id);
    } catch (e) {
      print('전원 토글 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전원을 전환하는 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 기기 정보 새로고침
  void _refreshDeviceInfo() {
    setState(() {
      _isLoading = true;
    });
    
    // 실제로는 ThinQ API에서 새로운 데이터를 가져와야 함
    // 현재는 딜레이만 시뮬레이션
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _device.name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _refreshDeviceInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_device.isConnected
              ? _buildDisconnectedView()
              : _buildDeviceDetailView(),
    );
  }
  
  // 연결 끊긴 기기 화면
  Widget _buildDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '${_device.name}에 연결할 수 없습니다',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '기기의 전원과 네트워크 연결 상태를 확인해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshDeviceInfo,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 기기 상세 화면
  Widget _buildDeviceDetailView() {
    final bool isPowered = _device.status['power'] ?? false;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기기 기본 정보 카드
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getDeviceTypeIcon(),
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _device.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDeviceTypeName(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isPowered,
                        onChanged: (value) => _togglePower(),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem('모델 번호', _device.modelNumber),
                      _buildInfoItem(
                        '마지막 업데이트',
                        DateFormat('yyyy-MM-dd HH:mm').format(_device.lastUpdated),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 기기 상태 및 제어 섹션
          if (isPowered) ...[
            Text(
              '기기 제어',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // 기기 타입별 제어 패널
            _buildDeviceTypeControls(),
          ],
          
          const SizedBox(height: 24),
          
          // 기기 상태 로그 (가상 데이터)
          Text(
            '상태 로그',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusLog(),
        ],
      ),
    );
  }
  
  // 기기 타입에 따른 아이콘
  IconData _getDeviceTypeIcon() {
    switch (_device.deviceType) {
      case 'AIR_CONDITIONER':
        return Icons.ac_unit;
      case 'REFRIGERATOR':
        return Icons.kitchen;
      case 'WASHER':
        return Icons.local_laundry_service;
      case 'OVEN':
        return Icons.microwave;
      case 'TV':
        return Icons.tv;
      case 'ROBOT_CLEANER':
        return Icons.cleaning_services;
      default:
        return Icons.devices_other;
    }
  }
  
  // 기기 타입 이름 변환
  String _getDeviceTypeName() {
    switch (_device.deviceType) {
      case 'AIR_CONDITIONER':
        return '에어컨';
      case 'REFRIGERATOR':
        return '냉장고';
      case 'WASHER':
        return '세탁기';
      case 'OVEN':
        return '오븐';
      case 'TV':
        return '텔레비전';
      case 'ROBOT_CLEANER':
        return '로봇 청소기';
      default:
        return '기타 기기';
    }
  }
  
  // 정보 아이템 위젯
  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // 기기 타입별 제어 인터페이스
  Widget _buildDeviceTypeControls() {
    switch (_device.deviceType) {
      case 'AIR_CONDITIONER':
        return _buildAirConditionerControls();
      case 'REFRIGERATOR':
        return _buildRefrigeratorControls();
      case 'WASHER':
        return _buildWasherControls();
      default:
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '이 기기 유형에 대한 상세 제어는 준비 중입니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    }
  }
  
  // 에어컨 제어 인터페이스
  Widget _buildAirConditionerControls() {
    final temperature = _device.status['temperature'] ?? 24;
    final mode = _device.status['mode'] ?? 'COOL';
    final fanSpeed = _device.status['fanSpeed'] ?? 'AUTO';
    
    // 가능한 모드 및 팬 속도 목록 (capabilities에서 가져와야 함)
    final modes = (_device.capabilities['modes'] as List<dynamic>?) ?? ['COOL', 'HEAT', 'DRY', 'FAN'];
    final fanSpeeds = (_device.capabilities['fanSpeeds'] as List<dynamic>?) ?? ['LOW', 'MEDIUM', 'HIGH', 'AUTO'];
    
    // 온도 범위
    final tempRange = (_device.capabilities['tempRange'] as Map<String, dynamic>?) ?? {'min': 18, 'max': 30};
    final minTemp = (tempRange['min'] as num).toInt();
    final maxTemp = (tempRange['max'] as num).toInt();
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 온도 조절
            Text(
              '온도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: temperature <= minTemp
                      ? null
                      : () => _setDeviceProperty('temperature', temperature - 1),
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$temperature°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: temperature >= maxTemp
                      ? null
                      : () => _setDeviceProperty('temperature', temperature + 1),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 모드 선택
            Text(
              '모드',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: modes.map((m) {
                  bool isSelected = m == mode;
                  IconData icon;
                  
                  switch (m) {
                    case 'COOL':
                      icon = Icons.ac_unit;
                      break;
                    case 'HEAT':
                      icon = Icons.whatshot;
                      break;
                    case 'DRY':
                      icon = Icons.water_drop;
                      break;
                    case 'FAN':
                      icon = Icons.air;
                      break;
                    default:
                      icon = Icons.settings;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(m),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _setDeviceProperty('mode', m);
                        }
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // 팬 속도
            Text(
              '팬 속도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: fanSpeeds.map((fs) {
                  bool isSelected = fs == fanSpeed;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(fs),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _setDeviceProperty('fanSpeed', fs);
                        }
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 냉장고 제어 인터페이스
  Widget _buildRefrigeratorControls() {
    final refrigeratorTemp = _device.status['refrigeratorTemp'] ?? 3;
    final freezerTemp = _device.status['freezerTemp'] ?? -18;
    final ecoMode = _device.status['ecoMode'] ?? false;
    
    // 온도 범위
    final refrigeratorTempRange = (_device.capabilities['refrigeratorTempRange'] as Map<String, dynamic>?) ?? {'min': 1, 'max': 7};
    final freezerTempRange = (_device.capabilities['freezerTempRange'] as Map<String, dynamic>?) ?? {'min': -23, 'max': -15};
    
    final minRefTemp = (refrigeratorTempRange['min'] as num).toInt();
    final maxRefTemp = (refrigeratorTempRange['max'] as num).toInt();
    final minFrzTemp = (freezerTempRange['min'] as num).toInt();
    final maxFrzTemp = (freezerTempRange['max'] as num).toInt();
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 냉장실 온도
            Text(
              '냉장실 온도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: refrigeratorTemp <= minRefTemp
                      ? null
                      : () => _setDeviceProperty('refrigeratorTemp', refrigeratorTemp - 1),
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$refrigeratorTemp°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: refrigeratorTemp >= maxRefTemp
                      ? null
                      : () => _setDeviceProperty('refrigeratorTemp', refrigeratorTemp + 1),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 냉동실 온도
            Text(
              '냉동실 온도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: freezerTemp <= minFrzTemp
                      ? null
                      : () => _setDeviceProperty('freezerTemp', freezerTemp - 1),
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$freezerTemp°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: freezerTemp >= maxFrzTemp
                      ? null
                      : () => _setDeviceProperty('freezerTemp', freezerTemp + 1),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 절전 모드
            Row(
              children: [
                Expanded(
                  child: Text(
                    '절전 모드',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Switch(
                  value: ecoMode,
                  onChanged: (value) => _setDeviceProperty('ecoMode', value),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 세탁기 제어 인터페이스
  Widget _buildWasherControls() {
    final cycle = _device.status['cycle'] ?? 'NORMAL';
    final cycles = (_device.capabilities['cycles'] as List<dynamic>?) ?? ['NORMAL', 'HEAVY', 'DELICATE', 'QUICK', 'ECO'];
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 세탁 코스
            Text(
              '세탁 코스',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cycles.map((c) {
                bool isSelected = c == cycle;
                return ChoiceChip(
                  label: Text(c),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _setDeviceProperty('cycle', c);
                    }
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            // 시작 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: 세탁 시작 기능 구현
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('세탁 시작 기능은 준비 중입니다'),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('세탁 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 상태 로그 위젯 (가상 데이터)
  Widget _buildStatusLog() {
    // 가상의 로그 데이터
    final logs = [
      {
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'event': '온도가 ${_device.status['temperature'] ?? 24}°C로 설정되었습니다.',
      },
      {
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'event': '기기가 켜졌습니다.',
      },
      {
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'event': '기기가 꺼졌습니다.',
      },
      {
        'time': DateTime.now().subtract(const Duration(hours: 6)),
        'event': '정상 작동 중입니다.',
      },
    ];
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: logs.map((log) {
            final time = log['time'] as DateTime;
            final event = log['event'] as String;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(time),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
} 