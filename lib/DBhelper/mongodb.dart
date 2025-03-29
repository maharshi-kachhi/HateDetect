import 'package:mongo_dart/mongo_dart.dart';

const MONGO_CONNECTION_URI =
    "YOUR_MONGO_CONNECTION_URL";
const USER_COLLECTION = "YOUR_COLLECTION_NAME";

class mongodb {
  static var db, userCollection, history;
  // foodCollection,
  // ordersCollection,
  // ownerCollection;

  // db = Db.create(MONGO_CONNECTION_URI);
  // db.open();
  // userCollection = db.collection(USER_COLLECTION);

  static connect() async {
    // Replace the connection string with your MongoDB URI
    db = await Db.create(MONGO_CONNECTION_URI);

    await db.open();

    // Replace 'users' with your collection name
    userCollection = db.collection('YOUR_COLLECTION_NAME');
    history = db.collection('YOUR_COLLECTION_NAME');
    //   // foodCollection = db.collection('FoodItems');
    //   // ordersCollection = db.collection('Orders');
    //   // ownerCollection = db.collection('Owner');

    print('DB connected');
  }

  static insertData(Map<String, dynamic> data) async {
    try {
      await userCollection.insert(data);
      print('Data successfully inserted into MongoDB');
    } catch (e) {
      print('Error during insertion: $e');
    }
  }
  // static insertHistoryData(Map<String, dynamic> historyData) async {
  //   try {
  //     await history.insert(historyData);
  //     print('History data successfully inserted into MongoDB');
  //   } catch (e) {
  //     print('Error inserting history data: $e');
  //   }
  // }

  static updatePassword(String email, String newPassword) async {
    try {
      var result = await userCollection.updateOne(
        where.eq(
            'email', email), // Assuming 'email' field is used to find the user
        modify.set('password', newPassword), // Assuming 'password' field exists
      );
      if (result.isSuccess) {
        print('Password updated successfully');
      } else {
        print('Failed to update password');
      }
    } catch (e) {
      print('Error updating password: $e');
    }
  }

  // static Future<List<Map<String, dynamic>>> getChatHistory(
  //     String userName) async {
  //   try {
  //     var historyList = await history
  //         .find(
  //             where.eq('user', userName).sortBy('timestamp', descending: true))
  //         .toList();
  //     return historyList.cast<Map<String, dynamic>>();
  //   } catch (e) {
  //     print("Error fetching chat history for $userName: $e");
  //     return [];
  //   }
  // }

  static Future<List<Map<String, dynamic>>> getHistoryData(
      String username) async {
    try {
      // Fetch all history documents for the given username from the 'history' collection.
      var historyList =
          await history.find(where.eq('username', username)).toList();
      return historyList.cast<Map<String, dynamic>>();
    } catch (e) {
      print("Error fetching history data for $username: $e");
      return [];
    }
  }

  static Future<void> insertHistoryData(
      String username, Map<String, dynamic> historyData) async {
    try {
      // Add the logged-in username to the history data.
      historyData['username'] = username;
      await history.insert(historyData);
      print('History data successfully inserted into MongoDB');
    } catch (e) {
      print('Error inserting history data: $e');
    }
  }

  static Future<void> insertChatHistory(String userName, String chatId,
      String chatName, List<Map<String, dynamic>> newMessages) async {
    try {
      var existingChat = await history.findOne({
        'user': userName,
        'chatId': chatId, // Ensure we check the chat ID, not just the name
      });

      if (existingChat != null) {
        // 🔹 Append new messages to the existing chat session
        List<dynamic> existingSession = existingChat['chatSession'] ?? [];
        existingSession.addAll(newMessages);

        await history.updateOne(
          where.eq('user', userName).eq('chatId', chatId),
          modify
              .set('chatSession', existingSession)
              .set('timestamp', DateTime.now().toIso8601String()),
        );

        print("✅ Chat updated successfully for '$chatName' (Chat ID: $chatId)");
      } else {
        // 🔹 Insert a new chat entry if it doesn't exist
        await history.insertOne({
          'user': userName,
          'chatId': chatId, // Use unique chat ID
          'chatName': chatName,
          'chatSession': newMessages,
          'timestamp': DateTime.now().toIso8601String(),
        });

        print("✅ New chat session created: $chatName (Chat ID: $chatId)");
      }
    } catch (e) {
      print("❌ Error storing chat history: $e");
    }
  }

  // static Future<List<Map<String, dynamic>>> getChatSession(
  //     String chatId) async {
  //   try {
  //     // Extract only the 24-character hex string from ObjectId
  //     if (chatId.contains("ObjectId")) {
  //       chatId = chatId
  //           .replaceAll(RegExp(r'ObjectId\("'), '')
  //           .replaceAll(RegExp(r'"\)'), '');
  //     }
  //     var chat = await history.findOne(where.id(ObjectId.parse(chatId)));
  //     if (chat != null && chat.containsKey('chatSession')) {
  //       return List<Map<String, dynamic>>.from(chat['chatSession']);
  //     }
  //     return [];
  //   } catch (e) {
  //     print("Error fetching chat session: $e");
  //     return [];
  //   }
  //}

  static Future<List<Map<String, dynamic>>> getChatSession(
      String chatId) async {
    try {
      var chat = await history.findOne(where.eq("_id", ObjectId.parse(chatId)));

      if (chat != null && chat.containsKey('chatSession')) {
        return List<Map<String, dynamic>>.from(chat['chatSession']);
      }
      return [];
    } catch (e) {
      print("Error fetching chat session: $e");
      return [];
    }
  }

  static Future<void> saveChatSession(
      String userName, String chatId, Map<String, dynamic> newMessage) async {
    try {
      var existingChat =
          await history.findOne(where.eq("_id", ObjectId.parse(chatId)));

      if (existingChat != null) {
        /// 🔹 Append new message to `chatSession`
        await history.updateOne(
          where.eq("_id", ObjectId.parse(chatId)),
          modify.push("chatSession", newMessage),
        );
      } else {
        /// 🔹 Create new chat session if not found
        await history.insertOne({
          "user": userName,
          "chatName": "New Chat",
          "chatSession": [newMessage],
          "timestamp": DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print("Error saving chat session: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getChatHistory(
      String userName) async {
    try {
      var chats = await history.find(where.eq("user", userName)).toList();

      // 🔹 Convert `_id` from ObjectId to string
      for (var chat in chats) {
        chat['_id'] = chat['_id'].toHexString(); // ✅ Convert ObjectId to string
      }

      return chats;
    } catch (e) {
      print("Error fetching chat history: $e");
      return [];
    }
  }

  static Future<void> insertOrUpdateChat(String userName, String? chatId,
      String chatName, List<Map<String, dynamic>> newMessages) async {
    try {
      ObjectId objectId;

      if (chatId != null && chatId.length == 24) {
        objectId = ObjectId.parse(chatId); // ✅ Convert to ObjectId
      } else {
        objectId = ObjectId(); // ✅ Generate a new ObjectId if needed
        chatId = objectId.toHexString();
        print(
            "! No existing chat. Creating new chat ID: $chatId with name: $chatName");
      }

      var existingChat = await history.findOne(where.eq("_id", objectId));

      if (existingChat != null) {
        print("🛠 Updating existing chat session with Chat ID: $chatId");

        // 🔹 Append new messages to the existing session
        List<Map<String, dynamic>> updatedMessages =
            List<Map<String, dynamic>>.from(existingChat['chatSession'] ?? []);
        updatedMessages.addAll(newMessages);

        await history.update(
          where.eq("_id", objectId),
          modify.set("chatSession", updatedMessages),
        );
      } else {
        print("🆕 Creating a new chat session for Chat ID: $chatId");

        await history.insert({
          "_id": objectId,
          "user": userName,
          "chatName": chatName,
          "chatSession": newMessages,
          "timestamp": DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print("❌ Error inserting or updating chat: $e");
    }
  }

  static Future<bool> renameChat(
      String userName, String chatId, String newChatName) async {
    try {
      var objectId = ObjectId.parse(chatId); // Ensure _id is an ObjectId

      final updateResult = await history.updateOne(
        where.id(objectId),
        modify.set("chatName", newChatName),
      );

      if (updateResult.isSuccess) {
        print("✅ Chat renamed successfully to '$newChatName'!");
        return true;
      } else {
        print("⚠️ No chat found with ID: $chatId or rename failed.");
        return false;
      }
    } catch (e) {
      print("❌ Error renaming chat: $e");
      return false;
    }
  }

  // static Future<void> insertChatHistory(String userName, String chatName,
  //     List<Map<String, dynamic>> chatSession) async {
  //   await history.insertOne({
  //     'user': userName,
  //     'chatName': chatName,
  //     'chatSession': chatSession,
  //     'timestamp': DateTime.now().toIso8601String(),
  //   });
  // }

  static Future<bool> deleteChat(String userName, String chatId) async {
    try {
      var objectId = ObjectId.parse(chatId); // Ensure valid ObjectId
      final result = await history.remove(where.eq("_id", objectId));

      if (result != null && result['nRemoved'] != null) {
        return result['nRemoved'] > 0; // ✅ Check if delete was successful
      } else {
        print("⚠️ No chat found to delete with ID: $chatId");
        return false;
      }
    } catch (e) {
      print("❌ Error deleting chat: $e");
      return false;
    }
  }

  static Future<void> updateHistoryData(
      String id, Map<String, dynamic> updatedData) async {
    try {
      final objectId = ObjectId.parse(id); // Convert string ID to ObjectId
      var result = await history.updateOne(
        where.id(objectId),
        modify.set('prompt', updatedData['prompt']), // Update the prompt field
      );
      if (result.isSuccess) {
        print('History updated successfully');
      } else {
        print('Failed to update history');
      }
    } catch (e) {
      print('Error updating history: $e');
    }
  }

  static Future<void> deleteHistoryData(String id) async {
    try {
      final objectId = ObjectId.parse(id); // Convert string ID to ObjectId
      var result = await history.deleteOne(where.id(objectId));
      if (result.isSuccess) {
        print('History deleted successfully');
      } else {
        print('Failed to delete history');
      }
    } catch (e) {
      print('Error deleting history: $e');
    }
  }

  // static ShowFooddata() async {
  //   try {
  //     // Fetch all documents from the collection
  //     var foodItems = await foodCollection.find().toList();

  //     // Print each document
  //     for (var item in foodItems) {
  //       print(item); // Prints the entire document
  //     }
  //   } catch (e) {
  //     print('Error fetching food items: $e');
  //   }
  // }

  // // Fetch distinct categories from FoodItems collection
  // static Future<List<String>> fetchCategories() async {
  //   try {
  //     var categories = await foodCollection.distinct('Category');
  //     return categories.cast<String>();
  //   } catch (e) {
  //     print('Error fetching categories: $e');
  //     return [];
  //   }
  // }

  // // Fetch food items based on the selected category
  // static Future<List<Map<String, dynamic>>> fetchFoodItems(
  //     String categoryId) async {
  //   try {
  //     var foodItems =
  //         await foodCollection.find({'Category': categoryId}).toList();
  //     return foodItems;
  //   } catch (e) {
  //     print('Error fetching food items: $e');
  //     return [];
  //   }
  // }
}





// static var db, userCollection;

  // static connect() async {
  //   // Replace the connection string with your MongoDB URI
  //   db = await Db.create("mongodb+srv://maharshi:200405@cluster0.mongodb.net/FoodApp_108?retryWrites=true&w=majority");

  //   await db.open();

  //   // Replace 'users' with your collection name
  //   userCollection = db.collection('Login_credentials');
  // }

  // static Future<List<Map<String, dynamic>>> getData() async {
  //   return await userCollection.find().toList();
  // }

  // static updateData(Map<String, dynamic> query, Map<String, dynamic> updateData) async {
  //   await userCollection.update(query, updateData);
  // }

  // static deleteData(Map<String, dynamic> query) async {
  //   await userCollection.remove(query);
  // }

  // static closeConnection() async {
  //   await db.close();
  // }





// import 'package:meal/dbHelper/Constant.dart';
// import 'package:mongo_dart/mongo_dart.dart';

// const MONGO_CONNECTION_URI = "mongodb+srv://maharshi:200405@cluster0.9rfuw.mongodb.net/";
// const USER_COLLECTION="Login_data";

// class mongodb
// {
//   static var db, USER_COLLECTION;
//   static connect() async{
//     db = await  Db.create(MONGO_CONNECTION_URI);
//     await db.open();
//     USER_COLLECTION = db.collection();
    
//   }
// }

