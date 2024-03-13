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
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'globals.dart';
import 'background.dart';

String formatDateTime(DateTime dateTime) {
  DateTime now = DateTime.now();
  DateFormat formatter;

  // Check if the date is today
  if (dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day) {
    // If it's today, use 'HH:mm' format
    formatter = DateFormat('HH:mm');
  } else {
    // Otherwise, use 'MMM/dd - HH:mm' format
    formatter = DateFormat('MMM/dd - HH:mm');
  }

  return formatter.format(dateTime);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title, required this.initialUrl});

  final String title;
  final String initialUrl;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _checkForMessages = true;
  int _progress = 100;
  String _lastCheck = "Never";
  String _lastResult = "None";

  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: backgroundColor,
      ),
      onRefresh: () async {
        webViewController?.reload();
      },
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('notification_icon'),
    );

    notificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      String gotoUrl;
      if (response.payload != null && response.payload == "login") {
        gotoUrl = loginUrl;
      } else {
        gotoUrl = messageUrl;
      }
      _loadUrl(WebUri(gotoUrl));
    });

    _checkAndroidPermissions();

    Workmanager().initialize(callbackDispatcher);

    _loadCheckForMessages();
  }

  Future<void> _loadUrl(WebUri uri) async {
    return webViewController?.loadUrl(urlRequest: URLRequest(url: uri));
  }

  _updateBackgroundTask() {
    if (_checkForMessages) {
      Workmanager().registerPeriodicTask("1", "checkForMessages",
          frequency: const Duration(minutes: 15));
    } else {
      Workmanager().cancelAll();
    }
  }

  _loadCheckForMessages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _checkForMessages = (prefs.getBool('checkForMessages') ?? true);
    });
    _updateBackgroundTask();
  }

  _loadLastResult() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    int lastCheck = (prefs.getInt('lastCheck') ?? 0);
    if (lastCheck != 0) {
      setState(() {
        _lastCheck =
            formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastCheck));
        _lastResult = (prefs.getString('lastResult') ?? "None");
      });
    }
  }

  // Update SharedPreferences when the button is toggled
  _updateCheckForMessages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _checkForMessages = value;
      prefs.setBool('checkForMessages', value);
    });
    _updateBackgroundTask();
  }

  Future<void> _checkAndroidPermissions() async {
    final bool enabled = await notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        false;

    logger.d("Notifications are ${(enabled ? "enabled" : "disabled")}");

    if (!enabled) _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool granted =
        await androidImplementation?.requestNotificationsPermission() ?? false;
    logger.d("Notifications were ${granted ? "granted" : "declined"}");
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (didPop) return;

          if (Navigator.of(context).canPop()) {
            Navigator.pop(context);
            return;
          }

          webViewController?.canGoBack().then((value) {
            if (value) {
              webViewController?.goBack();
            } else {
              SystemNavigator.pop();
            }
          });
        },
        child: Scaffold(
          appBar: AppBar(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              title: Text(widget.title),
              actions: [
                IconButton(
                    onPressed: () => webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(messageUrl))),
                    icon: const Icon(Icons.home)),
                IconButton(
                    onPressed: webViewController?.reload,
                    icon: const Icon(Icons.refresh))
              ]),
          body: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) async {
                  webViewController = controller;
                },
                initialSettings: InAppWebViewSettings(
                  useShouldInterceptRequest: true,
                ),
                shouldInterceptRequest: (controller, request) async {
                  if (blockedDomains
                      .any((domain) => request.url.host.contains(domain))) {
                    return WebResourceResponse(statusCode: 403);
                  } else {
                    return null;
                  }
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT);
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController?.endRefreshing();
                  setState(() {
                    _progress = 100;
                  });

                  if (_checkForMessages &&
                      url != null &&
                      url.host.endsWith('steamtrades.com')) {
                    Workmanager()
                        .registerOneOffTask("oneOffCheck", "checkForMessages");
                  }
                },
                onReceivedError: (controller, request, error) {
                  pullToRefreshController?.endRefreshing();
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController?.endRefreshing();
                  }
                  setState(() {
                    _progress = progress;
                  });
                },
              ),
              if (_progress != 100)
                LinearProgressIndicator(value: _progress / 100.0)
            ],
          ),
          onDrawerChanged: (isOpened) {
            if (isOpened) _loadLastResult();
          },
          drawer: Drawer(
              child: ListView(padding: EdgeInsets.zero, children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Check for messages in the background'),
              trailing: Switch(
                value: _checkForMessages,
                onChanged: _updateCheckForMessages,
              ),
            ),
            ListTile(
              title: const Text('Last check'),
              subtitle: Text(
                  "$_lastCheck ${_lastCheck != "Never" ? "- $_lastResult" : ""}"),
            ),
            ListTile(
              title: const Text('Buy me a coffee!'),
              onTap: () {
                launchUrl(Uri.parse(donateUrl));
                Navigator.pop(context);
              },
            ),
            AboutListTile(
              applicationIcon: Image.asset('assets/icons/app_icon.png',
                  width: 48, height: 48),
              applicationName: 'Game Trader',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2024 Saladin Shaban',
            ),
          ])),
        ));
  }
}
