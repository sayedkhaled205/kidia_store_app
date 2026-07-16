import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
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
