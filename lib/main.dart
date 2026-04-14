import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:convert' as convert show utf8;
import 'dart:async' show StreamTransformer;

// 配置常量
const String apiUrl = 'http://43.173.125.90:9090/api/news';
const String newsType = 'AI'; // 可配置
const int newsLimit = 3; // 可配置
const Duration pollInterval = Duration(minutes: 10); // 可配置轮询间隔

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 加载用户设置
  final settingsManager = SettingsManager();
  await settingsManager.loadSettings();

  const WindowOptions options = WindowOptions(
    size: Size(120, 120),
    minimumSize: Size(120, 120),
    maximumSize: Size(120, 120),
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
    title: '悬浮聊天',
    alwaysOnTop: true,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.show();
  });

  runApp(const FloatingChatApp());
}

class FloatingChatApp extends StatelessWidget {
  const FloatingChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Floating Chat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const FloatingBubblePage(),
    );
  }
}

class FloatingBubblePage extends StatefulWidget {
  const FloatingBubblePage({super.key});

  @override
  State<FloatingBubblePage> createState() => _FloatingBubblePageState();
}

class _FloatingBubblePageState extends State<FloatingBubblePage>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _onBubbleTap() {
    // 检查是否已完成初始设置
    final settings = SettingsManager().settings;
    
    if (settings.hasCompletedSetup) {
      // 已完成设置，直接打开聊天窗口
      _openChatWindow();
    } else {
      // 未完成设置，打开初始设置页面
      _openInitialSetupWindow();
    }
  }

  void _openInitialSetupWindow() async {
    final Rect currentBounds = await windowManager.getBounds();
    const double settingsWidth = 500;
    const double settingsHeight = 600;
    const double offsetX = 20;
    const double offsetY = 20;

    double settingsX = currentBounds.right + offsetX;
    double settingsY = currentBounds.bottom + offsetY;
    const double screenWidth = 1920;
    const double screenHeight = 1080;

    if (settingsX + settingsWidth > screenWidth) {
      settingsX = currentBounds.left - settingsWidth - offsetX;
    }
    if (settingsY + settingsHeight > screenHeight) {
      settingsY = currentBounds.top - settingsHeight - offsetY;
    }
    settingsX = settingsX.clamp(0, screenWidth - settingsWidth);
    settingsY = settingsY.clamp(0, screenHeight - settingsHeight);

    await windowManager.setMinimumSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setMaximumSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    await windowManager.setBounds(Rect.fromLTWH(settingsX, settingsY, settingsWidth, settingsHeight));

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const InitialSetupPage(),
    ));
  }

  void _openChatWindow() async {
    final Rect currentBounds = await windowManager.getBounds();
    const double chatWidth = 640;
    const double chatHeight = 720;
    const double offsetX = 20;
    const double offsetY = 20;

    double chatX = currentBounds.right + offsetX;
    double chatY = currentBounds.bottom + offsetY;
    const double screenWidth = 1920;
    const double screenHeight = 1080;

    if (chatX + chatWidth > screenWidth) {
      chatX = currentBounds.left - chatWidth - offsetX;
    }
    if (chatY + chatHeight > screenHeight) {
      chatY = currentBounds.top - chatHeight - offsetY;
    }
    chatX = chatX.clamp(0, screenWidth - chatWidth);
    chatY = chatY.clamp(0, screenHeight - chatHeight);

    await windowManager.setMinimumSize(const Size(chatWidth, chatHeight));
    await windowManager.setMaximumSize(const Size(chatWidth, chatHeight));
    await windowManager.setSize(const Size(chatWidth, chatHeight));
    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    await windowManager.setBounds(Rect.fromLTWH(chatX, chatY, chatWidth, chatHeight));

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChatPage(),
    ));
  }



  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        windowManager.startDragging();
      },
      onTap: _onBubbleTap,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/redboy.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(text: '欢迎使用悬浮聊天窗口！', isMine: false, timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
    ChatMessage(text: '你可以在这里输入消息，模拟微信聊天界面。', isMine: false, timestamp: DateTime.now().subtract(const Duration(minutes: 4))),
  ];
  final List<NewsItem> _news = <NewsItem>[];
  Timer? _pollTimer;
  String _chatBuffer = '';
  String _currentEvent = '';
  DateTime? _lastNewsRequestTime;
  late UserSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsManager().settings;
    SettingsManager().addListener(_onSettingsChanged);
    _loadMessages();
    _initializeNews();
    _pollTimer = Timer.periodic(
      Duration(minutes: _settings.newsIntervalMinutes),
      (_) => _checkAndFetchNews(),
    );
  }

  @override
  void dispose() {
    SettingsManager().removeListener(_onSettingsChanged);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {
      _settings = SettingsManager().settings;
    });
    // 重新设置定时器
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(minutes: _settings.newsIntervalMinutes),
      (_) => _checkAndFetchNews(),
    );
  }

  void _openSettings() async {
    // 获取当前聊天窗口位置
    final Rect currentBounds = await windowManager.getBounds();
    
    const double settingsWidth = 500;
    const double settingsHeight = 600;

    // 计算设置窗口位置：以聊天窗口中心为基准，保持视觉连续性
    double settingsX = currentBounds.left + (currentBounds.width - settingsWidth) / 2;
    double settingsY = currentBounds.top + (currentBounds.height - settingsHeight) / 2;
    
    const double screenWidth = 1920;
    const double screenHeight = 1080;

    // 确保窗口在屏幕范围内
    settingsX = settingsX.clamp(0, screenWidth - settingsWidth);
    settingsY = settingsY.clamp(0, screenHeight - settingsHeight);

    await windowManager.setMinimumSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setMaximumSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setSize(const Size(settingsWidth, settingsHeight));
    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    await windowManager.setBounds(Rect.fromLTWH(settingsX, settingsY, settingsWidth, settingsHeight));

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SettingsTabPage(),
    ));
  }

  void _sendMessage() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    // 检查是否是打开软件的命令
    final String lowerText = text.toLowerCase();
    if (lowerText == '打开钉钉' || lowerText == '钉钉') {
      _controller.clear();
      await _openApplication('钉钉');
      return;
    }
    if (lowerText == '打开浏览器' || lowerText == '浏览器' || lowerText == '打开chrome' || lowerText == 'chrome') {
      _controller.clear();
      await _openApplication('浏览器');
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isMine: true, timestamp: DateTime.now()));
      _controller.clear();
    });
    _saveMessages(); // 保存消息
    _scrollToBottom();
    // 调用流式聊天
    _streamChat(text);
  }

  Future<void> _openApplication(String appName) async {
    try {
      if (Platform.isWindows) {
        if (appName == '钉钉') {
          // 尝试多种方式打开钉钉
          await Process.run('powershell', ['/c', 'start', 'dingtalk']);
        } else if (appName == '浏览器') {
          // 打开默认浏览器
          await Process.run('powershell', ['/c', 'start', 'chrome']);
        }
      } else if (Platform.isMacOS) {
        if (appName == '钉钉') {
          await Process.run('open', ['-a', '钉钉']);
        } else if (appName == '浏览器') {
          await Process.run('open', ['-a', 'Google Chrome']);
        }
      }
      
      // 显示提示消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在打开$appName...'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0A84FF),
          ),
        );
      }
    } catch (e) {
      debugPrint('打开$appName失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开$appName失败'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _streamChat(String userMessage) async {
    final Uri uri = Uri.parse('http://43.173.125.90:9090/api/chat/stream');
    _chatBuffer = ''; // 重置缓冲区
    
    // 构建聊天请求体，包含消息和缓存的新闻内容
    final Map<String, dynamic> requestBody = {
      'text': userMessage,
    };
    
    // 如果有缓存的新闻，添加 content 参数（格式化为字符串）
    if (_news.isNotEmpty) {
      final List<String> newsLines = <String>[];
      for (int i = 0; i < _news.length; i++) {
        final news = _news[i];
        final StringBuffer sb = StringBuffer();
        sb.writeln('第${i + 1}条新闻：');
        sb.writeln('标题：${news.title}');
        sb.writeln('内容：${news.content}');
        if (news.pageContent != null && news.pageContent!.isNotEmpty) {
          sb.writeln('详情：${news.pageContent}');
        }
        newsLines.add(sb.toString());
      }
      requestBody['context'] = newsLines.join('\n\n');
    }
    
    debugPrint('=== Stream Chat Request ===');
    debugPrint('URL: $uri');
    debugPrint('Message: $userMessage');
    debugPrint('Cached news count: ${_news.length}');
    debugPrint('Payload: ${json.encode(requestBody)}');
    
    try {
      final HttpClient httpClient = HttpClient();
      httpClient.findProxy = (_) => 'DIRECT';
      
      final HttpClientRequest request = await httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(json.encode(requestBody));
      
      debugPrint('Request sent, waiting for response...');
      final HttpClientResponse response = await request.close();
      
      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        debugPrint('Stream started, processing events...');
        _currentEvent = ''; // 重置事件类型
        // 逐行读取 SSE 流
        await for (final line in response.transform(convert.utf8.decoder).transform(const LineSplitter())) {
          if (line.isEmpty) continue;
          
          debugPrint('SSE Line: $line');
          
          // 解析 event 行
          if (line.startsWith('event:')) {
            _currentEvent = line.substring(6).trim();
            debugPrint('Event type: $_currentEvent');
          }
          // 解析 data 行
          else if (line.startsWith('data:')) {
            final String jsonStr = line.substring(5).trim();
            debugPrint('Parsed JSON: $jsonStr');
            try {
              final Map<String, dynamic> data = json.decode(jsonStr);
              
              if (_currentEvent == 'delta' && data.containsKey('delta')) {
                final String delta = data['delta'] as String;
                debugPrint('Delta chunk: $delta');
                _chatBuffer += delta;
                
                // 检查并输出段落
                _processBuffer();
              } else if (_currentEvent == 'done') {
                debugPrint('Stream completed (event: done)');
                // 输出所有剩余缓冲内容
                if (_chatBuffer.isNotEmpty) {
                  setState(() {
                    _messages.add(ChatMessage(text: _chatBuffer.trim(), isMine: false, timestamp: DateTime.now()));
                  });
                  _saveMessages(); // 保存消息
                  _scrollToBottom();
                  _chatBuffer = '';
                }
              }
            } catch (e) {
              debugPrint('JSON parse error: $e, raw: $jsonStr');
            }
          }
        }
        
        httpClient.close();
      } else {
        // 读取错误响应体
        final String errorBody = await response.transform(convert.utf8.decoder).join();
        debugPrint('=== Stream Chat Failed ===');
        debugPrint('Status code: ${response.statusCode}');
        debugPrint('Status reason: ${response.reasonPhrase}');
        debugPrint('Response body: $errorBody');
        debugPrint('Response headers: ${response.headers}');
        debugPrint('==========================');
        
        setState(() {
          _messages.add(ChatMessage(text: '聊天请求失败 (${response.statusCode})', isMine: false, timestamp: DateTime.now()));
        });
        _saveMessages(); // 保存消息
      }
    } catch (e, stackTrace) {
      debugPrint('=== Stream Chat Exception ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('==============================');
      setState(() {
        _messages.add(ChatMessage(text: '网络连接错误: $e', isMine: false, timestamp: DateTime.now()));
      });
      _saveMessages(); // 保存消息
    }
  }

  void _processBuffer() {
    const String punctuation = '。！？；'; // 主要标点符号
    
    // 查找最后一个标点符号
    int lastPuncIndex = -1;
    for (int i = _chatBuffer.length - 1; i >= 0; i--) {
      if (punctuation.contains(_chatBuffer[i])) {
        lastPuncIndex = i;
        break;
      }
    }
    
    if (lastPuncIndex == -1) return; // 没有标点，继续缓冲
    
    // 获取到标点符号之前的文本
    final String segment = _chatBuffer.substring(0, lastPuncIndex).trim();
    final String punc = _chatBuffer[lastPuncIndex];
    
    // 如果段落长度 < 50，继续缓冲
    if (segment.length < 50) {
      return;
    }
    
    // 输出段落（包含标点）
    if (segment.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(text: segment + punc, isMine: false, timestamp: DateTime.now()));
      });
      _saveMessages(); // 保存消息
      _scrollToBottom();
    }
    
    // 清除已输出部分，保留剩余缓冲
    _chatBuffer = _chatBuffer.substring(lastPuncIndex + 1);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (messageDate == today) {
      dateStr = '今天';
    } else if (messageDate == yesterday) {
      dateStr = '昨天';
    } else {
      dateStr = '${dateTime.month}月${dateTime.day}日';
    }
    
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $time';
  }

  Future<String> _getMessagesFilePath() async {
    final appDataDir = Directory.systemTemp;
    final chatDir = Directory('${appDataDir.path}/flutter_chat');
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }
    return '${chatDir.path}/messages.json';
  }

  Future<String> _getLastNewsTimeFilePath() async {
    final appDataDir = Directory.systemTemp;
    final chatDir = Directory('${appDataDir.path}/flutter_chat');
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }
    return '${chatDir.path}/last_news_time.txt';
  }

  Future<void> _loadLastNewsTime() async {
    try {
      final filePath = await _getLastNewsTimeFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        _lastNewsRequestTime = DateTime.parse(contents);
        debugPrint('加载上次新闻请求时间: $_lastNewsRequestTime');
      }
    } catch (e) {
      debugPrint('加载新闻请求时间失败: $e');
      _lastNewsRequestTime = null;
    }
  }

  Future<void> _saveLastNewsTime(DateTime time) async {
    try {
      final filePath = await _getLastNewsTimeFilePath();
      final file = File(filePath);
      await file.writeAsString(time.toIso8601String());
      _lastNewsRequestTime = time;
      debugPrint('新闻请求时间已保存: $time');
    } catch (e) {
      debugPrint('保存新闻请求时间失败: $e');
    }
  }

  Future<void> _initializeNews() async {
    await _loadLastNewsTime();
    await _checkAndFetchNews();
  }

  Future<void> _checkAndFetchNews() async {
    final now = DateTime.now();
    
    // 获取当前设置的轮询间隔
    final currentPollInterval = Duration(minutes: _settings.newsIntervalMinutes);
    
    // 如果没有上次请求时间，或者间隔超过轮询时间，则请求新闻
    if (_lastNewsRequestTime == null || 
        now.difference(_lastNewsRequestTime!).compareTo(currentPollInterval) >= 0) {
      debugPrint('满足新闻请求条件，准备获取新闻');
      await _fetchNews();
      await _saveLastNewsTime(now);
    } else {
      final remaining = currentPollInterval - now.difference(_lastNewsRequestTime!);
      debugPrint('新闻请求冷却中，距下次更新还需 ${remaining.inMinutes} 分钟');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final filePath = await _getMessagesFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final jsonData = json.decode(contents) as List<dynamic>;
        
        setState(() {
          _messages.clear();
          for (final item in jsonData) {
            _messages.add(ChatMessage(
              text: item['text'] ?? '',
              isMine: item['isMine'] ?? false,
              type: item['type'] == 'news' ? MessageType.news : MessageType.chat,
              newsTitle: item['newsTitle'],
              newsContent: item['newsContent'],
              timestamp: DateTime.parse(item['timestamp'] ?? DateTime.now().toString()),
            ));
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        debugPrint('加载了 ${_messages.length} 条聊天记录');
      }
    } catch (e) {
      debugPrint('加载聊天记录失败: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final filePath = await _getMessagesFilePath();
      final file = File(filePath);
      
      final jsonData = _messages.map((msg) => {
        'text': msg.text,
        'isMine': msg.isMine,
        'type': msg.type == MessageType.news ? 'news' : 'chat',
        'newsTitle': msg.newsTitle,
        'newsContent': msg.newsContent,
        'timestamp': msg.timestamp.toIso8601String(),
      }).toList();
      
      await file.writeAsString(json.encode(jsonData));
      debugPrint('聊天记录已保存');
    } catch (e) {
      debugPrint('保存聊天记录失败: $e');
    }
  }

  Future<void> _fetchNews() async {
    // 使用用户设置的感兴趣方向
    final String currentNewsType = _settings.interest;
    final Uri uri = Uri.parse('$apiUrl?type=$currentNewsType&limit=$newsLimit');
    debugPrint('Fetching news from: $uri');
    try {
      // 改用最直接的方式：重新创建 HttpClient 并明确不走代理
      final HttpClient httpClient = HttpClient();
      httpClient.findProxy = (_) => 'DIRECT';
      
      final HttpClientRequest request = await httpClient.getUrl(uri)
          .timeout(const Duration(seconds: 5)); // 连接超时 5 秒
      request.headers.add('User-Agent', 'Flutter/News-Client');
      
      final HttpClientResponse response = await request.close()
          .timeout(const Duration(seconds: 20)); // 响应超时 20 秒
      
      final String responseBody = await response.transform(convert.utf8.decoder).join();
      
      debugPrint('News response status: ${response.statusCode}');
      debugPrint('News response body: $responseBody');
      
      httpClient.close();
      
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(responseBody);
          final List<dynamic> newsList = data['items'] ?? [];
          debugPrint('Parsed ${newsList.length} news items');
          
          setState(() {
            _news.clear();
            for (final dynamic item in newsList) {
              final newsItem = NewsItem(
                title: item['title'] ?? '无标题',
                content: item['content'] ?? '无内容',
                titleZh: item['title_zh'],
                contentZh: item['content_zh'],
                pageContent: item['page_content'],
              );
              _news.add(newsItem);
              // 将新闻添加到聊天记录中
              _messages.add(ChatMessage(
                text: '',
                isMine: false,
                type: MessageType.news,
                newsTitle: newsItem.title,
                newsContent: newsItem.content,
                newsTitleZh: newsItem.titleZh,
                newsContentZh: newsItem.contentZh,
                newsPageContent: newsItem.pageContent,
                timestamp: DateTime.now(),
              ));
            }
            // 自动滚动到底部显示新闻
            _scrollToBottom();
          });
          _saveMessages(); // 保存新闻到聊天记录
        } catch (parseError) {
          debugPrint('JSON parse error: $parseError');
        }
      } else {
        debugPrint('Failed to fetch news: ${response.statusCode} ${response.reasonPhrase}');
      }
    } on TimeoutException catch (e) {
      debugPrint('News request timed out: $e');
    } on SocketException catch (e) {
      debugPrint('News socket error: $e (this might be a proxy issue)');
    } catch (e, stackTrace) {
      debugPrint('Error fetching news: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _closeChat() async {
    // 获取当前聊天窗口位置，用于计算悬浮窗位置
    final Rect chatBounds = await windowManager.getBounds();
    
    // 计算悬浮窗应该出现的位置（聊天窗口中心）
    const double bubbleSize = 120;
    final double bubbleX = chatBounds.left + (chatBounds.width - bubbleSize) / 2;
    final double bubbleY = chatBounds.top + (chatBounds.height - bubbleSize) / 2;
    
    // 恢复悬浮窗属性
    await windowManager.setSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setMinimumSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setMaximumSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(false);
    
    // 设置悬浮窗位置到聊天窗口中心
    await windowManager.setBounds(Rect.fromLTWH(bubbleX, bubbleY, bubbleSize, bubbleSize));
    
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: _openSettings,
            color: Colors.grey[600],
          ),
          title: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            onDoubleTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            child: const Text(
              '消息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: _closeChat,
            color: Colors.grey[600],
          ),
        ],
        ),
        body: Column(
        children: [
          NewsPushBanner(news: _news),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final int actualIndex = _messages.length - 1 - index;
                final ChatMessage msg = _messages[actualIndex];
                final ChatMessage? prevMsg = actualIndex > 0 ? _messages[actualIndex - 1] : null;
                
                final bool showTimeSeparator = prevMsg != null && 
                    msg.timestamp.difference(prevMsg.timestamp).inMinutes >= 5;
                
                return Column(
                  children: [
                    if (showTimeSeparator)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    if (msg.type == MessageType.news)
                      NewsMessageBubble(message: msg)
                    else
                      ChatBubble(message: msg),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 0.5, color: Color(0xFFE5E5EA)),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFAEAEB2),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          height: 1.2,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        minLines: 1,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        cursorHeight: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A84FF), Color(0xFF5AC8FA)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      ),
      ),
    );
  }
}

class NewsPushBanner extends StatefulWidget {
  const NewsPushBanner({required this.news, super.key});

  final List<NewsItem> news;

  @override
  State<NewsPushBanner> createState() => _NewsPushBannerState();
}

class _NewsPushBannerState extends State<NewsPushBanner> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 可点击的标题栏
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '今日新闻推送',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // 新闻内容（可折叠）
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.news.isEmpty)
                    const Text(
                      '暂无新闻数据',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else
                    ...widget.news.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.content,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMine) ...[
            const SizedBox(width: 4),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/avatar1.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: CustomPaint(
              painter: message.isMine 
                  ? SentMessageBubblePainter()
                  : ReceivedMessageBubblePainter(),
              child: Container(
                padding: EdgeInsets.only(
                  left: message.isMine ? 16 : 20,
                  right: message.isMine ? 20 : 16,
                  top: 10,
                  bottom: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: message.isMine
                      ? const LinearGradient(
                          colors: [Color(0xFF0A84FF), Color(0xFF5AC8FA)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: message.isMine ? null : const Color(0xFFE5E5EA),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    color: message.isMine ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          if (message.isMine) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: ClipOval(
                child: Image.asset(
                  SettingsManager().settings.avatarPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class SentMessageBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0A84FF);
    final path = Path();
    
    path.moveTo(size.width - 8, size.height - 16);
    path.lineTo(size.width, size.height - 12);
    path.lineTo(size.width - 8, size.height - 8);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ReceivedMessageBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE5E5EA);
    final path = Path();
    
    path.moveTo(8, size.height - 16);
    path.lineTo(0, size.height - 12);
    path.lineTo(8, size.height - 8);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class NewsMessageBubble extends StatelessWidget {
  const NewsMessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange,
            ),
            child: const Icon(
              Icons.article,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.blue[600], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          message.newsTitle ?? '新闻推送',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    message.newsContent ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                  if (message.newsTitleZh != null || message.newsContentZh != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      message.newsTitleZh ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      message.newsContentZh ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MessageType { chat, news }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isMine,
    this.type = MessageType.chat,
    this.newsTitle,
    this.newsContent,
    this.newsTitleZh,
    this.newsContentZh,
    this.newsPageContent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isMine;
  final MessageType type;
  final String? newsTitle;
  final String? newsContent;
  final String? newsTitleZh;
  final String? newsContentZh;
  final String? newsPageContent;
  final DateTime timestamp;
}

class NewsItem {
  NewsItem({
    required this.title,
    required this.content,
    this.titleZh,
    this.contentZh,
    this.pageContent,
  });

  final String title;
  final String content;
  final String? titleZh;
  final String? contentZh;
  final String? pageContent;
}

// ==================== 用户设置 ====================

class UserSettings {
  String avatarPath;
  String interest;
  int newsIntervalMinutes;
  bool hasCompletedSetup;

  UserSettings({
    this.avatarPath = 'assets/images/avatar2.png',
    this.interest = 'AI',
    this.newsIntervalMinutes = 30,
    this.hasCompletedSetup = false,
  });

  Map<String, dynamic> toJson() => {
    'avatarPath': avatarPath,
    'interest': interest,
    'newsIntervalMinutes': newsIntervalMinutes,
    'hasCompletedSetup': hasCompletedSetup,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    avatarPath: json['avatarPath'] ?? 'assets/images/avatar2.png',
    interest: json['interest'] ?? 'AI',
    newsIntervalMinutes: json['newsIntervalMinutes'] ?? 30,
    hasCompletedSetup: json['hasCompletedSetup'] ?? false,
  );
}

// 全局设置管理
class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  UserSettings settings = UserSettings();
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  Future<void> loadSettings() async {
    try {
      final appDataDir = Directory.systemTemp;
      final file = File('${appDataDir.path}/flutter_chat/settings.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);
        settings = UserSettings.fromJson(json);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载设置失败: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final appDataDir = Directory.systemTemp;
      final dir = Directory('${appDataDir.path}/flutter_chat');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/settings.json');
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }
}

// ==================== 初始设置页面（只展示一次） ====================

class InitialSetupPage extends StatefulWidget {
  const InitialSetupPage({super.key});

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  int _currentStep = 0;
  String _selectedAvatar = 'assets/images/avatar2.png';
  String _selectedInterest = 'AI';
  double _newsInterval = 30;

  final List<String> _interests = ['AI', '科技', '财经', '体育', '娱乐', '健康'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => _backToBubble(),
            color: Colors.grey[600],
          ),
          title: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            child: const Text(
              '初始设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 进度指示器
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(0, '头像'),
                    _buildStepLine(0),
                    _buildStepIndicator(1, '兴趣'),
                    _buildStepLine(1),
                    _buildStepIndicator(2, '推送'),
                  ],
                ),
              ),
              // 内容区域
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('上一步', style: TextStyle(fontSize: 16, color: Color(0xFF0A84FF))),
                      )
                    else
                      const SizedBox(width: 80),
                    Row(
                      children: [
                        if (_currentStep < 2)
                          TextButton(
                            onPressed: () => _finishSetup(),
                            child: const Text('跳过', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_currentStep < 2) {
                              setState(() => _currentStep++);
                            } else {
                              _finishSetup();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(_currentStep < 2 ? '下一步' : '完成', style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step <= _currentStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0A84FF) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? const Color(0xFF0A84FF) : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = step < _currentStep;
    return Expanded(
      child: Container(
        height: 36,
        alignment: Alignment.center,
        child: Container(
          height: 2,
          color: isActive ? const Color(0xFF0A84FF) : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildAvatarStep();
      case 1:
        return _buildInterestStep();
      case 2:
        return _buildIntervalStep();
      default:
        return _buildAvatarStep();
    }
  }

  // 步骤1：选择头像（macOS风格并排显示）
  Widget _buildAvatarStep() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '选择一个头像',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '这将作为您在聊天中的头像显示',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarOption('assets/images/avatar2.png', '头像 1'),
              const SizedBox(width: 40),
              _buildAvatarOption('assets/images/avatar3.png', '头像 2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOption(String path, String label) {
    final isSelected = _selectedAvatar == path;
    return GestureDetector(
      onTap: () => setState(() => _selectedAvatar = path),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                path,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 步骤2：选择感兴趣的方向
  Widget _buildInterestStep() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '您感兴趣的方向？',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '我们将为您推送相关领域的新闻',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 50),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _interests.map((interest) => _buildInterestChip(interest)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestChip(String interest) {
    final isSelected = _selectedInterest == interest;
    return GestureDetector(
      onTap: () => setState(() => _selectedInterest = interest),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A84FF) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          interest,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // 步骤3：新闻推送间隔
  Widget _buildIntervalStep() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '新闻推送频率',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '我们将按此频率为您推送最新行业简报',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_newsInterval.toInt()} 分钟',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A84FF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '每 ${_newsInterval.toInt()} 分钟推送一次新消息',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Slider(
                  value: _newsInterval,
                  min: 10,
                  max: 120,
                  divisions: 11,
                  activeColor: const Color(0xFF0A84FF),
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (value) => setState(() => _newsInterval = value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('10分钟', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    Text('120分钟', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _finishSetup() async {
    final manager = SettingsManager();
    manager.settings.avatarPath = _selectedAvatar;
    manager.settings.interest = _selectedInterest;
    manager.settings.newsIntervalMinutes = _newsInterval.toInt();
    manager.settings.hasCompletedSetup = true; // 标记已完成初始设置
    await manager.saveSettings();
    manager.notifyListeners();

    // 初始设置完成后，回到悬浮窗
    _backToBubble();
  }

  void _backToBubble() async {
    // 恢复悬浮窗大小
    const double bubbleSize = 120;
    final Rect currentBounds = await windowManager.getBounds();
    
    await windowManager.setMinimumSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setMaximumSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setSize(const Size(bubbleSize, bubbleSize));
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(false);
    await windowManager.setBounds(Rect.fromLTWH(
      currentBounds.left + (currentBounds.width - bubbleSize) / 2,
      currentBounds.top + (currentBounds.height - bubbleSize) / 2,
      bubbleSize,
      bubbleSize,
    ));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ==================== Tab设置页面（从聊天页进入） ====================

class SettingsTabPage extends StatefulWidget {
  const SettingsTabPage({super.key});

  @override
  State<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends State<SettingsTabPage> {
  int _currentTab = 0;
  late String _selectedAvatar;
  late String _selectedInterest;
  late double _newsInterval;

  final List<String> _interests = ['AI', '科技', '财经', '体育', '娱乐', '健康'];

  @override
  void initState() {
    super.initState();
    final settings = SettingsManager().settings;
    _selectedAvatar = settings.avatarPath;
    _selectedInterest = settings.interest;
    _newsInterval = settings.newsIntervalMinutes.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => _backToChat(),
            color: Colors.grey[600],
          ),
          title: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            child: const Text(
              '个人设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Tab栏
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTab(0, '头像'),
                  _buildTab(1, '兴趣'),
                  _buildTab(2, '推送'),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0A84FF) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildAvatarTab();
      case 1:
        return _buildInterestTab();
      case 2:
        return _buildIntervalTab();
      default:
        return _buildAvatarTab();
    }
  }

  Widget _buildAvatarTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '选择头像',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarOption('assets/images/avatar2.png', '头像 1'),
              const SizedBox(width: 40),
              _buildAvatarOption('assets/images/avatar3.png', '头像 2'),
            ],
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () {
              _saveCurrentTabSettings();
              // 停留在当前页面，可以切换到其他tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('完成', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOption(String path, String label) {
    final isSelected = _selectedAvatar == path;
    return GestureDetector(
      onTap: () => setState(() => _selectedAvatar = path),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                path,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '感兴趣的方向',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选择您感兴趣的领域',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _interests.map((interest) => _buildInterestChip(interest)).toList(),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () {
              _saveCurrentTabSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('完成', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestChip(String interest) {
    final isSelected = _selectedInterest == interest;
    return GestureDetector(
      onTap: () => setState(() => _selectedInterest = interest),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A84FF) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          interest,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            '推送频率',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设置新闻推送的时间间隔',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_newsInterval.toInt()} 分钟',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A84FF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '每 ${_newsInterval.toInt()} 分钟推送一次',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _newsInterval,
                  min: 10,
                  max: 120,
                  divisions: 11,
                  activeColor: const Color(0xFF0A84FF),
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (value) => setState(() => _newsInterval = value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('10分钟', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    Text('120分钟', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 清除缓存按钮
          TextButton.icon(
            onPressed: () => _showClearCacheDialog(),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text(
              '清除所有缓存',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              _saveCurrentTabSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('完成', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有聊天记录和设置吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCache() async {
    try {
      // 删除缓存目录
      final appDataDir = Directory.systemTemp;
      final chatDir = Directory('${appDataDir.path}/flutter_chat');
      if (await chatDir.exists()) {
        await chatDir.delete(recursive: true);
      }

      // 重置设置
      final manager = SettingsManager();
      manager.settings = UserSettings();
      await manager.saveSettings();
      manager.notifyListeners();

      // 更新本地状态
      setState(() {
        _selectedAvatar = manager.settings.avatarPath;
        _selectedInterest = manager.settings.interest;
        _newsInterval = manager.settings.newsIntervalMinutes.toDouble();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存已清除'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF0A84FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除缓存失败: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveCurrentTabSettings() async {
    final manager = SettingsManager();
    manager.settings.avatarPath = _selectedAvatar;
    manager.settings.interest = _selectedInterest;
    manager.settings.newsIntervalMinutes = _newsInterval.toInt();
    await manager.saveSettings();
    manager.notifyListeners();

    // 显示保存成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF0A84FF),
      ),
    );
  }

  void _backToChat() async {
    // 保存设置
    _saveCurrentTabSettings();

    // 恢复聊天窗口大小
    const double chatWidth = 640;
    const double chatHeight = 720;
    final Rect currentBounds = await windowManager.getBounds();
    
    await windowManager.setMinimumSize(const Size(chatWidth, chatHeight));
    await windowManager.setMaximumSize(const Size(chatWidth, chatHeight));
    await windowManager.setSize(const Size(chatWidth, chatHeight));
    await windowManager.setBackgroundColor(const Color(0xFFF2F2F7));
    await windowManager.setHasShadow(true);
    await windowManager.setBounds(Rect.fromLTWH(
      currentBounds.left + (currentBounds.width - chatWidth) / 2,
      currentBounds.top + (currentBounds.height - chatHeight) / 2,
      chatWidth,
      chatHeight,
    ));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}


