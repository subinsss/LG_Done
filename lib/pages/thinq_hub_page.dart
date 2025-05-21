import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/thinq_device.dart';
import 'package:ThinQ/services/thinq_service.dart';
import 'package:ThinQ/pages/device_detail_page.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class ThinQHubPage extends StatefulWidget {
  const ThinQHubPage({super.key});

  @override
  State<ThinQHubPage> createState() => _ThinQHubPageState();
}

class _ThinQHubPageState extends State<ThinQHubPage> {
  final ThinQService _thinqService = ThinQService();
  List<ThinQDevice> _devices = [];
  bool _isInitializing = true;
  bool _hasError = false;
  StreamSubscription? _deviceSubscription;
  
  // 필터링 및 정렬 옵션
  String _filterOption = 'all'; // 'all', 'connected', 'disconnected'
  String _sortOption = 'name'; // 'name', 'type', 'lastUpdated'
  
  @override
  void initState() {
    super.initState();
    _initializeThinQService();
  }
  
  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }
  
  // ThinQ 서비스 초기화 및 기기 스트림 구독
  Future<void> _initializeThinQService() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
    });
    
    try {
      // 서비스 초기화
      await _thinqService.initialize();
      
      // 기기 목록 스트림 구독
      _deviceSubscription = _thinqService.devicesStream.listen(
        (devices) {
          setState(() {
            _devices = devices;
            _isInitializing = false;
          });
        },
        onError: (error) {
          print('기기 스트림 오류: $error');
          setState(() {
            _hasError = true;
            _isInitializing = false;
          });
        },
      );
      
      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'thinq_hub_opened',
        parameters: {
          'device_count': _thinqService.getAllDevices().length,
        },
      );
    } catch (e) {
      print('ThinQ 서비스 초기화 중 오류 발생: $e');
      setState(() {
        _hasError = true;
        _isInitializing = false;
      });
    }
  }
  
  // 필터링된 기기 목록 가져오기
  List<ThinQDevice> get _filteredDevices {
    var filteredList = List<ThinQDevice>.from(_devices);
    
    // 연결 상태로 필터링
    if (_filterOption == 'connected') {
      filteredList = filteredList.where((device) => device.isConnected).toList();
    } else if (_filterOption == 'disconnected') {
      filteredList = filteredList.where((device) => !device.isConnected).toList();
    }
    
    // 정렬
    switch (_sortOption) {
      case 'name':
        filteredList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'type':
        filteredList.sort((a, b) => a.deviceType.compareTo(b.deviceType));
        break;
      case 'lastUpdated':
        filteredList.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
    }
    
    return filteredList;
  }
  
  // 기기 타입에 따른 아이콘 가져오기
  IconData _getDeviceTypeIcon(String deviceType) {
    switch (deviceType) {
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
  
  // 기기 전원 토글
  Future<void> _toggleDevicePower(ThinQDevice device) async {
    try {
      final success = await _thinqService.togglePower(device.id);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${device.name}의 전원을 전환하는데 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // 분석 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'thinq_device_power_toggled',
        parameters: {
          'device_id': device.id,
          'device_type': device.deviceType,
          'success': success,
        },
      );
    } catch (e) {
      print('기기 전원 토글 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기기 제어 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 기기 상세 페이지로 이동
  void _navigateToDeviceDetail(ThinQDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailPage(device: device),
      ),
    );
    
    // 분석 이벤트 기록
    FirebaseAnalytics.instance.logEvent(
      name: 'thinq_device_detail_opened',
      parameters: {
        'device_id': device.id,
        'device_type': device.deviceType,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ThinQ 허브',
          style: TextStyle(
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
            onPressed: _isInitializing ? null : _initializeThinQService,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, color: Colors.black87),
            onSelected: (value) {
              if (value.startsWith('filter_')) {
                setState(() {
                  _filterOption = value.substring(7);
                });
              } else if (value.startsWith('sort_')) {
                setState(() {
                  _sortOption = value.substring(5);
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter_header',
                enabled: false,
                child: Text(
                  '필터',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              CheckedPopupMenuItem(
                value: 'filter_all',
                checked: _filterOption == 'all',
                child: const Text('모든 기기'),
              ),
              CheckedPopupMenuItem(
                value: 'filter_connected',
                checked: _filterOption == 'connected',
                child: const Text('연결된 기기'),
              ),
              CheckedPopupMenuItem(
                value: 'filter_disconnected',
                checked: _filterOption == 'disconnected',
                child: const Text('연결 끊긴 기기'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sort_header',
                enabled: false,
                child: Text(
                  '정렬',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              CheckedPopupMenuItem(
                value: 'sort_name',
                checked: _sortOption == 'name',
                child: const Text('이름순'),
              ),
              CheckedPopupMenuItem(
                value: 'sort_type',
                checked: _sortOption == 'type',
                child: const Text('기기 유형별'),
              ),
              CheckedPopupMenuItem(
                value: 'sort_lastUpdated',
                checked: _sortOption == 'lastUpdated',
                child: const Text('최근 업데이트순'),
              ),
            ],
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorView()
              : _filteredDevices.isEmpty
                  ? _buildEmptyView()
                  : _buildDeviceList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 기기 추가 기능 구현
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('새 기기 추가 기능은 준비 중입니다'),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // 오류 화면
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            '기기를 불러오는 중 오류가 발생했습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeThinQService,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
  
  // 빈 화면
  Widget _buildEmptyView() {
    String message;
    
    if (_filterOption == 'connected') {
      message = '연결된 기기가 없습니다.';
    } else if (_filterOption == 'disconnected') {
      message = '연결이 끊긴 기기가 없습니다.';
    } else {
      message = '등록된 기기가 없습니다. 새 기기를 추가해보세요.';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // 기기 목록
  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredDevices[index];
        final bool isPowered = device.status['power'] == true;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () => _navigateToDeviceDetail(device),
            borderRadius: BorderRadius.circular(16),
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
                          color: device.isConnected
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getDeviceTypeIcon(device.deviceType),
                          color: device.isConnected ? Colors.blue : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: device.isConnected
                                        ? Colors.green
                                        : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  device.isConnected ? '연결됨' : '연결 안됨',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: device.isConnected
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (device.isConnected && isPowered) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '켜짐',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (device.isConnected)
                        Switch(
                          value: isPowered,
                          onChanged: (value) => _toggleDevicePower(device),
                          activeColor: Colors.blue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildDeviceStatusInfo(device),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 기기 상태 정보
  Widget _buildDeviceStatusInfo(ThinQDevice device) {
    Widget statusWidget;
    
    if (!device.isConnected) {
      return const Text(
        '기기가 연결되어 있지 않습니다',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      );
    }
    
    switch (device.deviceType) {
      case 'AIR_CONDITIONER':
        final mode = device.status['mode'] ?? '';
        final temp = device.status['temperature'] ?? 0;
        final fanSpeed = device.status['fanSpeed'] ?? '';
        
        statusWidget = Row(
          children: [
            _buildStatusItem(Icons.thermostat, '$temp°C'),
            _buildStatusItem(Icons.mode, mode),
            _buildStatusItem(Icons.air, '팬: $fanSpeed'),
          ],
        );
        break;
        
      case 'REFRIGERATOR':
        final refTemp = device.status['refrigeratorTemp'] ?? 0;
        final frzTemp = device.status['freezerTemp'] ?? 0;
        final ecoMode = device.status['ecoMode'] == true;
        
        statusWidget = Row(
          children: [
            _buildStatusItem(Icons.kitchen, '냉장: $refTemp°C'),
            _buildStatusItem(Icons.ac_unit, '냉동: $frzTemp°C'),
            if (ecoMode) _buildStatusItem(Icons.eco, '절전 모드'),
          ],
        );
        break;
        
      case 'WASHER':
        final cycle = device.status['cycle'] ?? '';
        final timeRemaining = device.status['timeRemaining'] ?? 0;
        
        statusWidget = Row(
          children: [
            _buildStatusItem(Icons.settings, cycle),
            if (timeRemaining > 0)
              _buildStatusItem(Icons.timer, '$timeRemaining분 남음'),
          ],
        );
        break;
        
      default:
        statusWidget = const Text(
          '상세 정보를 보려면 기기를 탭하세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        );
    }
    
    return statusWidget;
  }
  
  // 상태 아이템 위젯
  Widget _buildStatusItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} 