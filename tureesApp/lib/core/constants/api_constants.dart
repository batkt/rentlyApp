class ApiConstants {
  static const String baseUrl = 'https://turees.zevtabs.mn/api';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth
  static const String login = '/khariltsagchNevtrey';
  static const String loginWithOrg = '/khariltsagchBaiguullagaarNevtrey';
  static const String verifyPhone = '/khariltsagchUtasShalgakh';
  static const String getUserByToken = '/tokenoorKhariltsagchAvya';
  static const String resetPasswordCheck = '/khariltsagchNuutsUgSolikh';
  static const String khariltsagch = '/khariltsagch';

  // Organization
  static const String organization = '/baiguullaga';

  // Agreement
  static const String geree = '/geree';
  static const String gereeBalance = '/gereeniiToololtAvya';
  static const String uldegdelBodyo = '/uldegdelBodyo';
  static const String saveTransaction = '/tulultOlnoorKhadgalya';
  static const String deleteTransaction = '/tulultUstgaya';

  // Payment
  static const String qpayGenerate = '/qpayGargaya';
  static const String qpayVerify = '/qpayShalgay';
  static const String qpayAmount = '/qpayGuilgeeUtgaAvya';
  static const String invoiceHistory = '/nekhemjlekhiinTuukh';
  static const String dans = '/dans';

  // Chat
  static const String conversations = '/chat/conversations';
  static String conversationMessages(String id) => '/chat/conversations/$id/messages';
  static String markConversationRead(String id) => '/chat/conversations/$id/read';

  // Notifications
  static const String notifications = '/sonorduulga';

  // Tasks
  static const String tasks = '/daalgavar';
  static const String submitTask = '/daalgavarOruulya';
  static const String acceptTask = '/daalgavarKhuleejAvlaa';
  static const String completeTask = '/daalgavarDuusgalaa';
  static const String cancelTask = '/daalgavarTsutsalya';

  // Duudlaga (calls/requests)
  static const String duudlagaKhadgalya = '/appWebDuudlagaKhadgalya';
  static String duudlagaTuluv(String id) => '/medegdel/$id';

  // Upload
  static const String upload = '/upload';

  // Feedback
  static const String feedback = '/sanalKhadgalya';
}

class StorageKeys {
  static const String token = 'tureestoken';
  static const String userRole = 'zochinTurul';
  static const String orgId = 'baiguullagiinId';
  static const String buildingId = 'barilgiinId';
  static const String userId = 'ezenId';
  static const String phone = 'utas';
  static const String userName = 'userName';
  static const String userRegister = 'userRegister';
}

class SocketEvents {
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String newMessage = 'newMessage';
  static const String newNotification = 'newNotification';
  static const String paymentComplete = 'paymentComplete';

  static String orgRoom(String orgId) => 'baiguullaga$orgId';
  static String userRoom(String userId) => 'khariltsagch$userId';
  static String qpayRoom(String orgId, String invoiceId) => 'qpay/$orgId/$invoiceId';
}
