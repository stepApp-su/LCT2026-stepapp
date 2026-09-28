import 'content_json.dart';

enum EventStyle { card, chat, book, pet, swipe, chest }

enum StoryMood { none, sad, ask, happy, calm }

enum StoryVoice { friend, pet, other }

enum FriendKind { bear, bunny }

const Set<String> storyScenes = {
  'school',
  'canteen',
  'dream',
  'morning',
  'table',
  'street',
  'shop',
  'park',
  'home',
  'rain',
};

final class StoryBubble {
  const StoryBubble({required this.voice, required this.text, this.name});

  factory StoryBubble.fromJson(Map<String, Object?> json) => StoryBubble(
        voice: jsonEnum(StoryVoice.values, json['voice'], 'bubbles.voice'),
        text: jsonText(json['text'], 'bubbles.text'),
        name: jsonTextOrNull(json['name'], 'bubbles.name'),
      );

  final StoryVoice voice;
  final String text;
  final String? name;
}

final class StoryStack {
  const StoryStack({required this.amount, required this.label, required this.good});

  factory StoryStack.fromJson(Map<String, Object?> json) => StoryStack(
        amount: jsonInt(json['amount'], 'stacks.amount', min: 0),
        label: jsonText(json['label'], 'stacks.label'),
        good: jsonBool(json['good'] ?? true, 'stacks.good'),
      );

  final int amount;
  final String label;
  final bool good;
}

final class StoryThought {
  const StoryThought({required this.title, required this.stacks, this.note});

  factory StoryThought.fromJson(Map<String, Object?> json) => StoryThought(
        title: jsonText(json['title'], 'thought.title'),
        stacks: List.unmodifiable([
          for (final raw in jsonMaps(json['stacks'] ?? const [], 'thought.stacks'))
            StoryStack.fromJson(raw),
        ]),
        note: jsonTextOrNull(json['note'], 'thought.note'),
      );

  final String title;
  final List<StoryStack> stacks;
  final String? note;
}

final class StoryPage {
  const StoryPage({
    required this.scene,
    required this.narration,
    required this.friendMood,
    required this.bubbles,
    this.petEmote,
    this.prop,
    this.thought,
  });

  factory StoryPage.fromJson(Map<String, Object?> json) {
    final scene = jsonText(json['scene'], 'pages.scene');
    if (!storyScenes.contains(scene)) {
      throw ArgumentError.value(scene, 'pages.scene', 'нет такой сцены');
    }
    final thought = json['thought'];
    return StoryPage(
      scene: scene,
      narration: jsonText(json['narration'], 'pages.narration'),
      friendMood: jsonEnum(
          StoryMood.values, json['friend'] ?? StoryMood.none.name, 'pages.friend'),
      bubbles: List.unmodifiable([
        for (final raw in jsonMaps(json['bubbles'] ?? const [], 'pages.bubbles'))
          StoryBubble.fromJson(raw),
      ]),
      petEmote: jsonTextOrNull(json['petEmote'], 'pages.petEmote'),
      prop: jsonTextOrNull(json['prop'], 'pages.prop'),
      thought: thought == null
          ? null
          : StoryThought.fromJson(jsonMap(thought, 'pages.thought')),
    );
  }

  final String scene;
  final String narration;
  final StoryMood friendMood;
  final List<StoryBubble> bubbles;
  final String? petEmote;
  final String? prop;
  final StoryThought? thought;
}

final class StoryFriend {
  const StoryFriend({required this.name, required this.kind});

  factory StoryFriend.fromJson(Map<String, Object?> json) => StoryFriend(
        name: jsonText(json['name'], 'friend.name'),
        kind: jsonEnum(FriendKind.values, json['kind'], 'friend.kind'),
      );

  final String name;
  final FriendKind kind;
}

final class ChatContact {
  const ChatContact({required this.name, required this.emoji, required this.note});

  factory ChatContact.fromJson(Map<String, Object?> json) => ChatContact(
        name: jsonText(json['name'], 'contact.name'),
        emoji: jsonText(json['emoji'], 'contact.emoji'),
        note: jsonText(json['note'], 'contact.note'),
      );

  final String name;
  final String emoji;
  final String note;
}

final class ChatQuestion {
  const ChatQuestion({required this.label, required this.answers, required this.petNote});

  factory ChatQuestion.fromJson(Map<String, Object?> json) => ChatQuestion(
        label: jsonText(json['label'], 'questions.label'),
        answers: jsonStrings(json['answers'] ?? const [], 'questions.answers'),
        petNote: jsonText(json['petNote'], 'questions.petNote'),
      );

  final String label;
  final List<String> answers;
  final String petNote;
}

final class SwipeCard {
  const SwipeCard(
      {required this.emoji, required this.text, required this.allowed, required this.why});

  factory SwipeCard.fromJson(Map<String, Object?> json) => SwipeCard(
        emoji: jsonText(json['emoji'], 'cards.emoji'),
        text: jsonText(json['text'], 'cards.text'),
        allowed: jsonBool(json['allowed'], 'cards.allowed'),
        why: jsonText(json['why'], 'cards.why'),
      );

  final String emoji;
  final String text;
  final bool allowed;
  final String why;
}

final class EventShow {
  const EventShow._({
    required this.style,
    this.contact,
    this.messages = const [],
    this.petNote,
    this.questions = const [],
    this.friend,
    this.pages = const [],
    this.cards = const [],
    this.yesLabel = 'Можно',
    this.noLabel = 'Нельзя',
    this.rule,
    this.prize,
    this.prizeText,
    this.taps = 3,
    this.scene = 'home',
  });

  static const EventShow card = EventShow._(style: EventStyle.card);

  factory EventShow.fromJson(EventStyle style, Map<String, Object?> json) {
    final contact = json['contact'];
    final friend = json['friend'];
    final scene = jsonTextOrNull(json['scene'], 'show.scene') ?? 'home';
    if (!storyScenes.contains(scene)) {
      throw ArgumentError.value(scene, 'show.scene', 'нет такой сцены');
    }
    final show = EventShow._(
      style: style,
      contact: contact == null
          ? null
          : ChatContact.fromJson(jsonMap(contact, 'show.contact')),
      messages: jsonStrings(json['messages'] ?? const [], 'show.messages'),
      petNote: jsonTextOrNull(json['petNote'], 'show.petNote'),
      questions: List.unmodifiable([
        for (final raw in jsonMaps(json['questions'] ?? const [], 'show.questions'))
          ChatQuestion.fromJson(raw),
      ]),
      friend: friend == null
          ? null
          : StoryFriend.fromJson(jsonMap(friend, 'show.friend')),
      pages: List.unmodifiable([
        for (final raw in jsonMaps(json['pages'] ?? const [], 'show.pages'))
          StoryPage.fromJson(raw),
      ]),
      cards: List.unmodifiable([
        for (final raw in jsonMaps(json['cards'] ?? const [], 'show.cards'))
          SwipeCard.fromJson(raw),
      ]),
      yesLabel: jsonTextOrNull(json['yes'], 'show.yes') ?? 'Можно',
      noLabel: jsonTextOrNull(json['no'], 'show.no') ?? 'Нельзя',
      rule: jsonTextOrNull(json['rule'], 'show.rule'),
      prize: jsonTextOrNull(json['prize'], 'show.prize'),
      prizeText: jsonTextOrNull(json['prizeText'], 'show.prizeText'),
      taps: jsonInt(json['taps'] ?? 3, 'show.taps', min: 1, max: 6),
      scene: scene,
    );
    final problem = switch (style) {
      EventStyle.card => null,
      EventStyle.chat when show.contact == null => 'в переписке нет собеседника',
      EventStyle.chat when show.messages.isEmpty => 'в переписке нет сообщений',
      EventStyle.book when show.pages.isEmpty => 'в книжке нет страниц',
      EventStyle.pet when show.petNote == null => 'питомцу нечего сказать',
      EventStyle.swipe when show.cards.length < 2 => 'нужно хотя бы две карточки',
      EventStyle.chest when show.prize == null || show.prizeText == null =>
        'в сундуке нет награды',
      _ => null,
    };
    if (problem != null) throw ArgumentError.value(style.name, 'show', problem);
    return show;
  }

  final EventStyle style;
  final ChatContact? contact;
  final List<String> messages;
  final String? petNote;
  final List<ChatQuestion> questions;
  final StoryFriend? friend;
  final List<StoryPage> pages;
  final List<SwipeCard> cards;
  final String yesLabel;
  final String noLabel;
  final String? rule;
  final String? prize;
  final String? prizeText;
  final int taps;
  final String scene;
}

final class OptionShow {
  const OptionShow({
    this.reply,
    this.answers = const [],
    this.hint,
    this.petLine,
    this.mood = StoryMood.none,
    this.ending,
    this.lesson,
    this.minScore = 0,
  });

  static const OptionShow none = OptionShow();

  factory OptionShow.fromJson(Map<String, Object?> json) {
    final ending = json['ending'];
    return OptionShow(
      reply: jsonTextOrNull(json['reply'], 'options.show.reply'),
      answers: jsonStrings(json['answers'] ?? const [], 'options.show.answers'),
      hint: jsonTextOrNull(json['hint'], 'options.show.hint'),
      petLine: jsonTextOrNull(json['petLine'], 'options.show.petLine'),
      mood: jsonEnum(
          StoryMood.values, json['mood'] ?? StoryMood.none.name, 'options.show.mood'),
      ending: ending == null
          ? null
          : StoryPage.fromJson(jsonMap(ending, 'options.show.ending')),
      lesson: jsonTextOrNull(json['lesson'], 'options.show.lesson'),
      minScore: jsonInt(json['minScore'] ?? 0, 'options.show.minScore', min: 0),
    );
  }

  final String? reply;
  final List<String> answers;
  final String? hint;
  final String? petLine;
  final StoryMood mood;
  final StoryPage? ending;
  final String? lesson;
  final int minScore;
}

final class Payback {
  const Payback({required this.coins, required this.days, required this.text});

  factory Payback.fromJson(Map<String, Object?> json) => Payback(
        coins: jsonInt(json['coins'], 'payback.coins', min: 1),
        days: jsonInt(json['days'] ?? 1, 'payback.days', min: 1, max: 7),
        text: jsonText(json['text'], 'payback.text'),
      );

  final int coins;
  final int days;
  final String text;
}
