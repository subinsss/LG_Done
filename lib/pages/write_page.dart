import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ThinQ/logging.dart';
import 'package:ThinQ/widgets/barrier_progress_indicator.dart';
import 'package:ThinQ/widgets/haptic_feedback.dart';
import 'package:ThinQ/widgets/rounded_inkwell.dart';

class WritePage extends StatefulWidget {
  const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  bool _isLoading = false;
  final List<XFile> _pickedImages = [];

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _studyTimeController = TextEditingController();
  String _selectedStudyType = '공부 유형 선택';

  // 공부 유형 리스트
  final List<String> _studyTypes = [
    '공부 유형 선택',
    '코딩',
    '외국어',
    '독서',
    '수학',
    '과학',
    '인문학',
    '예술',
    '기타'
  ];

  @override
  Widget build(BuildContext context) {
    return BarrierProgressIndicator(
      isActive: _isLoading,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(),
              _buildStudyTimeInput(),
              _buildStudyTypeDropdown(),
              _buildSelectedImages(),
              Container(height: 20),
              _buildShareButton(context),
            ],
          ),
        ),
        floatingActionButton: _buildPhotoButton(),
      ),
    );
  }

  Widget _buildStudyTimeInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공부 시간 (분)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _studyTimeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '공부한 시간을 분 단위로 입력하세요 (예: 120)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공부 유형',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: _selectedStudyType,
              isExpanded: true,
              underline: SizedBox(),
              items: _studyTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedStudyType = newValue!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImages() {
    const double itemSize = 60;
    return Container(
      height: itemSize,
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 100),
        children: [
          for (final image in _pickedImages)
            _buildSelectedImage(
              image,
              itemSize,
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedImage(XFile image, double itemSize) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: kIsWeb
                ? Image.network(image.path)
                : Image.file(
                    File(image.path),
                    width: itemSize,
                    height: itemSize,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(right: 16, top: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.close_rounded,
                size: 12,
                color: Colors.white70,
              ),
              onPressed: () {
                setState(() {
                  _pickedImages.remove(image);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoButton() {
    return Container(
      margin: EdgeInsets.only(bottom: 80),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.orangeAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(
          Icons.photo_size_select_actual_outlined,
          color: Colors.white,
        ),
        onPressed: () async {
          logGoogleAnalyticsEvent(
            "photo_button_clicked",
            {
              "page": "write_page",
              "image_count": _pickedImages.length,
            },
          );

          if (_pickedImages.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('이미지는 최대 1개까지 선택 가능합니다.'),
            ));
            ThinQHaptic.error();
            return;
          }

          // 사진첩에서 사진 선택
          final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

          // 선택한 파일이 없으면 종료
          if (pickedFile == null) exit(0);

          setState(() {
            _pickedImages.add(pickedFile);
          });
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF1F2F3),
      title: const Text(
        '새 게시물',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      height: 150,
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          hintText: '문구를 작성하거나 설문을 추가하세요...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.black45,
          ),
          border: OutlineInputBorder(),
        ),
        onChanged: (_) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return SafeArea(
      child: RoundedInkWell(
        onTap: () {
          if (_textController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('게시물을 입력해주세요.'),
            ));
            ThinQHaptic.error();
            return;
          }
          _uploadPost(context);
        },
        margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _textController.text.isEmpty ? Colors.black26 : Color(0xFF4B61EF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '공유',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadPost(BuildContext context) async {
    // TextField가 비어있으면 게시물을 업로드하지 않음
    if (_textController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 필요시 사진 업로드
      String? imageUrl = await _uploadImage(context);

      // 공부 시간 데이터 처리
      int? studyTime;
      if (_studyTimeController.text.isNotEmpty) {
        studyTime = int.tryParse(_studyTimeController.text);
      }

      // 공부 유형 데이터 처리
      String? studyType;
      if (_selectedStudyType != '공부 유형 선택') {
        studyType = _selectedStudyType;
      }

      // Firestore의 posts 컬렉션에 게시물 추가하기
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final CollectionReference posts = FirebaseFirestore.instance.collection('posts');
        await posts.add({
          'uid': user.uid,
          'username': user.displayName ?? '알 수 없음',
          'description': _textController.text,
          'imageUrl': imageUrl,
          'likes': [],
          'comments': [],
          'createdAt': FieldValue.serverTimestamp(),
          'studyTime': studyTime,
          'studyType': studyType,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시물이 등록되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('게시물 업로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('게시물 업로드 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _uploadImage(BuildContext context) async {
    try {
      setState(() => _isLoading = true);

      final pickedFile = _pickedImages.firstOrNull;

      // 선택한 파일이 없다면 종료
      if (pickedFile == null) {
        return null;
      }

      // Storage에 업로드할 위치 설정하기
      final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final String pathName = '/user/$uid/$fileName';

      // Storage에 업로드
      await FirebaseStorage.instance.ref(pathName).putData(
            await pickedFile.readAsBytes(),
            SettableMetadata(
              contentType: pickedFile.mimeType,
            ),
          );

      // 업로드된 파일의 URL 가져오기
      String downloadURL = await FirebaseStorage.instance.ref(pathName).getDownloadURL();
      return downloadURL;
    } catch (e) {
      // 오류 처리
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('이미지 업로드에 실패했습니다.'),
      ));
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
