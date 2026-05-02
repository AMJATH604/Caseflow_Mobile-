package com.example.caseflow

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Channel 1: Hearing Reminders
            val hearingChannel = NotificationChannel(
                "hearing_reminders",
                "Hearing Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Court hearing date reminders"
                enableVibration(true)
            }
            manager.createNotificationChannel(hearingChannel)

            // Channel 2: Chat Messages (Digital Chambers)
            val chatChannel = NotificationChannel(
                "chat_messages",
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Digital Chambers messages from your team"
                enableVibration(true)
            }
            manager.createNotificationChannel(chatChannel)
        }
    }
}
