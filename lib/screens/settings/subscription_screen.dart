import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/purchase_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _service = PurchaseService();
  Offerings? _offerings;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _offerings = await _service.getOfferings();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _buy(Package package) async {
    setState(() => _busy = true);
    try {
      await _service.purchase(package);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscribed! Thank you.')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Purchase could not be completed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = _offerings?.current?.availablePackages ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : packages.isEmpty
          ? const Center(child: Text('No plans available right now.'))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: packages
            .map((p) => Card(
          child: ListTile(
            title: Text(p.storeProduct.title),
            subtitle: Text(p.storeProduct.description),
            trailing: Text(p.storeProduct.priceString,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: _busy ? null : () => _buy(p),
          ),
        ))
            .toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                final messenger = ScaffoldMessenger.of(context);
                await _service.restore();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Purchases restored.')),
                );
              },
            child: const Text('Restore purchases'),
          ),
        ),
      ),
    );
  }
}