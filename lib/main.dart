import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const PlotterApp());
}

class PlotterApp extends StatelessWidget {
  const PlotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plotter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NovelEditor(),
    );
  }
}

class Section {
  final String name;
  final double start;
  final double end;
  final String purpose;
  const Section(this.name, this.start, this.end, this.purpose);
}

const sections = <Section>[
  Section('Setup', 0.0, 0.12,
      'Readers learn about your characters, their goals, and the stakes.'),
  Section('Buildup', 0.12, 0.25,
      'The final pieces necessary for the main conflict are moved into position, while ramping up the tension'),
  Section('Reaction', 0.25, 0.37,
      'The protagonist scrambles to understand the obstacles thrown in their way by the antagonist'),
  Section('Realization', 0.37, 0.50,
      "The protagonist's understanding of the conflict grows and their reactions become more informed"),
  Section('Action', 0.50, 0.62,
      'With their new understanding, the protagonist makes headway against the antagonist'),
  Section('Renewed push', 0.62, 0.75,
      'The protagonist renews their attack upon the antagonist, seeming to reach a victory'),
  Section('Recovery', 0.75, 0.88,
      'The protagonist reels as they question their choices, their commitment to the goal, and their own worthiness and ability.'),
  Section('Confrontation', 0.88, 0.98,
      'The protagonist and antagonist duel to the death, so that they cannot both walk away.'),
  Section('Resolution', 0.98, 1.0,
      'Ease the readers out of the excitement and into the final emotion.'),
];

class Scene {
  String id;
  String title;
  String text;
  int wordCount;
  Scene({
    required this.id,
    this.title = '',
    this.text = '',
    this.wordCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'wordCount': wordCount,
      };

  static Scene fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        wordCount: json['wordCount'] as int? ?? 0,
      );
}

class Novel {
  int totalWordCount;
  List<Scene> scenes;
  Novel({this.totalWordCount = 50000, List<Scene>? scenes})
      : scenes = scenes ?? [];

  Map<String, dynamic> toJson() => {
        'totalWordCount': totalWordCount,
        'scenes': scenes.map((s) => s.toJson()).toList(),
      };

  static Novel fromJson(Map<String, dynamic> json) => Novel(
        totalWordCount: json['totalWordCount'] as int? ?? 50000,
        scenes: (json['scenes'] as List<dynamic>? ?? [])
            .map((e) => Scene.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class NovelStorage {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/novel_plot.json');
  }

  Future<Novel> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final content = await f.readAsString();
        return Novel.fromJson(jsonDecode(content) as Map<String, dynamic>);
      }
    } catch (_) {}
    return Novel();
  }

  Future<void> save(Novel novel) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(novel.toJson()));
  }
}

class NovelEditor extends StatefulWidget {
  const NovelEditor({super.key});

  @override
  State<NovelEditor> createState() => _NovelEditorState();
}

class _Item {
  final Scene? scene;
  final Section? section;
  final String id;
  _Item.scene(this.scene)
      : section = null,
        id = scene!.id;
  _Item.section(this.section)
      : scene = null,
        id = 'section-${section!.name}';
  bool get isSection => section != null;
}

class _NovelEditorState extends State<NovelEditor> {
  final storage = NovelStorage();
  Novel? novel;

  @override
  void initState() {
    super.initState();
    storage.load().then((value) => setState(() => novel = value));
  }

  Section _sectionForIndex(int index) {
    int cum = 0;
    for (int i = 0; i < index; i++) {
      cum += novel!.scenes[i].wordCount;
    }
    double pct = novel!.totalWordCount == 0
        ? 0
        : cum / novel!.totalWordCount;
    return sections.firstWhere(
      (s) => pct >= s.start && pct < s.end,
      orElse: () => sections.last,
    );
  }

  List<_Item> _buildItems() {
    final items = <_Item>[];
    int cum = 0;
    Section? last;
    for (int i = 0; i < novel!.scenes.length; i++) {
      final scene = novel!.scenes[i];
      final pct = novel!.totalWordCount == 0
          ? 0
          : cum / novel!.totalWordCount;
      final section = sections.firstWhere(
          (s) => pct >= s.start && pct < s.end,
          orElse: () => sections.last);
      if (section != last) {
        items.add(_Item.section(section));
        last = section;
      }
      items.add(_Item.scene(scene));
      cum += scene.wordCount;
    }
    return items;
  }

  int _sceneIndexForItemIndex(int itemIndex, List<_Item> items) {
    int sceneIdx = -1;
    for (int i = 0; i < items.length; i++) {
      if (!items[i].isSection) {
        sceneIdx++;
      }
      if (i == itemIndex) {
        return sceneIdx;
      }
    }
    return sceneIdx;
  }

  void _save() {
    storage.save(novel!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (novel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = _buildItems();
    return Scaffold(
      appBar: AppBar(
        title: Text('Plotter (total ${novel!.totalWordCount} words)'),
        actions: [
          IconButton(
              onPressed: () async {
                final controller = TextEditingController(
                    text: novel!.totalWordCount.toString());
                final res = await showDialog<int>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Total word count'),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(
                                  context, int.tryParse(controller.text)),
                              child: const Text('OK')),
                        ],
                      );
                    });
                if (res != null) {
                  novel!.totalWordCount = res;
                  _save();
                }
              },
              icon: const Icon(Icons.numbers))
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          if (items[newIndex.clamp(0, items.length - 1)].isSection) {
            newIndex += newIndex > oldIndex ? 1 : -1;
          }
          final scenes = novel!.scenes;
          final oldSceneIndex =
              _sceneIndexForItemIndex(oldIndex, items);
          final newSceneIndex =
              _sceneIndexForItemIndex(newIndex, items);
          if (oldSceneIndex < 0 || newSceneIndex < 0) return;
          final scene = scenes.removeAt(oldSceneIndex);
          scenes.insert(newSceneIndex, scene);
          _save();
        },
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.isSection) {
            return ListTile(
              key: ValueKey(item.id),
              title: Text(item.section!.name),
              subtitle: Text(item.section!.purpose),
            );
          }
          final scene = item.scene!;
          final section = _sectionForIndex(novel!.scenes.indexOf(scene));
          return ListTile(
            key: ValueKey(item.id),
            title: Text(scene.title.isEmpty ? 'Untitled scene' : scene.title),
            subtitle: Text(
                '${scene.wordCount} words – ${section.name}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                novel!.scenes.remove(scene);
                _save();
              },
            ),
            onTap: () async {
              final titleController =
                  TextEditingController(text: scene.title);
              final wordsController = TextEditingController(
                  text: scene.wordCount.toString());
              final textController = TextEditingController(text: scene.text);
              final res = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Edit scene'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration:
                                  const InputDecoration(labelText: 'Title'),
                            ),
                            TextField(
                              controller: wordsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Word count'),
                            ),
                            TextField(
                              controller: textController,
                              decoration:
                                  const InputDecoration(labelText: 'Text'),
                              maxLines: 5,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Save')),
                      ],
                    );
                  });
              if (res == true) {
                scene.title = titleController.text;
                scene.wordCount = int.tryParse(wordsController.text) ?? 0;
                scene.text = textController.text;
                _save();
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          novel!.scenes.add(Scene(
              id: DateTime.now().millisecondsSinceEpoch.toString()));
          _save();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
