import 'package:flutter/material.dart';
import 'package:dx_project/data/character.dart';
import 'package:dx_project/pages/chat_page.dart';
import 'package:dx_project/pages/character_customization_page.dart';
import 'package:flutter/services.dart';

class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({super.key});

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  late List<Character> _characters;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    // Simulate loading characters
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _characters = Character.getRandomCharacters();
      _isLoading = false;
    });
  }

  void _navigateToChat(Character character) {
    _showCharacterNameDialog(character);
  }

  void _showCharacterNameDialog(Character character) {
    final TextEditingController nameController = TextEditingController(text: character.name);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('캐릭터 이름 설정', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(character.imageUrl),
                backgroundColor: const Color(0xFFF36D9D).withOpacity(0.1),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '캐릭터 이름',
                  hintText: '원하는 이름을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF36D9D), width: 2),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  final updatedCharacter = character.copyWith(name: newName);
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(character: updatedCharacter),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF36D9D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('대화 시작', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CharacterCustomizationPage(),
      ),
    ).then((newCharacter) {
      if (newCharacter != null && newCharacter is Character) {
        setState(() {
          _characters.insert(0, newCharacter);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 캐릭터 선택', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF36D9D)))
          : _buildCharacterGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCustomization,
        label: const Text('나만의 캐릭터 만들기'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFF36D9D),
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCharacterGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.7,
      ),
      itemCount: _characters.length,
      itemBuilder: (context, index) {
        final character = _characters[index];
        return _buildCharacterCard(character);
      },
    );
  }

  Widget _buildCharacterCard(Character character) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () => _navigateToChat(character),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFFDEEF4),
                child: Image.network(
                  character.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    return progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator(color: Color(0xFFF36D9D), strokeWidth: 2.0));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person, size: 80, color: Colors.grey.shade400);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ElevatedButton(
                onPressed: () => _navigateToChat(character),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF36D9D).withOpacity(0.15),
                  foregroundColor: const Color(0xFFF36D9D),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('선택하기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
} 