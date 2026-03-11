import 'package:aurora/models/chat/deal_proposal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dialog for creating a new deal proposal
class DealProposalFormDialog extends StatefulWidget {
  final String recipientId;
  final String conversationId;
  final Function(DealProposalFormData) onSubmit;

  const DealProposalFormDialog({
    Key? key,
    required this.recipientId,
    required this.conversationId,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<DealProposalFormDialog> createState() => _DealProposalFormDialogState();
}

class _DealProposalFormDialogState extends State<DealProposalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commissionController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _termsController = TextEditingController();
  DateTime? _expiresAt;

  @override
  void dispose() {
    _commissionController.dispose();
    _minOrderController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.handshake, size: 28),
          SizedBox(width: 12),
          Text('Create Deal Proposal'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Propose a commission deal to ${widget.recipientId.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Commission Rate
              Text(
                'Commission Rate *',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commissionController,
                decoration: InputDecoration(
                  hintText: 'e.g., 10',
                  prefixText: '',
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0 || rate > 100) {
                    return 'Must be 0-100';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Min Order Quantity
              Text(
                'Min Order Quantity',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minOrderController,
                decoration: InputDecoration(
                  hintText: 'e.g., 100 (optional)',
                  suffixText: 'units',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              // Terms
              Text(
                'Terms & Conditions',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _termsController,
                decoration: InputDecoration(
                  hintText: 'Payment terms, delivery, etc. (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 16),

              // Expiry Date
              Text(
                'Expires At',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _expiresAt = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _expiresAt != null
                            ? DateFormat('MMMM dd, yyyy').format(_expiresAt!)
                            : 'No expiry set (optional)',
                        style: TextStyle(
                          color: _expiresAt != null
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const Spacer(),
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() => _expiresAt = null);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Leave empty for no expiration',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit(
                DealProposalFormData(
                  commissionRate: double.parse(_commissionController.text),
                  minOrderQuantity: int.tryParse(_minOrderController.text),
                  terms: _termsController.text.isEmpty
                      ? null
                      : _termsController.text,
                  expiresAt: _expiresAt,
                ),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
          child: const Text('Send Proposal'),
        ),
      ],
    );
  }
}