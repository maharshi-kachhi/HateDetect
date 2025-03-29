import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:hate_speech/DBhelper/mongodb.dart';
import 'package:hate_speech/Screens/HistoryDrawer.dart';
import 'package:hate_speech/Utils/themeProvider.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String text;
  final bool isUser;
  final String category;

  Message({required this.text, required this.isUser, required this.category});

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'category': category,
    };
  }
}

class HateSpeechScreen extends StatefulWidget {
  final String userName;

  const HateSpeechScreen({super.key, required this.userName});

  @override
  _HateSpeechScreenState createState() => _HateSpeechScreenState();
}

class _HateSpeechScreenState extends State<HateSpeechScreen> {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  List<Message> _messages = [];
  String _chatName = "New Chat";
  String? _chatId; // 🔹 Nullable Chat ID
  List<Map<String, dynamic>> _chatSession = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  /// **🔹 Generate Unique Chat ID**
  String generateChatId() {
    final Random random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        "-" +
        random.nextInt(10000).toString();
  }

  String _extractChatName(String text) {
    List<String> words = text.split(" ");
    if (words.length >= 3) {
      return words.sublist(0, 3).join(" "); // Take first 3 words
    } else {
      return words.join(" "); // If less than 3 words, return all words
    }
  }

  /// **🔹 Detect Hate Speech & Store Chat History**
  /// **🔹 Detect Hate Speech & Store Chat History**
  static const String API_KEY = "AIzaSyDX1NAuegzLUc8SPHF_bTbRdxFV8YqMf3Y";
  static const String API_URL =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-thinking-exp:generateContent?key=$API_KEY";
  void _detectHateSpeech() async {
    String inputText = _textController.text.trim();
    if (inputText.isEmpty) {
      handleError("Please enter or speak text before detecting.");
      return;
    }

    setState(() {
      // Add user input to messages list
      Message userMessage =
          Message(text: inputText, isUser: true, category: "User Input");
      _messages.add(userMessage);
    });

    _textController.clear();

    try {
      // Check for existing chat ID
      print("📝 Checking for existing chat ID: $_chatId");

      if (_chatId?.isEmpty ?? true) {
        // If no existing chatId, create a new one
        _chatId = generateChatId();

        // Extract first 2-3 words from input as chat name
        _chatName = _extractChatName(inputText);
        print(
            "⚠️ No existing chat. Creating new chat ID: $_chatId with name: $_chatName");
      }

      // Send request to Gemini API (or any similar hate speech detection API)
      final response = await http.post(
        Uri.parse(API_URL), // Replace with the Gemini API URL
        headers: {
          "Content-Type": "application/json",
          "Authorization": "API_KEY", // Ensure you add your actual API key here
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "Classify the following text as one of the three categories: 'No Hate Speech', 'Offensive Language', or 'Hate Speech'. Just answer in one word, no explanation.\n\nText: $inputText"
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        var responseBody = jsonDecode(response.body);
        String responseText =
            responseBody["candidates"][0]["content"]["parts"][0]["text"].trim();

        setState(() {
          // Add the bot's response to the messages list
          Message botResponse = Message(
              text: responseText, isUser: false, category: responseText);

          _messages.add(botResponse);

          // Save the chat session to MongoDB
          List<Map<String, dynamic>> newMessages = [
            {'text': inputText, 'isUser': true, 'category': "User Input"},
            {'text': responseText, 'isUser': false, 'category': responseText}
          ];

          // Store the chat session under the chat ID
          print("📡 Storing messages in MongoDB under Chat ID: $_chatId");
          mongodb.insertOrUpdateChat(
              widget.userName, _chatId!, _chatName, newMessages);
        });
      } else {
        print("❌ Error: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  /// **🔹 Speech Recognition Start**
  void _startListening() async {
    try {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
        );
      }
    } catch (e) {
      handleError("Error starting speech recognition: $e");
    }
  }

  /// **🔹 Stop Listening**
  void _stopListening() {
    try {
      setState(() => _isListening = false);
      _speech.stop();
    } catch (e) {
      handleError("Error stopping speech recognition: $e");
    }
  }

  void handleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hate Speech Detector 🚀"),
        backgroundColor: isDarkMode ? Colors.black : Colors.blueAccent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      drawer: HistoryDrawer(
        userName: widget.userName,
        onSelectHistory: (chatSession, chatName, chatId) {
          setState(() {
            _chatName = chatName;
            _chatId = chatId; // 🔹 Restore chatId
            _messages = chatSession
                .map((msg) => Message(
                      text: msg['text'],
                      isUser: msg['isUser'],
                      category: msg['category'],
                    ))
                .toList();
          });
        },
        onLogout: () {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
          handleError("Logged out successfully.");
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDarkMode ? Colors.black : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Type something...",
                      hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.black),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.blue),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _detectHateSpeech,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// **🔹 Chat UI Message**
  Widget _buildMessage(Message message) {
    Color bgColor;

    if (!message.isUser) {
      switch (message.text.trim()) {
        case "Hate Speech":
          bgColor = Colors.red; // 🔴 Hate Speech
          break;
        case "Offensive Language":
          bgColor = Colors.yellow; // 🟡 Offensive Language
          break;
        case "No Hate Speech":
          bgColor = Colors.green; // 🟢 No Hate Speech
          break;
        default:
          bgColor = Colors.grey; // Unknown response
      }
    } else {
      bgColor = Colors.blueAccent.withOpacity(0.8); // User input color
    }

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.text,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
