import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterItem {
  final String id;
  final String name;
  final String description;
  final String type; // 'outfit', 'accessory', 'background' 등
  final String imageUrl; // 아이템 이미지 URL
  final int price; // 아이템 가격
  final bool isPremium; // 프리미엄 아이템 여부
  final List<String> compatibleCharacters; // 호환되는 캐릭터 ID 목록

  CharacterItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.price,
    this.isPremium = false,
    required this.compatibleCharacters,
  });

  CharacterItem copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    String? imageUrl,
    int? price,
    bool? isPremium,
    List<String>? compatibleCharacters,
  }) {
    return CharacterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      isPremium: isPremium ?? this.isPremium,
      compatibleCharacters: compatibleCharacters ?? this.compatibleCharacters,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'imageUrl': imageUrl,
      'price': price,
      'isPremium': isPremium,
      'compatibleCharacters': compatibleCharacters,
    };
  }

  factory CharacterItem.fromMap(Map<String, dynamic> map, String docId) {
    return CharacterItem(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      price: map['price'] ?? 0,
      isPremium: map['isPremium'] ?? false,
      compatibleCharacters: List<String>.from(map['compatibleCharacters'] ?? []),
    );
  }

  // 샘플 아이템 목록
  static List<CharacterItem> getSampleItems() {
    return [
      // 의상 아이템
      CharacterItem(
        id: 'item_outfit_business',
        name: '비즈니스 정장',
        description: '전문적인 분위기의 비즈니스 정장입니다.',
        type: 'outfit',
        imageUrl: 'assets/images/items/outfit_business.png',
        price: 200,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj'],
      ),
      CharacterItem(
        id: 'item_outfit_casual',
        name: '캐주얼 의상',
        description: '편안하고 자연스러운 캐주얼 의상입니다.',
        type: 'outfit',
        imageUrl: 'assets/images/items/outfit_casual.png',
        price: 150,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj', 'cha_infp'],
      ),
      CharacterItem(
        id: 'item_outfit_artistic',
        name: '예술가 의상',
        description: '창의적인 느낌의 예술가 의상입니다.',
        type: 'outfit',
        imageUrl: 'assets/images/items/outfit_artistic.png',
        price: 300,
        isPremium: true,
        compatibleCharacters: ['cha_infp'],
      ),

      // 악세서리 아이템
      CharacterItem(
        id: 'item_accessory_glasses',
        name: '안경',
        description: '지적인 분위기의 안경입니다.',
        type: 'accessory',
        imageUrl: 'assets/images/items/accessory_glasses.png',
        price: 100,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj', 'cha_infp'],
      ),
      CharacterItem(
        id: 'item_accessory_watch',
        name: '시계',
        description: '세련된 디자인의 손목시계입니다.',
        type: 'accessory',
        imageUrl: 'assets/images/items/accessory_watch.png',
        price: 150,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj'],
      ),
      CharacterItem(
        id: 'item_accessory_notebook',
        name: '노트북',
        description: '아이디어를 기록하는 노트북입니다.',
        type: 'accessory',
        imageUrl: 'assets/images/items/accessory_notebook.png',
        price: 250,
        isPremium: true,
        compatibleCharacters: ['cha_infp', 'cha_intj'],
      ),

      // 배경 아이템
      CharacterItem(
        id: 'item_background_office',
        name: '사무실',
        description: '깔끔한 사무실 배경입니다.',
        type: 'background',
        imageUrl: 'assets/images/items/background_office.png',
        price: 200,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj'],
      ),
      CharacterItem(
        id: 'item_background_cafe',
        name: '카페',
        description: '아늑한 카페 배경입니다.',
        type: 'background',
        imageUrl: 'assets/images/items/background_cafe.png',
        price: 200,
        isPremium: false,
        compatibleCharacters: ['cha_enfj', 'cha_intj', 'cha_infp'],
      ),
      CharacterItem(
        id: 'item_background_nature',
        name: '자연',
        description: '평화로운 자연 배경입니다.',
        type: 'background',
        imageUrl: 'assets/images/items/background_nature.png',
        price: 300,
        isPremium: true,
        compatibleCharacters: ['cha_enfj', 'cha_infp'],
      ),
    ];
  }
} 