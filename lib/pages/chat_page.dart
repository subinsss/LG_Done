import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ThinQ/pages/model.dart';
import 'package:ThinQ/data/character.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class ChatPage extends StatefulWidget {
  final Character? character;
  
  const ChatPage({super.key, this.character});

  @override
  State<ChatPage> createState() => _ChatGptAppState();
}

class _ChatGptAppState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _canSendMessage = false;
  bool _isGeneratingImage = false;
  ChatRoom _room = ChatRoom(chats: [], createdAt: DateTime.now());
  bool _isImageLoaded = false;

  late GenerativeModel model;

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(
      model: "gemini-2.5-flash-preview-04-17",
      apiKey: "AIzaSyAhe-vFRTiY_MddqG0kawcA3Y09WtDugBs"// 여러분이 만드신 API키를 넣어주세요,
    );
    model.startChat();
    
    // 위젯이 완전히 마운트된 후 이미지 프리캐싱 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheCharacterImage();
    });
  }

  @override
  void dispose() {
    // 더이상 이 화면이 필요없게 되는 순간
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.white,
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        widget.character?.name ?? "GPT",
        style: TextStyle(
          fontSize: 14,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 채팅 메시지 영역
        Expanded(
          child: ListView.builder(
            itemCount: _room.chats.length,
            padding: EdgeInsets.only(top: 16),
            itemBuilder: (context, index) {
              return _buildBubble(_room.chats[index]);
            },
          ),
        ),
        
        // 이미지 생성 중 표시
        if (_isGeneratingImage)
          Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.character?.getAvatarBackgroundColor() ?? Colors.grey,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text('이미지 생성 중...', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ),
          ),
        
        // 입력 필드
        Container(
          margin: EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(child: buildTextField()),
              // 이미지 생성 버튼 추가
              IconButton(
                icon: Icon(Icons.image, color: Colors.grey[700]),
                onPressed: _isGeneratingImage ? null : () => _generateStableDiffusionImage(),
                tooltip: '이미지 생성하기',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatMessage chat) {
    return GestureDetector(
      onLongPress: () {
        // 롱프레스로 길게 눌렀을 때 말풍선에 있는 텍스트 복사!
        Clipboard.setData(ClipboardData(text: chat.text));
      },
      onDoubleTap: () {
        // 해당 말풍선을 삭제
        setState(() {
          _room.chats.remove(chat);
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          mainAxisAlignment:
              chat.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat.isMe == false)
              Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: _buildChatAvatar(),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: chat.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Text(chat.text),
                    decoration: BoxDecoration(
                      color: chat.isMe ? Colors.grey[100] : widget.character?.getAvatarBackgroundColor().withOpacity(0.1) ?? Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    constraints: BoxConstraints(maxWidth: chat.isMe ? 200 : 300),
                  ),
                  // 이미지가 있으면 표시
                  if (chat.imageUrl != null && chat.imageUrl!.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: CachedNetworkImage(
                          imageUrl: chat.imageUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: Icon(Icons.error_outline, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAvatar() {
    // 채팅 말풍선 옆의 작은 아바타 이미지
    if (widget.character == null) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(Icons.person, size: 20, color: Colors.grey[700]),
      );
    }
    
    // 네트워크 이미지 우선 사용
    if (widget.character!.networkImageUrl != null && widget.character!.networkImageUrl!.isNotEmpty) {
      return Container(
        width: 30,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: widget.character!.getAvatarBackgroundColor().withOpacity(0.3),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: widget.character!.networkImageUrl!,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            width: 30,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: widget.character!.getAvatarBackgroundColor().withOpacity(0.3),
            ),
            child: Icon(
              widget.character!.getAvatarIcon(),
              size: 20,
              color: widget.character!.getAvatarBackgroundColor(),
            ),
          ),
          errorWidget: (context, url, error) => _buildIconAvatar(),
        ),
      );
    } else {
      return _buildIconAvatar();
    }
  }

  Widget _buildIconAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.character!.getAvatarBackgroundColor().withOpacity(0.3),
      ),
      child: Icon(
        widget.character!.getAvatarIcon(),
        size: 20,
        color: widget.character!.getAvatarBackgroundColor(),
      ),
    );
  }

  Widget _buildSmallLocalAvatar() {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          widget.character!.imageUrl, 
          width: 30, 
          height: 30,
          errorBuilder: (context, error, stackTrace) => _buildIconAvatar(),
        ),
      );
    } catch (e) {
      return _buildIconAvatar();
    }
  }

  TextField buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: (text) {
        setState(() {
          _canSendMessage = text.isNotEmpty;
        });
      },
      onSubmitted: (text) {
        _sendMessage();
      },
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        suffixIcon: Container(
          width: 30,
          height: 30,
          margin: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _canSendMessage ? Colors.black : Colors.grey,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_upward_rounded, color: Colors.white),
            padding: EdgeInsets.zero,
            onPressed: _canSendMessage ? _sendMessage : null,
          ),
        ),
        hintText: "메시지",
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    
    // 포커스를 없애기
    _focusNode.unfocus();

    String question = _controller.text;
    
    // 전송 버튼을 비활성화
    // ListView에 방금 입력한 메시지 추가
    setState(() {
      _canSendMessage = false;
      _room.chats.add(
        ChatMessage(isMe: true, text: question, sentAt: DateTime.now()),
      );
    });

    // 챗지피티 말풍선을 노출 (처음에는 말풍선의 내용은 비어있다)
    setState(() {
      _room.chats.add(
        ChatMessage(isMe: false, text: "", sentAt: DateTime.now()),
      );
    });

    // 캐릭터 정보가 있다면 페르소나를 포함
    String prompt = "";
    if (widget.character != null) {
      prompt = "${widget.character!.persona}\n\n사용자: $question";
    } else {
      prompt = question;
    }

    model.generateContentStream([Content.text(prompt)]).listen((response) {
      // Gemini로부터 응답값을 받아볼 수 있도록 한다.
      if (mounted) {
        setState(() {
          if (response.text != null) {
            _room.chats.last.text += response.text!;
          }
        });
      }
    });

    // 이미지 관련 단어가 포함되어 있으면 이미지 생성
    if (question.contains('이미지') || question.contains('그림') || 
        question.contains('보여') || question.contains('보여줘') ||
        math.Random().nextDouble() < 0.1) {
      _generateStableDiffusionImage(prompt: question);
    }

    // 텍스트 필드 내용을 싹 지우기
    _controller.clear();
  }

  // Stable Diffusion API를 사용하여 이미지 생성
  Future<void> _generateStableDiffusionImage({String? prompt}) async {
    // 프롬프트가 없으면 캐릭터의 성격을 기반으로 만들기
    String imagePrompt = prompt ?? '';
    
    if (imagePrompt.isEmpty && widget.character != null) {
      // 캐릭터 타입 기반으로 프롬프트 생성
      switch (widget.character!.characterType) {
        case 'ENFJ':
          imagePrompt = "심리학자 캐릭터, 따뜻한 색감, 격려하는, 지원적인, 미래지향적인";
          break;
        case 'INTJ':
          imagePrompt = "전략가 캐릭터, 차가운 색감, 분석적인, 복잡한 도표, 미래적인";
          break;
        case 'INFP':
          imagePrompt = "창의적인 작가 캐릭터, 따뜻한 색감, 꿈꾸는, 책, 카페, 편안한";
          break;
        case 'ENTJ':
          imagePrompt = "리더 캐릭터, 자신감 있는, 붉은 색상, 도시 전망, 전문적인";
          break;
        default:
          imagePrompt = "캐릭터, 친근한, 밝은 색감, 웃는, 도움을 주는";
      }
    }
    
    // 영어로 번역된 프롬프트 (실제로는 API 번역이 더 좋을 수 있음)
    String englishPrompt = "Digital art, character portrait, ${imagePrompt}, high quality, detailed";
    
    setState(() {
      _isGeneratingImage = true;
    });

    try {
      // Replicate API 호출 (Stable Diffusion API)
      final response = await http.post(
        Uri.parse('https://api.replicate.com/v1/predictions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token r8_MWRDaIV2Nd0REwIjv5EiInbW1xtsFoC4RGVJE', // 실제 운영환경에서는 환경변수로 관리해야 함
        },
        body: jsonEncode({
          'version': 'ac732df83cea7fff18b8472768c88ad041fa750ff7682a21affe81863cbe77e4',
          'input': {
            'prompt': englishPrompt,
            'width': 512,
            'height': 512,
            'num_outputs': 1,
            'guidance_scale': 7.5,
            'num_inference_steps': 50,
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String predictionId = data['id'];
        
        // 이미지 생성이 완료될 때까지 폴링
        await _checkImageGenerationStatus(predictionId);
      } else {
        print('API 호출 실패: ${response.statusCode} ${response.body}');
        if (mounted) {
          setState(() {
            _isGeneratingImage = false;
          });
        }
      }
    } catch (e) {
      print('이미지 생성 오류: $e');
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
      }
    }
  }

  // 이미지 생성 상태 확인
  Future<void> _checkImageGenerationStatus(String predictionId) async {
    bool isCompleted = false;
    int retryCount = 0;
    const maxRetries = 30; // 최대 30번 시도 (약 5분)

    while (!isCompleted && retryCount < maxRetries) {
      try {
        final response = await http.get(
          Uri.parse('https://api.replicate.com/v1/predictions/$predictionId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token r8_MWRDaIV2Nd0REwIjv5EiInbW1xtsFoC4RGVJE',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['status'] == 'succeeded') {
            isCompleted = true;
            final List<dynamic> outputs = data['output'];
            
            if (outputs.isNotEmpty && outputs[0] is String) {
              final String imageUrl = outputs[0];
              
              // 채팅방에 이미지 추가
              if (mounted) {
                setState(() {
                  if (_room.chats.isNotEmpty) {
                    // 마지막 메시지의 이미지 URL 업데이트
                    _room.chats.last = _room.chats.last.copyWith(
                      imageUrl: imageUrl,
                    );
                  }
                  _isGeneratingImage = false;
                });
              }
            }
          } else if (data['status'] == 'failed') {
            print('이미지 생성 실패: ${data['error'] ?? "알 수 없는 오류"}');
            isCompleted = true;
            if (mounted) {
              setState(() {
                _isGeneratingImage = false;
              });
            }
          }
        } else {
          print('상태 확인 실패: ${response.statusCode} ${response.body}');
          retryCount++;
        }
      } catch (e) {
        print('상태 확인 오류: $e');
        retryCount++;
      }

      if (!isCompleted) {
        // 10초 기다렸다가 다시 확인
        await Future.delayed(Duration(seconds: 10));
      }
    }

    if (!isCompleted && mounted) {
      setState(() {
        _isGeneratingImage = false;
      });
    }
  }

  // 캐릭터 이미지를 안전하게 프리캐싱하는 메서드
  void _precacheCharacterImage() {
    if (widget.character != null && 
        widget.character!.networkImageUrl != null && 
        widget.character!.networkImageUrl!.isNotEmpty &&
        mounted) {
      precacheImage(
        NetworkImage(widget.character!.networkImageUrl!), 
        context
      ).then((_) {
        if (mounted) {
          setState(() {
            _isImageLoaded = true;
          });
        }
      });
    }
  }
}
