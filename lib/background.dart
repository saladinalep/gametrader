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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';
import 'scrape.dart';

// unread messages already processed
List<String> _unreadPermalinks = [];
List<String> _unreadMessages = [];

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    bool doneLoading = false;
    HeadlessInAppWebView headlessView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(messageUrl)),
        initialSettings: InAppWebViewSettings(
            contentBlockers: blockedDomains
                .map((filter) => ContentBlocker(
                    trigger: ContentBlockerTrigger(
                      urlFilter: filter,
                    ),
                    action: ContentBlockerAction(
                        type: ContentBlockerActionType.BLOCK)))
                .toList()),
        onLoadStop: (controller, url) async {
          String html = await controller.evaluateJavascript(
              source: "document.documentElement.outerHTML;");
          await _checkForMessages(html);
          doneLoading = true;
        },
        onReceivedError: (controller, request, error) {
          logger.e("Error loading messages page: $error");
          doneLoading = true;
        });

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('notification_icon'),
    );

    await notificationsPlugin.initialize(initializationSettings);

    await _loadProcessed();
    logger.d("Loaded processed links: $_unreadPermalinks");

    await headlessView.run();
    while (!doneLoading) {
      await Future.delayed(const Duration(seconds: 2));
    }
    return Future.value(true);
  });
}

Future<void> _loadProcessed() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  _unreadPermalinks = sharedPreferences.getStringList("unreadPermalinks") ?? [];
  _unreadMessages = sharedPreferences.getStringList("unreadMessages") ?? [];
}

Future<void> _saveProcessed() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sharedPreferences.setStringList("unreadPermalinks", _unreadPermalinks);
  sharedPreferences.setStringList("unreadMessages", _unreadMessages);
}

void _requestLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;
  final lastRequest = (prefs.getInt("lastLoginRequest") ?? 0);

  // check that at least one hour has passed
  final minutesPassed = (now - lastRequest) / (1000 * 60);
  if (minutesPassed < 60) {
    return;
  } else {
    prefs.setInt("lastLoginRequest", now);
  }

  notificationsPlugin.show(
      summaryNotificationId,
      "Login required",
      "Log in to SteamTrades to receive message notifications",
      const NotificationDetails(
          android: AndroidNotificationDetails(groupChannelId, groupChannelName,
              channelDescription: groupChannelDescription,
              priority: Priority.max,
              importance: Importance.max)),
      payload: "login");
}

Future<void> _saveResult(String result) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sharedPreferences.setInt('lastCheck', DateTime.now().millisecondsSinceEpoch);
  sharedPreferences.setString('lastResult', result);
}

Future<void> _checkForMessages(String html) async {
  List<String> errors = [];
  List<String> newMessages = [];

  try {
    List<STMessage> messages = parseMessages(html, errors);

    if (messages.isEmpty) {
      // all messages marked as read
      _unreadPermalinks = [];
      _unreadMessages = [];
      _saveProcessed();
      _saveResult("No unread messages");
      return;
    }

    // remove unread messages we already notified the user about
    messages.removeWhere(
        (element) => _unreadPermalinks.contains(element.permalink));

    if (messages.isEmpty) {
      _saveResult("No new messages");
      return;
    }

    for (STMessage message in messages) {
      newMessages.add("<b>${message.author}:</b> ${message.message}");
      logger.d("Adding ${message.permalink} to permalinks");
      _unreadPermalinks.add(message.permalink);
    }

    _unreadMessages = newMessages + _unreadMessages;
    // Create a summary notification to group all messages together
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      groupChannelId,
      groupChannelName,
      channelDescription: groupChannelDescription,
      priority: Priority.max,
      importance: Importance.max,
      styleInformation: InboxStyleInformation(_unreadMessages,
          htmlFormatLines: true,
          htmlFormatContent: true,
          contentTitle: "New messages on SteamTrades",
          summaryText: "${newMessages.length} new message(s)"),
      groupKey: groupKey,
      setAsGroupSummary: true,
    );

    notificationsPlugin.show(
      summaryNotificationId,
      'New Messages on SteamTrades',
      _unreadMessages[0],
      NotificationDetails(android: androidPlatformChannelSpecifics),
    );
  } on LoggedOutException {
    logger.d("User logged out");
    _saveResult("User logged out");
    _requestLogin();
    return;
  } catch (e) {
    logger.e("Unexpected error while checking for messages: $e");
  }

  String result = "${newMessages.length} new message(s)";
  if (errors.isNotEmpty) {
    result = "Errors encountered: ${errors.last}";
  }

  _saveResult(result);
  _saveProcessed();
}
