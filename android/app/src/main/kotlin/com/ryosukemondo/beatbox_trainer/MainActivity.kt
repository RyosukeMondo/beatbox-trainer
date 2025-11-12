package com.ryosukemondo.beatbox_trainer

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    init {
        System.loadLibrary("beatbox_trainer")
    }
}
