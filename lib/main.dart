import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    var flutterLocalNotificationsPlugin = await initializeFcm();
    runApp(MyApp(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin));
  }, (error, stack) {});
}

initializeFcm() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  var channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print(newToken);
  });
  FirebaseMessaging.instance.getToken().then((value) {
    print(value);
  });
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: IOSNotificationDetails(
            badgeNumber: 1,
            subtitle: 'the subtitle',
            sound: 'slow_spring_board.aiff',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  });
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  return flutterLocalNotificationsPlugin;
}

class MyApp extends StatefulWidget {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  GlobalKey webViewKey = GlobalKey();
  Completer<InAppWebViewController> webViewController = Completer<InAppWebViewController>();
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(useShouldOverrideUrlLoading: true, mediaPlaybackRequiresUserGesture: false),
    android: AndroidInAppWebViewOptions(useHybridComposition: true),
    ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
  );

  MyApp({Key? key, required this.flutterLocalNotificationsPlugin}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

Future<void> setupInteractedMessage(webViewController) async {
  return webViewController.future.then((controller) async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) onBackgroundMessage(initialMessage, controller);
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await onBackgroundMessage(message, controller);
    });
  });
}

onBackgroundMessage(RemoteMessage message, controller) async {
  var redirectUrl = message.data['redirectUrl'];
  if (redirectUrl != null) {
    await controller.loadUrl(urlRequest: URLRequest(url: Uri.parse(redirectUrl)));
  }
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    setupInteractedMessage(widget.webViewController);
    AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings();
    InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    widget.flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (payload) async {
      if (payload != null) {
        var jsonPayload = jsonDecode(payload);
        var redirectUrl = jsonPayload['redirectUrl'];
        if (redirectUrl != null) {
          return widget.webViewController.future.then((controller) async {
            await controller.loadUrl(urlRequest: URLRequest(url: Uri.parse(redirectUrl)));
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '노는법',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: webviewWidget(widget.webViewController, widget.webViewKey, widget.options),
    );
  }
}

webviewWidget(Completer<InAppWebViewController> webViewController, webViewKey, options) {
  return WillPopScope(
    onWillPop: () async {
      return webViewController.future.then((controller) async {
        if (await controller.canGoBack()) {
          controller.goBack();
          return Future.value(false);
        } else {
          return Future.value(true);
        }
      });
    },
    child: Scaffold(
      body: SafeArea(
        child: InAppWebView(
          key: webViewKey,
          initialUrlRequest: URLRequest(url: Uri.parse('https://nonunbub.com')),
          initialOptions: options,
          onWebViewCreated: (controller) async {
            webViewController.complete(controller);
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url!;
            if (!uri.scheme.contains('http')) {
              var platform = MethodChannel('NNB/INTENT');
              var link = uri.toString();
              var result = await platform.invokeMethod('intent', {"url": link});
              if (result != null) {
                return webViewController.future.then((controller) async {
                  await controller.loadUrl(urlRequest: URLRequest(url: Uri.parse(result)));
                });
              }
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
    ),
  );
}
