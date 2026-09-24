import 'dart:io';

import 'package:finni/content/content_repository.dart';

Future<ContentBundle> loadTestContent() =>
    ContentRepository((file) => File('assets/content/$file').readAsString())
        .load();
