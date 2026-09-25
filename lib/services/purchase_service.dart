import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseService {
  static const _apiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';
  static const _entitlementId = 'pro';

  Future<void> configure() async {
    final user = Supabase.instance.client.auth.currentUser;
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(
      PurchasesConfiguration(_apiKeyAndroid)..appUserID = user?.id,
    );
  }

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<bool> isPro() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(_entitlementId);
  }

  Future<CustomerInfo> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restore() => Purchases.restorePurchases();
}