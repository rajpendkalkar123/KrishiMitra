package com.rajpendkalkar123.krishimitra

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.webkit.WebView

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable WebView hardware acceleration and debugging (fixes frame sync issues)
        WebView.setWebContentsDebuggingEnabled(false)
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
                // Enable hardware acceleration for better WebView performance
                window.setFlags(
                    android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                    android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                )
            }
        } catch (e: Exception) {
            // Ignore if hardware acceleration fails
        }
    }
}
