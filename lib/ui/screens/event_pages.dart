part of 'game_shell.dart';

extension _EventPages on _GameShellState {
  void showEvent() {
    final event = s.todayEvent;
    if (event == null || requirePlan()) return;
    s.openEvent();
    if (event.style == EventStyle.card) {
      _cardEvent(event);
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute(
      settings: RouteSettings(name: s.eventHeader),
      builder: (context) => _EventScreen(state: s, event: event),
    ));
  }

  void _cardEvent(GameEventDef event) {
    EventOutcome? outcome;
    sheet(
        s.eventHeader,
        StatefulBuilder(builder: (context, update) {
          final current = outcome;
          final done = current is EventResolved ? current : null;
          final short = current is EventShort ? current : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: PopIn(
                      motion: s.motion,
                      child: EmojiBadge(event.iconId, size: 96))),
              const SizedBox(height: 12),
              GameText(event.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              GameText(event.situation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 16),
              if (done != null) ...[
                _Notice(icon: Icons.check_circle_outline, text: done.text),
                const SizedBox(height: 12),
                if (done.shifts.isNotEmpty) _ShiftList(done.shifts),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: GameText(s.eventText('done'))),
              ] else ...[
                if (event.options.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GameText(s.eventText('chooseHint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FinniColors.muted)),
                  ),
                if (short != null) ...[
                  _Notice(icon: Icons.lightbulb_outline, text: short.text),
                  const SizedBox(height: 12),
                ],
                for (final option in event.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.tonal(
                      onPressed: () {
                        final result = s.resolveEvent(option.id);
                        if (result != null) update(() => outcome = result);
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                      child: Row(
                        children: [
                          Expanded(
                              child: GameText(option.label,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800))),
                          if (option.cost > 0)
                            _Pill(
                                icon: Icons.remove_rounded,
                                label: '${option.cost}',
                                color: FinniColors.lavender)
                          else if (option.coins > 0)
                            _Pill(
                                icon: Icons.add_rounded,
                                label: '${option.coins}',
                                color: FinniColors.mint)
                          else
                            const _Pill(
                                icon: Icons.favorite_border_rounded,
                                label: 'Бесплатно',
                                color: FinniColors.mint),
                        ],
                      ),
                    ),
                  ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: GameText(s.eventText('postpone'))),
              ],
            ],
          );
        }));
  }
}

String _statEmoji(PetStat stat) => switch (stat) {
      PetStat.satiety => '🍎',
      PetStat.care => '🧼',
      PetStat.mood => '😊',
      PetStat.cozy => '🏠',
    };

String _moodEmote(StoryMood mood) => switch (mood) {
      StoryMood.happy => '✨',
      StoryMood.sad => '💧',
      StoryMood.calm => '🙂',
      StoryMood.ask => '❓',
      StoryMood.none => '',
    };

Widget _eventPet(GameController state, [double? progress]) => MoniScene(
      stage: state.stage,
      outfit: state.outfit,
      motion: state.motion,
      equipped: state.equipped,
      celebrationProgress: progress,
    );

class _EventScreen extends StatelessWidget {
  const _EventScreen({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  Widget build(BuildContext context) {
    final body = switch (event.style) {
      EventStyle.chat => _ChatEvent(state: state, event: event),
      EventStyle.book => _BookEvent(state: state, event: event),
      EventStyle.swipe => _SwipeEvent(state: state, event: event),
      EventStyle.chest => _ChestEvent(state: state, event: event),
      EventStyle.pet || EventStyle.card => _PetEvent(state: state, event: event),
    };
    return Scaffold(
      backgroundColor: FinniColors.morning,
      appBar: AppBar(
        backgroundColor: FinniColors.morning,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) * 2.7 + 8,
        leading: IconButton(
            tooltip: 'Назад',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameText(state.eventHeader,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: FinniColors.muted)),
            GameText(event.title, maxLines: 2),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _ReplyButton extends StatelessWidget {
  const _ReplyButton({
    required this.emoji,
    required this.text,
    required this.onTap,
    this.hint,
    this.cost = 0,
    this.coins = 0,
    this.quiet = false,
  });

  final String emoji;
  final String text;
  final VoidCallback onTap;
  final String? hint;
  final int cost;
  final int coins;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: quiet ? FinniColors.lavender : FinniColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: FinniColors.line, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  ExcludeSemantics(
                      child: GameText(emoji, style: const TextStyle(fontSize: 26))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GameText(text,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        if (hint case final small?)
                          GameText(small,
                              style: const TextStyle(
                                  fontSize: 15, color: FinniColors.muted)),
                      ],
                    ),
                  ),
                  if (cost > 0) ...[
                    const SizedBox(width: 8),
                    TagChip('🪙 −$cost', tone: TagTone.purple),
                  ] else if (coins > 0) ...[
                    const SizedBox(width: 8),
                    TagChip('🪙 +$coins', tone: TagTone.green),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.state});

  final GameController state;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
        child: GameText(state.eventText('done')),
      );
}

class _EventOutcomeCard extends StatelessWidget {
  const _EventOutcomeCard({
    required this.state,
    required this.event,
    required this.option,
    this.resolved,
    this.note,
  });

  final GameController state;
  final GameEventDef event;
  final EventOption option;
  final EventResolved? resolved;
  final String? note;

  List<Widget> _tags() {
    final done = resolved;
    if (done == null) {
      return [TagChip(state.eventText('readAgain'))];
    }
    final back = option.payback;
    return [
      if (option.fromSavings)
        TagChip('🐷 −${option.cost}', tone: TagTone.purple)
      else if (option.cost > 0)
        TagChip('🪙 −${option.cost}', tone: TagTone.purple),
      if (option.coins > 0)
        TagChip(option.toSavings ? '🐷 +${option.coins}' : '🪙 +${option.coins}',
            tone: TagTone.green),
      if (back != null)
        TagChip(
            back.days == 1
                ? '🤝 +${back.coins} завтра'
                : '🤝 +${back.coins} через ${back.days} ${ruDays(back.days)}',
            tone: TagTone.gold),
      if (option.careful)
        for (final title in state.content.titles.titles)
          if (title.condition case CarefulCondition(:final count))
            TagChip(
                '🔒 «${title.title}» ${math.min(state.carefulCount, count)} из $count',
                tone: TagTone.gold),
      for (final shift in done.shifts)
        if (shift.delta != 0)
          TagChip(
              '${_statEmoji(shift.stat)} ${shift.label} ${shift.delta > 0 ? '+' : '−'}${shift.delta.abs()}',
              tone: shift.delta > 0 ? TagTone.green : TagTone.peach),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags();
    return PopIn(
      motion: state.motion,
      child: _Panel(
        padding: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: FinniColors.honey, borderRadius: BorderRadius.circular(16)),
              child: ExcludeSemantics(
                  child: GameText(option.emoji ?? '✨', style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GameText(state.eventLine(option.show.lesson ?? event.title),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  GameText(resolved?.text ?? state.eventLine(option.resultText),
                      style: const TextStyle(fontSize: 16, height: 1.35)),
                  if (note case final rule?) ...[
                    const SizedBox(height: 6),
                    GameText('💡 ${state.eventLine(rule)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: tags),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _From { them, me, pet }

class _ChatLine {
  const _ChatLine(this.from, this.text, {this.typing = false});

  final _From from;
  final String text;
  final bool typing;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.line, required this.state});

  final _ChatLine line;
  final GameController state;

  @override
  Widget build(BuildContext context) {
    final mine = line.from == _From.me;
    final pet = line.from == _From.pet;
    final color = switch (line.from) {
      _From.me => FinniColors.primary,
      _From.pet => FinniColors.honey,
      _From.them => FinniColors.paper,
    };
    final ink = mine ? FinniColors.paper : FinniColors.ink;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
        boxShadow: const [
          BoxShadow(color: FinniColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: line.typing
          ? GameText(state.eventText('typing'),
              style: const TextStyle(
                  fontSize: 16, fontStyle: FontStyle.italic, color: FinniColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pet)
                  GameText(state.petName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: FinniColors.gold)),
                GameText(line.text,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: ink, height: 1.3)),
              ],
            ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: PopIn(motion: state.motion, child: bubble),
      ),
    );
  }
}

class _ChatEvent extends StatefulWidget {
  const _ChatEvent({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  State<_ChatEvent> createState() => _ChatEventState();
}

class _ChatEventState extends State<_ChatEvent> {
  final lines = <_ChatLine>[];
  final asked = <int>{};
  final scroll = ScrollController();
  bool talking = true;
  EventOption? chosen;
  EventResolved? done;
  EventShort? short;

  GameController get s => widget.state;
  EventShow get show => widget.event.show;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  bool get _animate => mounted && motionAllowed(context, s.motion);

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        unawaited(scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut));
      });

  Future<void> _say(_From from, String text) async {
    if (!mounted) return;
    if (from == _From.them && _animate) {
      setState(() => lines.add(_ChatLine(from, '', typing: true)));
      _toEnd();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => lines[lines.length - 1] = _ChatLine(from, text));
      s.fx('bubble');
    } else {
      if (_animate) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      setState(() => lines.add(_ChatLine(from, text)));
      s.fx('bubble');
    }
    _toEnd();
  }

  void _settle() {
    if (!mounted) return;
    setState(() => talking = false);
    _toEnd();
  }

  Future<void> _start() async {
    for (final message in show.messages) {
      await _say(_From.them, s.eventLine(message));
    }
    if (show.petNote case final note?) {
      await _say(_From.pet, s.eventLine(note));
    }
    _settle();
  }

  Future<void> _ask(int index) async {
    final question = show.questions[index];
    setState(() {
      talking = true;
      short = null;
      asked.add(index);
    });
    await _say(_From.me, s.eventLine(question.label));
    for (final answer in question.answers) {
      await _say(_From.them, s.eventLine(answer));
    }
    await _say(_From.pet, s.eventLine(question.petNote));
    _settle();
  }

  Future<void> _pick(EventOption option) async {
    final outcome = s.resolveEvent(option.id);
    if (outcome is EventShort) {
      setState(() => short = outcome);
      _toEnd();
      return;
    }
    if (outcome is! EventResolved) return;
    setState(() {
      talking = true;
      short = null;
      chosen = option;
    });
    await _say(_From.me, s.eventLine(option.show.reply ?? option.label));
    for (final answer in option.show.answers) {
      await _say(_From.them, s.eventLine(answer));
    }
    await _say(_From.pet, s.eventLine(option.show.petLine ?? outcome.text));
    if (!mounted) return;
    setState(() {
      done = outcome;
      talking = false;
    });
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    final contact = show.contact!;
    final replies = !talking && done == null;
    final picked = chosen;
    final result = done;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Panel(
          padding: 12,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: FinniColors.sky, shape: BoxShape.circle),
                child: ExcludeSemantics(
                    child: GameText(contact.emoji, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameText(s.eventLine(contact.name),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    TagChip('⚠️ ${s.eventLine(contact.note)}', tone: TagTone.peach),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final line in lines) _ChatBubble(line: line, state: s),
        if (replies) ...[
          const SizedBox(height: 6),
          GameText(s.eventText('yourMove'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: FinniColors.muted)),
          const SizedBox(height: 8),
          if (short case final gap?) ...[
            _Notice(icon: Icons.lightbulb_outline, text: gap.text),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < show.questions.length; i++)
            if (!asked.contains(i))
              _ReplyButton(
                emoji: '🤔',
                text: s.eventLine(show.questions[i].label),
                quiet: true,
                onTap: () => unawaited(_ask(i)),
              ),
          for (final option in widget.event.options)
            _ReplyButton(
              emoji: option.emoji ?? '💬',
              text: s.eventLine(option.label),
              cost: option.cost,
              coins: option.coins,
              onTap: () => unawaited(_pick(option)),
            ),
        ],
        if (result != null && picked != null) ...[
          const SizedBox(height: 10),
          _EventOutcomeCard(state: s, event: widget.event, option: picked, resolved: result),
          const SizedBox(height: 12),
          _DoneButton(state: s),
        ],
      ],
    );
  }
}

class _BookPage extends StatelessWidget {
  const _BookPage({
    super.key,
    required this.state,
    required this.event,
    required this.page,
    required this.number,
    required this.total,
    required this.hint,
  });

  final GameController state;
  final GameEventDef event;
  final StoryPage page;
  final int number;
  final int total;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      topLeft: Radius.circular(10),
      bottomLeft: Radius.circular(10),
      topRight: Radius.circular(24),
      bottomRight: Radius.circular(24),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FinniColors.storyPaper,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: FinniColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
          BoxShadow(color: FinniColors.storyEdge, offset: Offset(4, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StoryStage(
              page: page,
              pet: _eventPet(state),
              petName: state.petName,
              friend: event.show.friend,
              fill: state.eventLine,
            ),
            Container(height: 2, color: FinniColors.storyDash),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GameText(state.eventLine(page.narration),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, height: 1.38)),
                  ),
                  const SizedBox(width: 8),
                  GameText('$number/$total',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: FinniColors.storyPageNo)),
                ],
              ),
            ),
            if (hint)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: GameText('нажми ›',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: FinniColors.primary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookEvent extends StatefulWidget {
  const _BookEvent({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  State<_BookEvent> createState() => _BookEventState();
}

class _BookEventState extends State<_BookEvent> {
  int index = 0;
  bool forward = true;
  EventOption? ending;
  EventOption? first;
  EventResolved? done;
  EventShort? short;

  GameController get s => widget.state;
  List<StoryPage> get pages => widget.event.show.pages;
  bool get asking => ending == null && index == pages.length - 1;
  int get total => pages.length + 1;

  void _next() {
    if (ending != null || index >= pages.length - 1) return;
    setState(() {
      index++;
      forward = true;
    });
    s.fx('page_turn');
  }

  void _back() {
    if (ending != null || index == 0) return;
    setState(() {
      index--;
      forward = false;
    });
    s.fx('page_turn');
  }

  void _pick(EventOption option) {
    if (first != null) {
      setState(() {
        ending = option;
        forward = true;
      });
      return;
    }
    final outcome = s.resolveEvent(option.id);
    if (outcome is EventShort) {
      setState(() => short = outcome);
      return;
    }
    if (outcome is! EventResolved) return;
    setState(() {
      first = option;
      done = outcome;
      ending = option;
      short = null;
      forward = true;
    });
  }

  void _other() => setState(() {
        ending = null;
        index = pages.length - 1;
        forward = false;
      });

  Widget _turn(Widget child, Animation<double> animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY((1 - t) * (forward ? -.9 : .9)),
              child: child,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final shown = ending;
    final page = shown?.show.ending ?? pages[index];
    final number = shown != null ? total : index + 1;
    final view = _BookPage(
      key: ValueKey('${shown?.id ?? 'page'}-$index'),
      state: s,
      event: widget.event,
      page: page,
      number: number,
      total: total,
      hint: shown == null && !asking,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 24),
      children: [
        Semantics(
          label: 'Страница $number из $total',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: motionAllowed(context, s.motion)
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: _turn,
                    child: view)
                : view,
          ),
        ),
        const SizedBox(height: 14),
        if (shown != null) ...[
          _EventOutcomeCard(
            state: s,
            event: widget.event,
            option: shown,
            resolved: shown == first ? done : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.event.options.length > 1) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _other,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: GameText(s.eventText('other'), textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: _DoneButton(state: s)),
            ],
          ),
        ] else if (asking) ...[
          GameText(s.eventText('askPet', {'pet': s.petName}),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (short case final gap?) ...[
            _Notice(icon: Icons.lightbulb_outline, text: gap.text),
            const SizedBox(height: 8),
          ],
          for (final option in widget.event.options)
            _ReplyButton(
              emoji: option.emoji ?? '💬',
              text: '«${s.eventLine(option.show.reply ?? option.label)}»',
              hint: option == first ? 'твой выбор' : null,
              cost: first == null ? option.cost : 0,
              coins: first == null ? option.coins : 0,
              onTap: () => _pick(option),
            ),
          if (index > 0)
            TextButton(onPressed: _back, child: const GameText('‹ Назад')),
        ] else
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Назад',
                onPressed: index == 0 ? null : _back,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++)
                      Expanded(
                        child: Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= index ? FinniColors.primary : FinniColors.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _next,
                child: GameText('${s.eventText('next')} ›'),
              ),
            ],
          ),
      ],
    );
  }
}

class _PetReaction extends StatelessWidget {
  const _PetReaction({super.key, required this.state, required this.mood});

  final GameController state;
  final StoryMood mood;

  @override
  Widget build(BuildContext context) {
    if (!motionAllowed(context, state.motion) ||
        mood == StoryMood.ask ||
        mood == StoryMood.none) {
      return _eventPet(state);
    }
    final happy = mood == StoryMood.happy;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: happy ? 1400 : 700),
      builder: (context, t, _) => happy
          ? _eventPet(state, t)
          : Transform.translate(
              offset: Offset(math.sin(t * math.pi * 6) * 8 * (1 - t), 0),
              child: _eventPet(state)),
    );
  }
}

class _PetEvent extends StatefulWidget {
  const _PetEvent({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  State<_PetEvent> createState() => _PetEventState();
}

class _PetEventState extends State<_PetEvent> {
  EventOption? chosen;
  EventResolved? done;
  EventShort? short;

  GameController get s => widget.state;

  void _pick(EventOption option) {
    final outcome = s.resolveEvent(option.id);
    if (outcome is EventShort) {
      setState(() => short = outcome);
      return;
    }
    if (outcome is! EventResolved) return;
    setState(() {
      chosen = option;
      done = outcome;
      short = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.event.show;
    final picked = chosen;
    final result = done;
    final line = picked == null
        ? show.petNote ?? widget.event.situation
        : picked.show.petLine ?? result?.text ?? picked.resultText;
    final mood = picked?.show.mood ?? StoryMood.ask;
    final emote = _moodEmote(mood);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: AspectRatio(
            aspectRatio: storyWidth / storyHeight,
            child: LayoutBuilder(builder: (context, box) {
              final k = box.maxWidth / storyWidth;
              return Stack(
                children: [
                  Positioned.fill(child: SceneArt(show.scene)),
                  Positioned(
                    left: (storyWidth - 160) / 2 * k,
                    bottom: 0,
                    width: 160 * k,
                    height: 172 * k,
                    child: IgnorePointer(
                        child: _PetReaction(
                            key: ValueKey(picked?.id ?? 'ask'), state: s, mood: mood)),
                  ),
                  if (emote.isNotEmpty)
                    Positioned(
                      right: 62 * k,
                      bottom: 150 * k,
                      child: PopIn(
                        key: ValueKey('emote-${picked?.id}'),
                        motion: s.motion,
                        child: GameText(emote, style: TextStyle(fontSize: 34 * k, height: 1)),
                      ),
                    ),
                  Positioned(
                    left: 12 * k,
                    right: 12 * k,
                    top: 10 * k,
                    child: PopIn(
                      key: ValueKey('line-${picked?.id}'),
                      motion: s.motion,
                      child: StoryBubbleView(text: s.eventLine(line), name: s.petName),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        if (result != null && picked != null) ...[
          _EventOutcomeCard(state: s, event: widget.event, option: picked, resolved: result),
          const SizedBox(height: 12),
          _DoneButton(state: s),
        ] else ...[
          GameText(s.eventText('advice'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (short case final gap?) ...[
            _Notice(icon: Icons.lightbulb_outline, text: gap.text),
            const SizedBox(height: 8),
          ],
          for (final option in widget.event.options)
            _ReplyButton(
              emoji: option.emoji ?? '💬',
              text: s.eventLine(option.label),
              hint: option.show.hint == null ? null : s.eventLine(option.show.hint!),
              cost: option.fromSavings ? 0 : option.cost,
              coins: option.coins,
              onTap: () => _pick(option),
            ),
        ],
      ],
    );
  }
}

class _SwipeCardView extends StatelessWidget {
  const _SwipeCardView({required this.card, this.stamp, this.stampYes = true});

  final SwipeCard card;
  final String? stamp;
  final bool stampYes;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 270,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FinniColors.paper,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: FinniColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                      child: GameText(card.emoji, style: const TextStyle(fontSize: 64))),
                  const SizedBox(height: 12),
                  GameText(card.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, height: 1.25)),
                ],
              ),
            ),
            if (stamp case final word?)
              Positioned(
                top: 0,
                left: stampYes ? 0 : null,
                right: stampYes ? null : 0,
                child: Transform.rotate(
                  angle: stampYes ? -.2 : .2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: stampYes ? FinniColors.primary : FinniColors.alert,
                          width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: GameText(word.toUpperCase(),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: stampYes ? FinniColors.primary : FinniColors.alert)),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _SwipeEvent extends StatefulWidget {
  const _SwipeEvent({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  State<_SwipeEvent> createState() => _SwipeEventState();
}

class _SwipeEventState extends State<_SwipeEvent> {
  int index = 0;
  int score = 0;
  double dx = 0;
  SwipeCard? last;
  bool lastRight = false;
  EventOption? result;
  EventResolved? done;

  GameController get s => widget.state;
  EventShow get show => widget.event.show;
  List<SwipeCard> get cards => show.cards;

  void _answer(bool allowed) {
    if (index >= cards.length) return;
    final card = cards[index];
    final right = card.allowed == allowed;
    s.fx(right ? 'round_win' : 'miss');
    setState(() {
      if (right) score++;
      last = card;
      lastRight = right;
      index++;
      dx = 0;
    });
    if (index >= cards.length) _finish();
  }

  void _finish() {
    final option = widget.event.optionForScore(score);
    final outcome = s.resolveEvent(option.id);
    if (outcome is EventResolved) {
      setState(() {
        result = option;
        done = outcome;
      });
    }
  }

  void _release() {
    if (dx.abs() > 90) {
      _answer(dx > 0);
    } else {
      setState(() => dx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = cards.length;
    final left = index < total;
    final shown = last;
    final option = result;
    final outcome = done;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            TagChip('${math.min(index + 1, total)} из $total'),
            const Spacer(),
            TagChip(
                s.eventText('score', {'score': '$score', 'total': '$total'}),
                tone: TagTone.green),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 290,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (index + 1 < total)
                Transform.translate(
                  offset: const Offset(0, 12),
                  child: Transform.scale(
                      scale: .93, child: _SwipeCardView(card: cards[index + 1])),
                ),
              if (left)
                Semantics(
                  label: cards[index].text,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => setState(() => dx += d.delta.dx),
                    onHorizontalDragEnd: (_) => _release(),
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.rotate(
                        angle: dx / 900,
                        child: _SwipeCardView(
                          card: cards[index],
                          stamp: dx > 30
                              ? show.yesLabel
                              : dx < -30
                                  ? show.noLabel
                                  : null,
                          stampYes: dx > 0,
                        ),
                      ),
                    ),
                  ),
                )
              else
                PopIn(
                  motion: s.motion,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameText(score == total ? '🏆' : '🌟',
                          style: const TextStyle(fontSize: 80)),
                      const SizedBox(height: 8),
                      GameText(s.eventText('score', {'score': '$score', 'total': '$total'}),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (shown != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PopIn(
              key: ValueKey(index),
              motion: s.motion,
              child: _Panel(
                padding: 12,
                color: lastRight ? FinniColors.mint : FinniColors.peach,
                child: GameText(
                    '${lastRight ? '✅ Верно!' : '❌ Не совсем.'} ${s.eventLine(shown.why)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        if (left) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: GameText('✋ ${show.noLabel}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _answer(true),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: GameText('👍 ${show.yesLabel}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GameText(s.eventText('swipeHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: FinniColors.muted)),
        ],
        if (option != null && outcome != null) ...[
          _EventOutcomeCard(
              state: s,
              event: widget.event,
              option: option,
              resolved: outcome,
              note: show.rule),
          const SizedBox(height: 12),
          _DoneButton(state: s),
        ],
      ],
    );
  }
}

class _Shake extends StatelessWidget {
  const _Shake({super.key, required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      child: child,
      builder: (context, t, child) => Transform.rotate(
        angle: math.sin(t * math.pi * 4) * .14 * (1 - t),
        child: child,
      ),
    );
  }
}

class _CoinBurst extends StatelessWidget {
  const _CoinBurst();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 8; i++)
                Transform.translate(
                  offset: Offset(math.cos(i * math.pi / 4) * 120 * t,
                      math.sin(i * math.pi / 4) * 90 * t - 30 * t),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: const GameText('🪙', style: TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _ChestEvent extends StatefulWidget {
  const _ChestEvent({required this.state, required this.event});

  final GameController state;
  final GameEventDef event;

  @override
  State<_ChestEvent> createState() => _ChestEventState();
}

class _ChestEventState extends State<_ChestEvent> {
  int hits = 0;
  EventOption? chosen;
  EventResolved? done;
  EventShort? short;

  GameController get s => widget.state;
  EventShow get show => widget.event.show;
  bool get open => hits >= show.taps;

  void _knock() {
    if (open) return;
    setState(() => hits++);
    s.fx(open ? 'coin' : 'knock');
  }

  void _pick(EventOption option) {
    final outcome = s.resolveEvent(option.id);
    if (outcome is EventShort) {
      setState(() => short = outcome);
      return;
    }
    if (outcome is! EventResolved) return;
    setState(() {
      chosen = option;
      done = outcome;
      short = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = motionAllowed(context, s.motion);
    final options = [
      for (final option in widget.event.options)
        if (!option.toSavings || s.goalView != null) option,
    ];
    final picked = chosen;
    final result = done;
    final tapText = s.eventText('tapChest', {'taps': '${show.taps}'});
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [FinniColors.honey, FinniColors.morning],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!open)
                Semantics(
                  button: true,
                  label: tapText,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _knock,
                    child: _Shake(
                      key: ValueKey(hits),
                      active: motion && hits > 0,
                      child: const GameText('🧰', style: TextStyle(fontSize: 120)),
                    ),
                  ),
                )
              else ...[
                if (motion) const _CoinBurst(),
                PopIn(
                  motion: s.motion,
                  child: GameText(show.prize!, style: const TextStyle(fontSize: 110)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!open) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < show.taps; i++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < hits ? FinniColors.gold : FinniColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GameText(tapText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextButton(onPressed: _knock, child: const GameText('Постучать')),
        ] else ...[
          PopIn(
            motion: s.motion,
            child: GameText(s.eventLine(show.prizeText!),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.3)),
          ),
          const SizedBox(height: 14),
          if (result != null && picked != null) ...[
            _EventOutcomeCard(state: s, event: widget.event, option: picked, resolved: result),
            const SizedBox(height: 12),
            _DoneButton(state: s),
          ] else ...[
            if (short case final gap?) ...[
              _Notice(icon: Icons.lightbulb_outline, text: gap.text),
              const SizedBox(height: 8),
            ],
            for (final option in options)
              _ReplyButton(
                emoji: option.emoji ?? '✨',
                text: s.eventLine(option.label),
                hint: option.show.hint == null ? null : s.eventLine(option.show.hint!),
                coins: option.toSavings ? 0 : option.coins,
                onTap: () => _pick(option),
              ),
          ],
        ],
      ],
    );
  }
}
