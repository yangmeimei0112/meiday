enum GroceryCategory {
  produce('生鮮蔬果', '🥦'),
  dairy('乳製品與蛋', '🥛'),
  meat('肉類與海鮮', '🥩'),
  bakery('烘焙與主食', '🍞'),
  pantry('罐頭與調料', '🥫'),
  beverages('飲品與零食', '🧃'),
  household('生活日用品', '🧴'),
  other('其他未分類', '📌');

  final String displayName;
  final String emoji;
  const GroceryCategory(this.displayName, this.emoji);

  static GroceryCategory fromName(String? name) {
    if (name == null || name.isEmpty) return GroceryCategory.other;
    for (final cat in GroceryCategory.values) {
      if (cat.name.toLowerCase() == name.toLowerCase() ||
          cat.displayName == name ||
          cat.emoji == name) {
        return cat;
      }
    }
    return GroceryCategory.other;
  }
}

class GroceryCategoryClassifier {
  static final Map<String, GroceryCategory> _dictionary = {
    // Produce
    'apple': GroceryCategory.produce,
    'banana': GroceryCategory.produce,
    'tomato': GroceryCategory.produce,
    'vegetable': GroceryCategory.produce,
    'carrot': GroceryCategory.produce,
    'onion': GroceryCategory.produce,
    'potato': GroceryCategory.produce,
    'lettuce': GroceryCategory.produce,
    '蘋果': GroceryCategory.produce,
    '香蕉': GroceryCategory.produce,
    '番茄': GroceryCategory.produce,
    '青菜': GroceryCategory.produce,
    '胡蘿蔔': GroceryCategory.produce,
    '洋蔥': GroceryCategory.produce,
    '馬鈴薯': GroceryCategory.produce,
    '蔬菜': GroceryCategory.produce,
    '水果': GroceryCategory.produce,

    // Dairy
    'milk': GroceryCategory.dairy,
    'egg': GroceryCategory.dairy,
    'cheese': GroceryCategory.dairy,
    'yogurt': GroceryCategory.dairy,
    'butter': GroceryCategory.dairy,
    'cream': GroceryCategory.dairy,
    '鮮奶': GroceryCategory.dairy,
    '牛奶': GroceryCategory.dairy,
    '雞蛋': GroceryCategory.dairy,
    '蛋': GroceryCategory.dairy,
    '起司': GroceryCategory.dairy,
    '乳酪': GroceryCategory.dairy,
    '優格': GroceryCategory.dairy,
    '奶油': GroceryCategory.dairy,

    // Meat
    'beef': GroceryCategory.meat,
    'chicken': GroceryCategory.meat,
    'pork': GroceryCategory.meat,
    'fish': GroceryCategory.meat,
    'salmon': GroceryCategory.meat,
    'shrimp': GroceryCategory.meat,
    'steak': GroceryCategory.meat,
    '牛肉': GroceryCategory.meat,
    '雞肉': GroceryCategory.meat,
    '豬肉': GroceryCategory.meat,
    '魚': GroceryCategory.meat,
    '鮭魚': GroceryCategory.meat,
    '蝦': GroceryCategory.meat,
    '牛排': GroceryCategory.meat,
    '肉': GroceryCategory.meat,

    // Bakery
    'bread': GroceryCategory.bakery,
    'toast': GroceryCategory.bakery,
    'rice': GroceryCategory.bakery,
    'noodles': GroceryCategory.bakery,
    'pasta': GroceryCategory.bakery,
    'croissant': GroceryCategory.bakery,
    '麵包': GroceryCategory.bakery,
    '吐司': GroceryCategory.bakery,
    '白米': GroceryCategory.bakery,
    '米': GroceryCategory.bakery,
    '麵條': GroceryCategory.bakery,
    '義大利麵': GroceryCategory.bakery,

    // Pantry
    'oil': GroceryCategory.pantry,
    'olive oil': GroceryCategory.pantry,
    'salt': GroceryCategory.pantry,
    'sugar': GroceryCategory.pantry,
    'pepper': GroceryCategory.pantry,
    'sauce': GroceryCategory.pantry,
    'soy sauce': GroceryCategory.pantry,
    'flour': GroceryCategory.pantry,
    '油': GroceryCategory.pantry,
    '沙拉油': GroceryCategory.pantry,
    '橄欖油': GroceryCategory.pantry,
    '鹽': GroceryCategory.pantry,
    '糖': GroceryCategory.pantry,
    '胡椒': GroceryCategory.pantry,
    '醬油': GroceryCategory.pantry,
    '醋': GroceryCategory.pantry,
    '麵粉': GroceryCategory.pantry,

    // Beverages
    'coffee': GroceryCategory.beverages,
    'tea': GroceryCategory.beverages,
    'juice': GroceryCategory.beverages,
    'coke': GroceryCategory.beverages,
    'soda': GroceryCategory.beverages,
    'beer': GroceryCategory.beverages,
    'chips': GroceryCategory.beverages,
    'snack': GroceryCategory.beverages,
    '咖啡': GroceryCategory.beverages,
    '茶': GroceryCategory.beverages,
    '果汁': GroceryCategory.beverages,
    '可樂': GroceryCategory.beverages,
    '汽水': GroceryCategory.beverages,
    '啤酒': GroceryCategory.beverages,
    '洋芋片': GroceryCategory.beverages,
    '零食': GroceryCategory.beverages,

    // Household
    'toilet paper': GroceryCategory.household,
    'tissue': GroceryCategory.household,
    'soap': GroceryCategory.household,
    'detergent': GroceryCategory.household,
    'shampoo': GroceryCategory.household,
    'toothpaste': GroceryCategory.household,
    'trash bag': GroceryCategory.household,
    '衛生紙': GroceryCategory.household,
    '面紙': GroceryCategory.household,
    '肥皂': GroceryCategory.household,
    '洗衣精': GroceryCategory.household,
    '洗碗精': GroceryCategory.household,
    '洗髮精': GroceryCategory.household,
    '牙膏': GroceryCategory.household,
    '垃圾袋': GroceryCategory.household,
  };

  static GroceryCategory classify(String text) {
    final lower = text.toLowerCase().trim();
    for (final entry in _dictionary.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return GroceryCategory.other;
  }
}
