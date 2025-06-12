import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dx_project/data/character.dart';

class CharacterCustomizationPage extends StatefulWidget {
  const CharacterCustomizationPage({super.key});
  
  @override
  _CharacterCustomizationPageState createState() =>
      _CharacterCustomizationPageState();
}

class _CharacterCustomizationPageState extends State<CharacterCustomizationPage> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _error;
          
  // 서버 URL (실제 환경에 맞게 수정 필요)
  final String _serverUrl = 'http://192.168.0.12:5050/generate/prompt';

  Future<void> _generateCharacter() async {
    if (_promptController.text.isEmpty) {
      setState(() {
        _error = '캐릭터를 설명해주세요!';
      });
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
      _error = null;
    });
    
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': _promptController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
            setState(() {
            _generatedImageUrl = data['image_url'];
            });
        } else {
          setState(() {
            _error = data['error'] ?? '이미지 생성에 실패했습니다.';
          });
        }
      } else {
        setState(() {
          _error = '서버 오류가 발생했습니다: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = '네트워크 오류: 서버에 연결할 수 없습니다.';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _confirmAndReturnCharacter() {
    if (_generatedImageUrl == null) return;

    final newCharacter = Character(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _promptController.text.split(',').first, // 프롬프트의 첫 부분을 이름으로 사용
      description: _promptController.text,
      imageUrl: _generatedImageUrl!,
      persona: 'You are a helpful assistant based on the prompt: ${_promptController.text}',
      characterType: 'Custom',
      customization: {},
    );

    Navigator.of(context).pop(newCharacter);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나만의 캐릭터 만들기', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
              ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGeneratedImageDisplay(),
            const SizedBox(height: 24),
            _buildPromptInputField(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
          ],
        ),
            ),
    );
  }
  
  Widget _buildGeneratedImageDisplay() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF36D9D).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF36D9D).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _isGenerating
            ? const Center(
                child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    CircularProgressIndicator(color: Color(0xFFF36D9D)),
                    SizedBox(height: 16),
                    Text('캐릭터를 만들고 있어요...', style: TextStyle(color: Colors.black54)),
                  ],
              ),
              )
            : _generatedImageUrl != null
                ? Column(
                  children: [
                    Expanded(
                  child: Image.network(
                          _generatedImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, color: Colors.red, size: 50),
                        ),
                  ),
              Container(
                      width: double.infinity,
                      color: Colors.black.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          '이 캐릭터로 시작하기',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
                        onPressed: _confirmAndReturnCharacter,
                      ),
                ),
                  ],
                )
                : const Center(
                    child: Text(
                      '캐릭터 설명을 입력하고\n생성 버튼을 눌러주세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
              ),
        ),
      ),
    );
  }
  
  Widget _buildPromptInputField() {
    return TextField(
      controller: _promptController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: '캐릭터 설명',
        hintText: '예시: 핑크색 머리를 한, 안경을 쓴 귀여운 고양이 마법사',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF36D9D), width: 2),
              ),
      ),
      onChanged: (value) {
        if (_error != null) {
          setState(() {
            _error = null;
          });
        }
      },
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : _generateCharacter,
      icon: const Icon(Icons.auto_awesome),
      label: Text(_isGenerating ? '생성 중...' : '생성하기'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF36D9D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
                          ),
                    ),
    );
  }
} 