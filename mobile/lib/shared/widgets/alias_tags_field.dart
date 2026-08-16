import 'package:flutter/material.dart';

class AliasTagsField extends StatefulWidget {
  final String label;
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const AliasTagsField({
    super.key,
    required this.label,
    required this.onTagsChanged,
    this.initialTags = const [],
  });

  @override
  State<AliasTagsField> createState() => _AliasTagsFieldState();
}

class _AliasTagsFieldState extends State<AliasTagsField> {
  late final TextEditingController _controller;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = List.of(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _controller.clear();
      return;
    }
    setState(() {
      _tags = [..._tags, tag];
      _controller.clear();
    });
    widget.onTagsChanged(List.unmodifiable(_tags));
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((item) => item != tag).toList());
    widget.onTagsChanged(List.unmodifiable(_tags));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addTag(),
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: '输入后点击 + 添加',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: '添加',
              icon: const Icon(Icons.add),
              onPressed: _addTag,
            ),
          ),
        ),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () => _removeTag(tag),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
