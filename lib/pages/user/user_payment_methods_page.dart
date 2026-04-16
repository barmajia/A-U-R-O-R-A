import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';

/// User Payment Methods Page
/// Manage saved payment options
class UserPaymentMethodsPage extends StatefulWidget {
  const UserPaymentMethodsPage({super.key});

  @override
  State<UserPaymentMethodsPage> createState() => _UserPaymentMethodsPageState();
}

class _UserPaymentMethodsPageState extends State<UserPaymentMethodsPage> {
  List<PaymentMethod> _paymentMethods = [];
  String? _defaultPaymentId;
  bool _isLoading = false; // Set to false since we're using stub data

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);

    // TODO: Connect to backend when getUserPaymentMethods is implemented
    // Stub data for now
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _paymentMethods = [];
      _isLoading = false;
    });
  }

  Future<void> _setDefaultPayment(String paymentId) async {
    // TODO: Connect to backend when setDefaultPaymentMethod is implemented
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _defaultPaymentId = paymentId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default payment method updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deletePayment(String paymentId) async {
    // TODO: Connect to backend when deletePaymentMethod is implemented
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _paymentMethods.removeWhere((m) => m.id == paymentId);
        if (_defaultPaymentId == paymentId) {
          _defaultPaymentId =
              _paymentMethods.isNotEmpty ? _paymentMethods.first.id : null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment method removed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAddPaymentDialog() {
    final cardNumberController = TextEditingController();
    final cardNameController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Payment Method'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Preview
              _buildCardPreview(
                cardNumberController.text,
                cardNameController.text,
                expiryController.text,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cardNameController,
                decoration: InputDecoration(
                  labelText: 'Cardholder Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment method added'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadPaymentMethods();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview(
    String cardNumber,
    String cardName,
    String expiry,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.credit_card, color: Colors.white, size: 32),
              const Text(
                'VISA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            cardNumber.isEmpty ? '•••• •••• •••• ••••' : cardNumber,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARDHOLDER',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    cardName.isEmpty ? 'YOUR NAME' : cardName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    expiry.isEmpty ? 'MM/YY' : expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String paymentId, String cardLast4) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Remove Card'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the card ending in ••••$cardLast4?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePayment(paymentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      drawer: const AppDrawer(currentPage: 'payments'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
          ? _buildEmptyView()
          : _buildPaymentList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No payment methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a card to make payments easier',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddPaymentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Payment Method'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return _buildPaymentCard(method);
      },
    );
  }

  Widget _buildPaymentCard(PaymentMethod method) {
    final isDefault = method.id == _defaultPaymentId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isDefault ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Card Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getCardColor(method.cardType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.credit_card,
                color: _getCardColor(method.cardType),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Card Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '•••• •••• •••• ${method.last4Digits}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${method.cardType} • Expires ${method.expiryDate}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmation(method.id, method.last4Digits);
                } else if (value == 'default' && !isDefault) {
                  _setDefaultPayment(method.id);
                }
              },
              itemBuilder: (context) => [
                if (!isDefault)
                  const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Colors.blue;
      case 'mastercard':
        return Colors.orange;
      case 'amex':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// Payment Method Model
class PaymentMethod {
  final String id;
  final String cardType;
  final String last4Digits;
  final String expiryDate;
  final String cardholderName;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.cardType,
    required this.last4Digits,
    required this.expiryDate,
    required this.cardholderName,
    this.isDefault = false,
  });

  factory PaymentMethod.empty() {
    return PaymentMethod(
      id: '',
      cardType: '',
      last4Digits: '',
      expiryDate: '',
      cardholderName: '',
    );
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] ?? '',
      cardType: map['card_type'] ?? 'Unknown',
      last4Digits: map['last_4_digits'] ?? '0000',
      expiryDate: map['expiry_date'] ?? 'MM/YY',
      cardholderName: map['cardholder_name'] ?? '',
      isDefault: map['is_default'] ?? false,
    );
  }
}
