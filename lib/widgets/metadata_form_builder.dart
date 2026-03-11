import 'package:flutter/material.dart';
import 'package:aurora/models/product_metadata_template.dart';

/// Dynamic form builder that generates metadata fields based on category
class MetadataFormBuilder extends StatefulWidget {
  final ProductCategory category;
  final Map<String, dynamic> initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const MetadataFormBuilder({
    super.key,
    required this.category,
    this.initialData = const {},
    required this.onChanged,
  });

  @override
  State<MetadataFormBuilder> createState() => _MetadataFormBuilderState();
}

class _MetadataFormBuilderState extends State<MetadataFormBuilder> {
  late Map<String, dynamic> _formData;
  late MetadataTemplate _template;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _template = MetadataTemplate.getTemplate(widget.category);
    _formData = Map<String, dynamic>.from(widget.initialData);

    // Initialize form data with existing values or defaults
    for (var field in _template.fields) {
      if (!_formData.containsKey(field.key)) {
        _formData[field.key] = null;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notifyParent() {
    widget.onChanged(_formData);
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).primaryColor),
          ),
          child: Row(
            children: [
              Text(widget.category.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Specifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      widget.category.displayName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dynamic Fields
        ..._buildFieldGroups(),
      ],
    );
  }

  List<Widget> _buildFieldGroups() {
    // Group fields by category
    final Map<String?, List<MetadataField>> groupedFields = {};

    for (var field in _template.fields) {
      final group = field.category;
      if (!groupedFields.containsKey(group)) {
        groupedFields[group] = [];
      }
      groupedFields[group]!.add(field);
    }

    final widgets = <Widget>[];

    // Build fields for each group
    groupedFields.forEach((group, fields) {
      if (group != null) {
        widgets.add(_buildGroupHeader(group));
      }

      for (var field in fields) {
        widgets.add(_buildField(field));
      }
    });

    return widgets;
  }

  Widget _buildGroupHeader(String groupName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        groupName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildField(MetadataField field) {
    // Get existing value
    final existingValue = _formData[field.key];

    switch (field.type) {
      case FieldType.text:
        return _buildTextField(field, existingValue);

      case FieldType.number:
        return _buildNumberField(field, existingValue);

      case FieldType.decimal:
        return _buildDecimalField(field, existingValue);

      case FieldType.boolean:
        return _buildBooleanField(field, existingValue ?? false);

      case FieldType.dropdown:
        return _buildDropdownField(field, existingValue);

      case FieldType.multiSelect:
        return _buildMultiSelectField(field, existingValue);

      case FieldType.date:
        return _buildDateField(field, existingValue);

      case FieldType.color:
        return _buildColorField(field, existingValue);
    }
  }

  Widget _buildTextField(MetadataField field, dynamic value) {
    final controller = _controllers[field.key] ??= TextEditingController(
      text: value ?? '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: 'Enter ${field.label.toLowerCase()}',
          suffixText: field.unit,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        onChanged: (val) => _updateField(field.key, val),
        validator: (val) {
          if (field.required && (val == null || val.isEmpty)) {
            return '${field.label} is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildNumberField(MetadataField field, dynamic value) {
    final controller = _controllers[field.key] ??= TextEditingController(
      text: value?.toString() ?? '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: 'Enter number',
          suffixText: field.unit,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        keyboardType: TextInputType.number,
        onChanged: (val) => _updateField(field.key, int.tryParse(val)),
      ),
    );
  }

  Widget _buildDecimalField(MetadataField field, dynamic value) {
    final controller = _controllers[field.key] ??= TextEditingController(
      text: value?.toString() ?? '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: 'Enter decimal number',
          suffixText: field.unit,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (val) => _updateField(field.key, double.tryParse(val)),
      ),
    );
  }

  Widget _buildBooleanField(MetadataField field, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                value == true ? Icons.check_circle : Icons.cancel,
                color: value == true ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(field.label, style: const TextStyle(fontSize: 16)),
              ),
              Switch(
                value: value == true,
                onChanged: (val) => _updateField(field.key, val),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(MetadataField field, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && value.toString().isNotEmpty
            ? value.toString()
            : null,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        hint: Text('Select ${field.label.toLowerCase()}'),
        items: field.options?.map((option) {
          return DropdownMenuItem(value: option, child: Text(option));
        }).toList(),
        onChanged: (val) => _updateField(field.key, val),
        validator: (val) {
          if (field.required && (val == null || val.isEmpty)) {
            return '${field.label} is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMultiSelectField(MetadataField field, dynamic value) {
    final selectedValues = value is List ? value : <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    field.options?.map((option) {
                      final isSelected = selectedValues.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (selected) {
                          final newList = selected
                              ? [...selectedValues, option]
                              : selectedValues
                                    .where((v) => v != option)
                                    .toList();
                          _updateField(field.key, newList);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      );
                    }).toList() ??
                    [],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(MetadataField field, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value != null
                ? (value is DateTime
                      ? value
                      : DateTime.tryParse(value) ?? DateTime.now())
                : DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            _updateField(field.key, date.toIso8601String());
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label + (field.required ? ' *' : ''),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value != null
                          ? _formatDate(value)
                          : 'Select ${field.label.toLowerCase()}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorField(MetadataField field, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          // For simplicity, just use a text field for color code
          // In production, use a color picker package
          final color = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enter Color Code'),
              content: TextField(
                decoration: const InputDecoration(
                  hintText: '#000000',
                  labelText: 'Hex Color Code',
                ),
                controller: TextEditingController(text: value ?? ''),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Get the text from controller
                    Navigator.pop(context, '#000000');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (color != null) {
            _updateField(field.key, color);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value != null ? _parseColor(value) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value ?? 'Select color',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (e) {}
    return Colors.grey;
  }
}
