import 'package:flutter/material.dart';
import '../../models/client.dart';

class ClientDetailScreen extends StatelessWidget {
  final ClientModel client;

  const ClientDetailScreen({
    super.key,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(client.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${client.email}'),
            // add whatever other ClientModel fields you want to show
          ],
        ),
      ),
    );
  }
}