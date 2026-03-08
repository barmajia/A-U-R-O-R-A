import 'dart:io';
import 'package:aurora/models/factory/factory_models.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

/// Factory Settings Page
/// Allows factory owners to manage their profile, location, and wholesale settings
class FactorySettingsPage extends StatefulWidget {
  const FactorySettingsPage({super.key});

  @override
  State<FactorySettingsPage> createState() => _FactorySettingsPageState();
}

class _FactorySettingsPageState extends State<FactorySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;
  late TextEditingController _minOrderController;
  late TextEditingController _discountController;
  late TextEditingController _capacityController;
  late TextEditingController _productionTimeController;
  late TextEditingController _customizationOptionsController;

  // State
  FactoryInfo? _factoryInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _acceptsReturns = false;
  bool _acceptsCustomization = false;
  Position? _currentLocation;
  File? _licenseImage;
  String? _licenseUrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadFactoryData();
  }

  void _initControllers() {
    _companyNameController = TextEditingController();
    _locationController = TextEditingController();
    _phoneController = TextEditingController();
    _minOrderController = TextEditingController();
    _discountController = TextEditingController();
    _capacityController = TextEditingController();
    _productionTimeController = TextEditingController();
    _customizationOptionsController = TextEditingController();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _minOrderController.dispose();
    _discountController.dispose();
    _capacityController.dispose();
    _productionTimeController.dispose();
    _customizationOptionsController.dispose();
    super.dispose();
  }

  Future<void> _loadFactoryData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = context.read<SupabaseProvider>();
      final userId = supabase.currentUser?.id;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final info = await supabase.getFactoryInfo(userId);

      setState(() {
        _factoryInfo = info;
        _isLoading = false;

        // Populate controllers with existing data
        _companyNameController.text = _factoryInfo?.fullName ?? '';
        _locationController.text = _factoryInfo?.location ?? '';
        _minOrderController.text =
            _factoryInfo?.minOrderQuantity?.toString() ?? '';
        _discountController.text =
            _factoryInfo?.wholesaleDiscount?.toString() ?? '';
        _acceptsReturns = false; // Would need to fetch from seller profile
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load factory data: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = position;
        _locationController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    }
  }

  Future<void> _pickLicenseImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _licenseImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = context.read<SupabaseProvider>();

      // Update factory profile
      final result = await supabase.updateFactoryProfile(
        companyName: _companyNameController.text.isNotEmpty
            ? _companyNameController.text
            : null,
        minOrderQuantity: _minOrderController.text.isNotEmpty
            ? int.tryParse(_minOrderController.text)
            : null,
        wholesaleDiscount: _discountController.text.isNotEmpty
            ? double.tryParse(_discountController.text)
            : null,
        productionCapacity: _capacityController.text.isNotEmpty
            ? _capacityController.text
            : null,
      );

      // Update location if changed
      if (_currentLocation != null) {
        await supabase.updateSellerLocation(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
        );
      }

      // Upload license image if selected
      if (_licenseImage != null) {
        // TODO: Implement license image upload
        // final imageUrl = await supabase.uploadFactoryLicense(_licenseImage!);
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          _loadFactoryData();
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? AppColors.darkSurface : AppColors.auroraPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Settings'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      drawer: const AppDrawer(currentPage: 'factory_settings'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFactoryData,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Basic Information Section
                    _buildSectionTitle('Basic Information'),
                    const SizedBox(height: 12),
                    _buildBasicInfoCard(),
                    const SizedBox(height: 24),

                    // Location Section
                    _buildSectionTitle('Location'),
                    const SizedBox(height: 12),
                    _buildLocationCard(),
                    const SizedBox(height: 24),

                    // Wholesale Settings Section
                    _buildSectionTitle('Wholesale Settings'),
                    const SizedBox(height: 12),
                    _buildWholesaleSettingsCard(),
                    const SizedBox(height: 24),

                    // Production Capacity Section
                    _buildSectionTitle('Production Capacity'),
                    const SizedBox(height: 12),
                    _buildProductionCard(),
                    const SizedBox(height: 24),

                    // Business License Section
                    _buildSectionTitle('Business License'),
                    const SizedBox(height: 12),
                    _buildLicenseCard(),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: const Icon(Icons.save, size: 24),
                        label: const Text(
                          'Save Settings',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company/Factory Name',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Factory name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (Coordinates)',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
                hintText: 'Auto-filled or enter manually',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
                  ),
                ),
                if (_currentLocation != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ],
            ),
            if (_factoryInfo?.latitude != null &&
                _factoryInfo?.longitude != null) ...[
              const SizedBox(height: 12),
              Text(
                'Current: ${_factoryInfo!.latitude!.toStringAsFixed(4)}, ${_factoryInfo!.longitude!.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWholesaleSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _minOrderController,
              decoration: const InputDecoration(
                labelText: 'Minimum Order Quantity',
                prefixIcon: Icon(Icons.shopping_cart),
                border: OutlineInputBorder(),
                hintText: 'e.g., 10',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'Wholesale Discount (%)',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
                hintText: 'e.g., 15',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Accepts Returns'),
              subtitle: const Text('Allow buyers to return products'),
              value: _acceptsReturns,
              onChanged: (value) {
                setState(() => _acceptsReturns = value);
              },
              secondary: const Icon(Icons.assignment_return),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(
                labelText: 'Production Capacity',
                prefixIcon: Icon(Icons.settings),
                border: OutlineInputBorder(),
                hintText: 'e.g., 1000 units/month',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productionTimeController,
              decoration: const InputDecoration(
                labelText: 'Average Production Time',
                prefixIcon: Icon(Icons.access_time),
                border: OutlineInputBorder(),
                hintText: 'e.g., 7-14 days',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Accepts Customization'),
              subtitle: const Text('Offer custom product modifications'),
              value: _acceptsCustomization,
              onChanged: (value) {
                setState(() => _acceptsCustomization = value);
              },
              secondary: const Icon(Icons.build),
            ),
            if (_acceptsCustomization) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customizationOptionsController,
                decoration: const InputDecoration(
                  labelText: 'Customization Options',
                  prefixIcon: Icon(Icons.tune),
                  border: OutlineInputBorder(),
                  hintText:
                      'e.g., Logo printing, Custom packaging, Color options',
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business License',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your business license for verification',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_licenseImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _licenseImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _licenseImage = null),
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ] else if (_licenseUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _licenseUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              InkWell(
                onTap: _pickLicenseImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload license',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_factoryInfo?.isVerified ?? false)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Factory is verified',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
