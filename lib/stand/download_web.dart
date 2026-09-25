import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

void downloadApk() => _open(
    '/downloads/finni.apk'.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
