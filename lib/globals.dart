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
import 'package:logger/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

var logger = Logger();
FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

const Color backgroundColor = Colors.purple;
const Color foregroundColor = Colors.white;

const messageUrl = 'https://www.steamtrades.com/messages';
const loginUrl = 'https://www.steamtrades.com/?login';
const donateUrl = 'https://selosh.gitlab.io/donate/';

const List<String> blockedDomains = [
  "nitropay.com",
  "rubiconproject.com",
  "google-analytics.com",
  "googletagmanager.com"
];

const String groupKey = 'io.gitlab.selosh.gametrader.messages';
const String groupChannelId = 'message_channel';
const String groupChannelName = 'Message Channel';
const String groupChannelDescription = 'Channel for message notifications';
const int summaryNotificationId = 0; // ID for the summary notification

