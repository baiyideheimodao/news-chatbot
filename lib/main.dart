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

  void _openChatWindow() async {
    // 获取当前悬浮窗的位置
    final Rect currentBounds = await windowManager.getBounds();

    // 计算聊天窗口位置：悬浮窗右下角偏移一点
    const double chatWidth = 640;
    const double chatHeight = 720;
    const double offsetX = 20;
    const double offsetY = 20;

    double chatX = currentBounds.right + offsetX;
    double chatY = currentBounds.bottom + offsetY;

    // 简单边界检查（假设屏幕尺寸至少 1920x1080）
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
      onTap: _openChatWindow,
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
  String _chatBuffer = ''; // 新增：聊天缓冲区
  String _currentEvent = ''; // SSE 事件类型追踪
  DateTime? _lastNewsRequestTime; // 上次新闻请求时间

  @override
  void initState() {
    super.initState();
    _loadMessages(); // 加载本地聊天记录
    _initializeNews(); // 检查并初始化新闻
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkAndFetchNews()); // 定期检查是否需要更新
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
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
        newsLines.add('第${i + 1}条新闻：${_news[i].title}\n${_news[i].content}');
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
    
    // 如果没有上次请求时间，或者间隔超过轮询时间，则请求新闻
    if (_lastNewsRequestTime == null || 
        now.difference(_lastNewsRequestTime!).compareTo(pollInterval) >= 0) {
      debugPrint('满足新闻请求条件，准备获取新闻');
      await _fetchNews();
      await _saveLastNewsTime(now);
    } else {
      final remaining = pollInterval - now.difference(_lastNewsRequestTime!);
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
    final Uri uri = Uri.parse('$apiUrl?type=$newsType&limit=$newsLimit');
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
              );
              _news.add(newsItem);
              // 将新闻添加到聊天记录中
              _messages.add(ChatMessage(
                text: '',
                isMine: false,
                type: MessageType.news,
                newsTitle: newsItem.title,
                newsContent: newsItem.content,
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '信息',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFAEAEB2),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
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
    );
  }
}

class NewsPushBanner extends StatelessWidget {
  const NewsPushBanner({required this.news, super.key});

  final List<NewsItem> news;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.campaign, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                '今日新闻推送',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (news.isEmpty)
            const Text(
              '暂无新闻数据',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            )
          else
            ...news.map((item) => Padding(
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
                color: Colors.grey,
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
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
                child: Text(
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue[300],
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
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
                        child: Text(
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
                  Text(
                    message.newsContent ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
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
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isMine;
  final MessageType type;
  final String? newsTitle;
  final String? newsContent;
  final DateTime timestamp;
}

class NewsItem {
  NewsItem({required this.title, required this.content});

  final String title;
  final String content;
}
