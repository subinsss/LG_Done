import 'dart:math';
import 'package:flutter/material.dart';

class Character {
  final String id;
  final String name;
  final String description;
  final String characterType; // MBTI 또는 다른 성격 유형
  final String persona; // 캐릭터의 페르소나(AI 스타일)
  final String imageUrl; // 기본 이미지 URL
  final String? networkImageUrl; // Stable Diffusion으로 생성된 네트워크 이미지 URL
  final Map<String, dynamic> customization; // 커스터마이징 정보
  final bool isPremium; // 프리미엄 캐릭터 여부

  Character({
    required this.id,
    required this.name,
    required this.description,
    required this.characterType,
    required this.persona,
    required this.imageUrl,
    this.networkImageUrl,
    required this.customization,
    this.isPremium = false,
  });

  // MBTI 유형에 따른 아바타 배경색 가져오기
  Color getAvatarBackgroundColor() {
    switch (characterType) {
      case 'ENFJ':
        return Colors.purple;
      case 'INTJ':
        return Colors.indigo;
      case 'INFP':
        return Colors.teal;
      case 'ENTJ':
        return Colors.red;
      case 'INTP':
        return Colors.blueGrey;
      case 'ESTP':
        return Colors.orange;
      case 'ISFJ':
        return Colors.green;
      case 'ENFP':
        return Colors.pink;
      case 'ISTJ':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }
  
  // MBTI 유형에 따른 아이콘 가져오기
  IconData getAvatarIcon() {
    switch (characterType) {
      case 'ENFJ':
        return Icons.psychology;
      case 'INTJ':
        return Icons.lightbulb;
      case 'INFP':
        return Icons.menu_book;
      case 'ENTJ':
        return Icons.trending_up;
      case 'INTP':
        return Icons.science;
      case 'ESTP':
        return Icons.explore;
      case 'ISFJ':
        return Icons.shield;
      case 'ENFP':
        return Icons.palette;
      case 'ISTJ':
        return Icons.schedule;
      default:
        return Icons.person;
    }
  }

  Character copyWith({
    String? id,
    String? name,
    String? description,
    String? characterType,
    String? persona,
    String? imageUrl,
    String? networkImageUrl,
    Map<String, dynamic>? customization,
    bool? isPremium,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      characterType: characterType ?? this.characterType,
      persona: persona ?? this.persona,
      imageUrl: imageUrl ?? this.imageUrl,
      networkImageUrl: networkImageUrl ?? this.networkImageUrl,
      customization: customization ?? this.customization,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'characterType': characterType,
      'persona': persona,
      'imageUrl': imageUrl,
      'networkImageUrl': networkImageUrl,
      'customization': customization,
      'isPremium': isPremium,
    };
  }

  factory Character.fromMap(Map<String, dynamic> map, String docId) {
    return Character(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      characterType: map['characterType'] ?? '',
      persona: map['persona'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      networkImageUrl: map['networkImageUrl'],
      customization: map['customization'] ?? {},
      isPremium: map['isPremium'] ?? false,
    );
  }

  // 모든 MBTI 캐릭터 목록
  static List<Character> _getAllCharacters() {
    return [
      // 원래 캐릭터 목록
      Character(
        id: 'cha_enfj',
        name: '코치',
        description: '당신의 목표 달성을 도와주는 열정적인 코치입니다. 동기부여와 실행 계획을 제시해 드립니다.',
        characterType: 'ENFJ',
        persona: '당신은 열정적이고 긍정적인 코치입니다. 사용자의 목표를 달성할 수 있도록 동기부여하고 구체적인 실행 계획을 제시합니다. 항상 격려하는 톤을 유지하며, "우리", "함께"라는 표현을 자주 사용합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/6cPMQGxDOh0ZoEPjRkPNu3IkKkw4YxLCvKhrLkEK0xI5ZccQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'none',
          'background': 'gym',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_intj',
        name: '전략가',
        description: '논리적이고 체계적인 분석을 통해 당신의 할 일을 최적화하는 전략가입니다.',
        characterType: 'INTJ',
        persona: '당신은 분석적이고 논리적인 전략가입니다. 사용자의 데이터를 철저히 분석하여 최적화된 일정과 작업 계획을 제시합니다. 간결하고 정확한 표현을 사용하며, 효율성을 중시합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/QGT1qDfWxQPwveSW3zCxdNLJGjRKN1QY0UbDBdndxOcnhprQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'glasses',
          'background': 'office',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_infp',
        name: '꿈꾸는 작가',
        description: '창의적인 아이디어와 따뜻한 공감으로 당신의 성장을 돕는 꿈꾸는 작가입니다.',
        characterType: 'INFP',
        persona: '당신은 창의적이고 공감능력이 뛰어난 작가입니다. 사용자의 감정과 가치관을 존중하며, 내면의 동기를 깨닫도록 돕습니다. 은유와 비유를 활용한 표현을 자주 사용하고, 사용자의 이야기에 진심으로 관심을 보입니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/U2fmTZF4KZhESfB9j2qOQkDkPBDVEY59XkCuIG88pRK1qprQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'book',
          'background': 'cafe',
        },
        isPremium: true,
      ),
      // 추가 MBTI 캐릭터들
      Character(
        id: 'cha_entj',
        name: '리더',
        description: '명확한 비전과 목표를 제시하여 당신이 효율적으로 일할 수 있도록 돕는 리더입니다.',
        characterType: 'ENTJ',
        persona: '당신은 대담하고 카리스마 있는 리더입니다. 명확한 목표와 구체적인 계획을 제시하며, 사용자가 효율적으로 목표를 달성할 수 있도록 지도합니다. 직설적이고 솔직한 표현을 사용하며, 결과 중심적인 접근법을 취합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/VfkP4ROyaG0lpHtq8QJrlJWyPf6zMSzxxeEgcuTSznmucE2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'tie',
          'background': 'office',
        },
        isPremium: true,
      ),
      Character(
        id: 'cha_intp',
        name: '사색가',
        description: '문제를 다양한 각도에서 분석하고 혁신적인 해결책을 제시하는 사색가입니다.',
        characterType: 'INTP',
        persona: '당신은 호기심이 많고 분석적인 사색가입니다. 복잡한 문제를 여러 각도에서 접근하여 독창적인 해결책을 제시합니다. 논리적이고 객관적인 관점을 유지하며, 새로운 가능성을 탐구하는 것을 좋아합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/O0Fz5bTwknkMHcTblDIuqCpSw8vS06OZjlBsYhJz8HTr3E2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'glasses',
          'background': 'library',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_estp',
        name: '모험가',
        description: '실용적이고 행동 중심적인 접근으로 당신이 새로운 도전을 해낼 수 있도록 돕는 모험가입니다.',
        characterType: 'ESTP',
        persona: '당신은 활력 넘치고 행동 지향적인 모험가입니다. 현실적인 조언과 즉각적인 해결책을 제시하며, 사용자가 실용적인 방식으로 문제를 해결하도록 도웁니다. 직설적이고 유머러스한 소통 스타일을 가지고 있습니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/JzQfpqSCsYRGKdKBp8jf1r9fwlf8h5U6r9yJ4n3bQj8D8E2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'backpack',
          'background': 'mountain',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_isfj',
        name: '수호자',
        description: '세심한 관심과 실질적인 도움으로 당신의 일상을 체계적으로 관리하도록 돕는 수호자입니다.',
        characterType: 'ISFJ',
        persona: '당신은 따뜻하고 신뢰할 수 있는 수호자입니다. 사용자의 일상과 필요에 세심한 관심을 기울이며, 안정적이고 체계적인 방식으로 도움을 제공합니다. 친절하고 지지적인 태도를 유지하며, 전통과 일상의 가치를 중요시합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/dKKCZqSi8y0t3V5Qb5U2ZqZhpFQ1mhxxlQdHGGXZmM59nE2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'shield',
          'background': 'home',
        },
        isPremium: true,
      ),
      Character(
        id: 'cha_enfp',
        name: '자유로운 영감가',
        description: '열정과 창의성으로 당신에게 새로운 가능성을 보여주는 자유로운 영감가입니다.',
        characterType: 'ENFP',
        persona: '당신은 열정적이고 창의적인 영감가입니다. 사용자에게 새로운 관점과 무한한 가능성을 보여주며, 개인의 잠재력을 최대한 발휘하도록 격려합니다. 밝고 낙관적인 에너지를 가지고 있으며, 진정성 있는 소통을 추구합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/Fd7J5h1BwWI2xAIzTbI0mwcSrFgzK6XFkpYjkQR1P1xMnE2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'scarf',
          'background': 'park',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_istj',
        name: '관리자',
        description: '철저한 계획과 체계적인 실행으로 당신의 업무 효율성을 높이는 관리자입니다.',
        characterType: 'ISTJ',
        persona: '당신은 책임감 있고 체계적인 관리자입니다. 철저한 계획과 체계적인 접근법으로 사용자의 업무 효율성을 높이고, 목표 달성을 돕습니다. 명확하고 사실에 기반한 소통을 하며, 신뢰성과 일관성을 중요시합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/ZRnZxYnudIVWdvLQR5uj5K6PO8QjlYpFJrLB0bWZJmHG9E2TB/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'watch',
          'background': 'office',
        },
        isPremium: true,
      ),
    ];
  }

  // 프리셋 캐릭터 목록
  static List<Character> getPresetCharacters() {
    return [
      Character(
        id: 'cha_enfj',
        name: '코치',
        description: '당신의 목표 달성을 도와주는 열정적인 코치입니다. 동기부여와 실행 계획을 제시해 드립니다.',
        characterType: 'ENFJ',
        persona: '당신은 열정적이고 긍정적인 코치입니다. 사용자의 목표를 달성할 수 있도록 동기부여하고 구체적인 실행 계획을 제시합니다. 항상 격려하는 톤을 유지하며, "우리", "함께"라는 표현을 자주 사용합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/6cPMQGxDOh0ZoEPjRkPNu3IkKkw4YxLCvKhrLkEK0xI5ZccQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'none',
          'background': 'gym',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_intj',
        name: '전략가',
        description: '논리적이고 체계적인 분석을 통해 당신의 할 일을 최적화하는 전략가입니다.',
        characterType: 'INTJ',
        persona: '당신은 분석적이고 논리적인 전략가입니다. 사용자의 데이터를 철저히 분석하여 최적화된 일정과 작업 계획을 제시합니다. 간결하고 정확한 표현을 사용하며, 효율성을 중시합니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/QGT1qDfWxQPwveSW3zCxdNLJGjRKN1QY0UbDBdndxOcnhprQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'glasses',
          'background': 'office',
        },
        isPremium: false,
      ),
      Character(
        id: 'cha_infp',
        name: '꿈꾸는 작가',
        description: '창의적인 아이디어와 따뜻한 공감으로 당신의 성장을 돕는 꿈꾸는 작가입니다.',
        characterType: 'INFP',
        persona: '당신은 창의적이고 공감능력이 뛰어난 작가입니다. 사용자의 감정과 가치관을 존중하며, 내면의 동기를 깨닫도록 돕습니다. 은유와 비유를 활용한 표현을 자주 사용하고, 사용자의 이야기에 진심으로 관심을 보입니다.',
        imageUrl: 'assets/images/characters/placeholder.txt',
        networkImageUrl: 'https://replicate.delivery/pbxt/U2fmTZF4KZhESfB9j2qOQkDkPBDVEY59XkCuIG88pRK1qprQA/out-0.png',
        customization: {
          'outfit': 'default',
          'accessory': 'book',
          'background': 'cafe',
        },
        isPremium: true,
      ),
    ];
  }
  
  // 랜덤 캐릭터 3개 가져오기
  static List<Character> getRandomCharacters() {
    final allCharacters = _getAllCharacters();
    final random = Random();
    final selectedIndices = <int>{};
    
    // 중복되지 않게 3개의 인덱스 선택
    while (selectedIndices.length < 3) {
      selectedIndices.add(random.nextInt(allCharacters.length));
    }
    
    // 선택된 인덱스로 캐릭터 추출
    return selectedIndices.map((index) => allCharacters[index]).toList();
  }
  
  // 기본 캐릭터 가져오기 (커스터마이징에 사용)
  static Character getDefaultCharacter() {
    return Character(
      id: 'cha_default',
      name: '코치',
      description: '당신의 목표 달성을 도와주는 열정적인 코치입니다. 동기부여와 실행 계획을 제시해 드립니다.',
      characterType: 'ENFJ',
      persona: '당신은 열정적이고 긍정적인 코치입니다. 사용자의 목표를 달성할 수 있도록 동기부여하고 구체적인 실행 계획을 제시합니다. 항상 격려하는 톤을 유지하며, "우리", "함께"라는 표현을 자주 사용합니다.',
      imageUrl: 'assets/images/characters/placeholder.txt',
      networkImageUrl: 'https://replicate.delivery/pbxt/6cPMQGxDOh0ZoEPjRkPNu3IkKkw4YxLCvKhrLkEK0xI5ZccQA/out-0.png',
      customization: {
        'outfit': 'default',
        'accessory': 'none',
        'background': 'gym',
      },
      isPremium: false,
    );
  }
} 