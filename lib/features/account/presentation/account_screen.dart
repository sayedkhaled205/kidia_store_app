import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.onWishlist});

  final VoidCallback? onWishlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('مرحبًا بك'),
              subtitle: Text('تصفّح المتجر واحفظ منتجاتك المفضلة'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('المفضلة'),
              subtitle: const Text('المنتجات المحفوظة على هذا الجهاز'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onWishlist,
            ),
          ),
          const Card(
            child: ListTile(
              enabled: false,
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('الطلبات والعناوين'),
              subtitle: Text('تحتاج تسجيل دخول WooCommerce آمن'),
            ),
          ),
        ],
      ),
    );
  }
}
