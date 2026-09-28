import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/finni_theme.dart';
import 'game_icon.dart';
import 'moni_scene.dart';
import 'sprite_sheet.dart';
import 'room_backdrop.dart';

const Map<String, (String, int)> _sprites = {
  'food': ('props', 0),
  'icon_shop_food': ('props', 0),
  'water_light': ('props', 1),
  'icon_shop_water_light': ('props', 1),
  'bouncy_ball': ('props', 2),
  'cleaning': ('props', 4),
  'rug': ('props', 11),
  'bow': ('accessories', 0),
  'cap': ('accessories', 1),
  'glasses': ('accessories', 2),
  'scarf': ('accessories', 3),
  'bowtie': ('accessories', 4),
  'tshirt': ('accessories', 5),
  'raincoat': ('accessories', 6),
  'backpack': ('accessories', 7),
  'balloon': ('accessories', 8),
};

const Map<String, GameIconKind> _icons = {
  'scooter': GameIconKind.scooter,
};

const Map<String, String> kEmoji = {
  'treat': '🍪',
  'porridge': '🥣',
  'lunchbox': '🍱',
  'toothbrush': '🪥',
  'laundry': '🧺',
  'warm_socks': '🧦',
  'mittens': '🧤',
  'warm_jacket': '🧥',
  'honey_tea': '🍯',
  'vitamins': '💊',
  'notebook': '📓',
  'pencils': '✏️',
  'book': '📖',
  'apple': '🍎',
  'puzzle': '🧩',
  'flower_pot': '🌷',
  'cactus': '🌵',
  'poster': '🖼️',
  'clock': '⏰',
  'shelf': '📚',
  'pouf': '🛋️',
  'palm': '🌴',
  'table': '🪑',
  'bed': '🛏️',
  'night_light': '🌟',
  'aquarium': '🐠',
  'wp_plain': '🤍',
  'wp_clouds': '☁️',
  'wp_leaves': '🍃',
  'wp_stars': '⭐',
  'wp_space': '🪐',
  'constructor': '🧱',
  'slime_kit': '🫧',
  'giant_plush': '🧸',
  'roller_skates': '🛼',
  'board_game': '🎲',
  'smartwatch': '⌚',
  'headphones': '🎧',
  'science_kit': '🔬',
  'instant_camera': '📸',
  'karaoke': '🎤',
  'skateboard': '🛹',
  'robot_kit': '🤖',
  'keyboard': '🎹',
  'tent': '⛺',
  'game_console': '🎮',
  'bike': '🚲',
  'drawing_tablet': '🎨',
  'icon_task_board': '🎲',
  'icon_task_stall': '🍦',
  'icon_task_cashier': '🧾',
  'icon_board_start': '🚩',
  'icon_board_finish': '🏁',
  'icon_board_piggy': '🐷',
  'icon_board_rest': '🌼',
  'icon_board_flowers': '🌷',
  'icon_board_coin': '🪙',
  'icon_board_light': '💡',
  'icon_board_help': '🧺',
  'icon_board_balloon': '🎈',
  'icon_board_gift': '🎁',
  'icon_board_umbrella': '☂️',
  'icon_weather_sun': '☀️',
  'icon_weather_cloud': '⛅',
  'icon_weather_rain': '🌧️',
  'icon_weather_hot': '🌞',
  'icon_customer_bunny': '🐰',
  'icon_customer_bear': '🐻',
  'icon_customer_cat': '🐱',
  'icon_customer_hedgehog': '🦔',
  'icon_customer_frog': '🐸',
  'icon_customer_owl': '🦉',
  'icon_customer_panda': '🐼',
  'icon_card_apple': '🍎',
  'icon_card_cookie': '🍪',
  'icon_card_candle': '🕯️',
  'icon_task_pricetag': '🔍',
  'icon_card_ball': '⚽',
  'icon_card_pencils': '✏️',
  'icon_card_robot': '🤖',
  'icon_card_walk': '🚶',
  'icon_task_sort': '🧺',
  'icon_task_safety': '🛡️',
  'icon_safe_message': '📲',
  'icon_safe_piggy': '🐷',
  'icon_safe_receipt': '🧾',
  'icon_safe_password': '🔑',
  'icon_safe_card': '💳',
  'icon_safe_prize': '🎁',
  'icon_safe_shop': '🛒',
  'icon_safe_door': '🚪',
  'icon_safe_ask': '🙋',
  'icon_safe_photo': '📸',
  'icon_safe_link': '🔗',
  'icon_safe_secret': '🤫',
  'icon_safe_change': '🪙',
  'icon_safe_wallet': '👛',
  'icon_safe_cash': '💸',
  'icon_safe_pin': '🔢',
  'icon_safe_stranger': '🕵️',
  'icon_safe_bank': '🏦',
  'icon_safe_lock': '🔐',
  'icon_safe_silent': '📵',
  'icon_safe_eyes': '🙈',
  'icon_safe_sms': '💬',
  'icon_safe_slot': '🎰',
  'icon_safe_hurry': '⏰',
  'icon_task_coins': '🪙',
  'icon_task_distribute': '🥧',
  'icon_task_order': '🏷️',
  'icon_task_choice': '🤔',
  'icon_task_basket': '🛒',
  'icon_task_lemonade': '🍋',
  'icon_task_days': '🐷',
  'icon_task_priority': '🥇',
  'icon_task_week': '📅',
  'icon_theme_planning': '🗺️',
  'icon_theme_savings': '🐷',
  'icon_theme_payments': '🛍️',
  'icon_card_bread': '🍞',
  'icon_card_water': '💧',
  'icon_card_soap': '🧼',
  'icon_card_pet_food': '🦴',
  'icon_card_toy': '🧸',
  'icon_card_candy': '🍬',
  'icon_card_bow': '🎀',
  'icon_card_stickers': '✨',
  'icon_card_notebooks': '📓',
  'icon_card_bus_ticket': '🎫',
  'icon_card_medicine': '💊',
  'icon_card_jacket': '🧥',
  'icon_card_jacket_fancy': '🥻',
  'icon_card_phone_game': '🎮',
  'icon_card_ice_cream': '🍦',
  'icon_card_book': '📖',
  'icon_card_bicycle': '🚲',
  'icon_card_fridge': '🧊',
  'icon_card_eraser': '✏️',
  'icon_card_pizza': '🍕',
  'icon_card_sneakers': '👟',
  'icon_card_repair': '🔨',
  'icon_card_milk': '🥛',
  'icon_card_chocolate': '🍫',
  'icon_card_juice': '🧃',
  'icon_card_toy_car': '🚗',
  'icon_card_eggs': '🥚',
  'icon_card_cake': '🎂',
  'icon_card_magazine': '📰',
  'icon_card_pen': '🖊️',
  'icon_event_gift': '🎁',
  'icon_event_cinema': '🎬',
  'icon_event_doctor': '🩺',
  'icon_event_ad': '📢',
  'icon_event_coins': '🪙',
  'icon_event_help': '🤝',
  'icon_event_rain': '🌧️',
  'icon_event_bulb': '💡',
  'icon_event_holiday': '🎉',
  'icon_event_price': '🏷️',
  'icon_event_debt': '🤲',
  'icon_event_receipt': '🧾',
  'icon_event_park': '🎠',
  'icon_event_code': '🔐',
  'icon_event_prize': '🏆',
  'icon_event_umbrella': '☂️',
  'icon_event_insurance': '🛡️',
  'icon_event_lock': '🔒',
  'icon_event_web': '🌐',
  'icon_event_cart': '🛒',
  'icon_event_fair': '🎪',
  'icon_event_euro': '💶',
  'icon_counter_days': '📅',
  'icon_plan_mandatory': '🍲',
  'icon_plan_optional': '🎈',
  'icon_plan_savings': '🐷',
  'icon_gl_money': '💰',
  'icon_gl_income': '➕',
  'icon_gl_expense': '➖',
  'icon_gl_mandatory': '🍲',
  'icon_gl_optional': '🎁',
  'icon_gl_budget': '👛',
  'icon_gl_plan': '📋',
  'icon_gl_savings': '🐷',
  'icon_gl_goal': '🎯',
  'icon_gl_price': '🏷️',
  'icon_gl_change': '🪙',
  'icon_gl_ad': '📣',
  'icon_gl_work': '🛠️',
  'icon_gl_wait': '⏳',
  'icon_gl_cash': '💳',
  'icon_gl_fraud': '🦹',
  'icon_gl_password': '🔑',
  'icon_gl_debt': '🤝',
  'icon_gl_cushion': '🛡️',
  'icon_gl_insurance': '🦺',
  'icon_gl_tax': '🏛️',
  'icon_gl_currency': '💶',
  'icon_gl_receipt': '🧾',
  'icon_gl_bank': '🏦',
  'icon_gl_discount': '🔖',
  'icon_gl_profit': '📈',
  'icon_gl_salary': '💼',
  'icon_gl_price_change': '📉',
  'icon_gl_free': '🆓',
  'icon_gl_rights': '🙋',
};

const List<Color> kArtBackgrounds = [
  FinniColors.mint,
  FinniColors.sky,
  FinniColors.lavender,
  FinniColors.honey,
];

Color artBackground(String id) => kArtBackgrounds[
    id.codeUnits.fold(0, (a, b) => a + b) % kArtBackgrounds.length];

class ItemArt extends StatelessWidget {
  const ItemArt(this.id, {super.key, this.size = 72, this.background = true});

  final String id;
  final double size;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final sprite = _sprites[id];
    final icon = _icons[id];
    final Widget art;
    if (accessoryCells.containsKey(id)) {
      art = SheetArt(
          path: 'assets/pets/shared/accessories.png',
          cell: accessoryCells[id]!,
          columns: 3,
          rows: 3);
    } else if (furnitureCells.containsKey(id)) {
      art = SheetArt(
          path: 'assets/room/furniture.png', cell: furnitureCells[id]!);
    } else if (wallpaperCells.containsKey(id)) {
      art = RoomBackdrop(wallpaperId: id, thumbnail: true);
    } else if (goalCells.containsKey(id)) {
      art = SheetArt(path: 'assets/room/goals.png', cell: goalCells[id]!);
    } else if (sprite != null) {
      art = ProductArt(sheet: sprite.$1, cell: sprite.$2);
    } else if (icon != null) {
      art = GameIcon(icon, size: size * .8);
    } else if (id == 'wp_stripes' || id == 'wp_dots') {
      art = CustomPaint(painter: _PatternPainter(dots: id == 'wp_dots'));
    } else {
      art = Center(
        child: Text(
          kEmoji[id] ?? '🎁',
          style: TextStyle(fontSize: size * .52, height: 1),
          textScaler: TextScaler.noScaling,
        ),
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .08),
        decoration: background
            ? BoxDecoration(
                color: artBackground(id).withValues(alpha: .75),
                borderRadius: BorderRadius.circular(size * .3),
              )
            : null,
        child: art,
      ),
    );
  }
}

class RoomArt extends StatelessWidget {
  const RoomArt(this.id, {super.key, required this.size});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (furnitureCells.containsKey(id) || goalCells.containsKey(id)) {
      return SizedBox(
          width: size,
          height: size,
          child: SheetArt(
            path: goalCells.containsKey(id)
                ? 'assets/room/goals.png'
                : 'assets/room/furniture.png',
            cell: goalCells[id] ?? furnitureCells[id]!,
            alignment: Alignment.bottomCenter,
          ));
    }
    final sprite = _sprites[id];
    final icon = _icons[id];
    final Widget art;
    if (sprite != null) {
      art = ProductArt(sheet: sprite.$1, cell: sprite.$2);
    } else if (icon != null) {
      art = Align(
          alignment: Alignment.bottomCenter, child: GameIcon(icon, size: size));
    } else if (id == 'aquarium') {
      art = Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: size * .78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [FinniColors.sky, FinniColors.blue],
              stops: [.1, 1],
            ),
            borderRadius: BorderRadius.circular(size * .12),
            border: Border.all(
                color: FinniColors.paper, width: math.max(2, size * .05)),
          ),
          child: Text('🐠',
              style: TextStyle(fontSize: size * .42, height: 1),
              textScaler: TextScaler.noScaling),
        ),
      );
    } else {
      art = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: Text(
          kEmoji[id] ?? '🎁',
          style: TextStyle(fontSize: size * .9, height: 1),
          textScaler: TextScaler.noScaling,
        ),
      );
    }
    return ExcludeSemantics(
        child: SizedBox(width: size, height: size, child: art));
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.dots});

  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clip =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * .2));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(rect, Paint()..color = FinniColors.paper);
    final paint = Paint()
      ..color = dots
          ? FinniColors.purple.withValues(alpha: .45)
          : FinniColors.primary.withValues(alpha: .35);
    if (dots) {
      final step = size.width / 4;
      for (var y = step / 2; y < size.height; y += step) {
        for (var x = step / 2; x < size.width; x += step) {
          canvas.drawCircle(Offset(x, y), step * .22, paint);
        }
      }
    } else {
      final step = size.width / 5;
      for (var x = 0.0; x < size.width; x += step * 2) {
        canvas.drawRect(Rect.fromLTWH(x, 0, step, size.height), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => oldDelegate.dots != dots;
}

class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.iconId, {super.key, this.size = 56, this.color});

  final String iconId;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sprite = _sprites[iconId];
    final hasArtwork = accessoryCells.containsKey(iconId) ||
        furnitureCells.containsKey(iconId) ||
        wallpaperCells.containsKey(iconId) ||
        goalCells.containsKey(iconId);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .1),
        decoration: BoxDecoration(
          color: color ?? artBackground(iconId).withValues(alpha: .8),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: hasArtwork
            ? ItemArt(iconId, size: size * .8, background: false)
            : sprite != null
                ? ProductArt(sheet: sprite.$1, cell: sprite.$2)
                : Center(
                    child: Text(
                      kEmoji[iconId] ?? '⭐',
                      style: TextStyle(fontSize: size * .5, height: 1),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
      ),
    );
  }
}
