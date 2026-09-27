import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/pet_name.dart';
import '../theme/finni_theme.dart';

class NamePicker extends StatefulWidget {
  const NamePicker({
    super.key,
    required this.initial,
    required this.names,
    this.onChanged,
    this.onDone,
    this.buttonLabel,
  });

  final String initial;
  final List<String> names;
  final void Function(String name, bool valid)? onChanged;
  final ValueChanged<String>? onDone;
  final String? buttonLabel;

  @override
  State<NamePicker> createState() => _NamePickerState();
}

class _NamePickerState extends State<NamePicker> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initial);
  final FocusNode focus = FocusNode();
  final math.Random random = math.Random();
  bool touched = false;

  String get name => normalizePetName(controller.text);
  String? get problem => petNameProblem(controller.text);

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  void _set(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _changed();
  }

  void _changed() {
    setState(() => touched = true);
    widget.onChanged?.call(name, problem == null);
  }

  void _surprise() {
    final others = [
      for (final option in widget.names)
        if (option != name) option
    ];
    if (others.isEmpty) return;
    _set(others[random.nextInt(others.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final error = problem;
    final valid = error == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          decoration: BoxDecoration(
            color: FinniColors.paper,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: focus.hasFocus
                  ? FinniColors.primary
                  : valid
                      ? FinniColors.line
                      : FinniColors.purple,
              width: focus.hasFocus ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                  color: FinniColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: FinniColors.mint, shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded,
                    color: FinniColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onFocusChange: (_) => setState(() {}),
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    maxLength: petNameMaxLength,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: FinniColors.ink),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Своё имя',
                      counterText: '',
                      isDense: true,
                    ),
                    onChanged: (_) => _changed(),
                    onSubmitted: (_) {
                      if (problem == null) widget.onDone?.call(name);
                    },
                  ),
                ),
              ),
              Semantics(
                label: 'Букв: ${controller.text.characters.length} из $petNameMaxLength',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${controller.text.characters.length}/$petNameMaxLength',
                    style: const TextStyle(
                        fontSize: 16, color: FinniColors.muted),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Придумай за меня',
                onPressed: _surprise,
                icon: const Text('🎲', style: TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !valid && touched
              ? Container(
                  key: ValueKey(error),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FinniColors.lavender,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: FinniColors.purple),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(error,
                              style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('ok'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FinniColors.mint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Text('👋', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          valid ? 'Привет! Меня зовут $name' : 'Придумай имя',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),
        const Text('Или выбери готовое',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FinniColors.muted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in widget.names)
              ChoiceChip(
                label: Text(option, style: const TextStyle(fontSize: 16)),
                selected: name == option,
                onSelected: (_) => _set(option),
                padding: const EdgeInsets.all(10),
              ),
          ],
        ),
        if (widget.onDone != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: valid ? () => widget.onDone!(name) : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.buttonLabel ?? 'Готово'),
          ),
        ],
      ],
    );
  }
}
