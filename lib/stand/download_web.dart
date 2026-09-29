import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

void downloadApk() => _open(
    (const String.fromEnvironment('BUILD_ID', defaultValue: 'local') == 'local'
            ? 'https://github.com/stepApp-su/LCT2026-stepapp/releases/latest/download/finni.apk'
            : '/downloads/finni.apk')
        .toJS,
    '_blank'.toJS,
    'noopener,noreferrer'.toJS);
