/* Copyright (C) 2024 Saladin Shaban
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'globals.dart';
import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await notificationsPlugin.getNotificationAppLaunchDetails();

  String initialUrl = messageUrl;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    String? selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
    if (selectedNotificationPayload != null &&
        selectedNotificationPayload == "login") {
      initialUrl = loginUrl;
    }
  }

  runApp(MaterialApp(
    home: HomePage(title: "Game Trader", initialUrl: initialUrl),
    color: backgroundColor,
  ));
}
