# Product Image Upload System - Implementation Guide

## Overview

A complete product image upload system for Aurora E-commerce, integrated with Supabase Storage. Features include image picking, compression, cropping, upload, deletion, and caching.

---

## ✅ Implementation Summary

### Files Created/Modified

| File | Status | Purpose |
|------|--------|---------|
| `supabase/migrations/007_product_images_storage.sql` | ✅ Created | Storage bucket & RLS policies |
| `lib/services/image_upload_service.dart` | ✅ Created | Image upload/compression logic |
| `lib/widgets/product_image_upload.dart` | ✅ Created | UI widget for image management |
| `lib/services/supabase.dart` | ✅ Modified | Added static `of()` method |
| `pubspec.yaml` | ✅ Updated | Added `cached_network_image` dependency |

### Permissions Already Configured

- ✅ Android: Camera, Storage, Media permissions in `AndroidManifest.xml`
- ✅ iOS: Camera, Photo Library usage in `Info.plist`

---

## 📋 Setup Instructions

### Step 1: Run SQL Migration in Supabase

1. Open your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Copy and run the contents of `supabase/migrations/007_product_images_storage.sql`

This will:
- Create the `product-images` storage bucket
- Set up Row Level Security (RLS) policies
- Create cleanup trigger for automatic image deletion
- Configure public access for product images

**SQL Migration Features:**
- 5MB file size limit per image
- Allowed MIME types: JPEG, PNG, WebP
- User-specific folders for security
- Automatic cleanup on product update/delete

---

### Step 2: Install Dependencies

Already done! Run this if you need to reinstall:

```bash
flutter pub get
```

---

### Step 3: Usage in Product Form Screen

Import the widget:

```dart
import 'package:aurora/widgets/product_image_upload.dart';
```

Add to your product form:

```dart
ProductImageUpload(
  productId: productId,  // Your product ID
  existingImages: product['images'],  // Optional: existing image URLs
  onImagesUpdated: (images) {
    // Update your product data with new images list
    setState(() => _images = images);
  },
  maxImages: 10,  // Maximum number of images
)
```

---

## 🎨 Features

### Image Upload
- ✅ Single image upload from camera or gallery
- ✅ Multiple image upload (up to 10 per product)
- ✅ Optional image cropping before upload
- ✅ Automatic image compression (max 5MB)
- ✅ Upload progress indication
- ✅ Success/error notifications

### Image Management
- ✅ Image grid preview (3 columns)
- ✅ Delete individual images
- ✅ Confirmation dialog before deletion
- ✅ Primary image badge (first image)
- ✅ Cached network images for performance

### Security
- ✅ User-specific storage folders (`user_id/product_id/`)
- ✅ Row Level Security (RLS) policies
- ✅ Authenticated upload/delete
- ✅ Public read access for product listings

---

## 📱 Example: Complete Product Form Integration

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../widgets/product_image_upload.dart';
import '../services/image_upload_service.dart';
import '../services/supabase.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _images = [];
  bool _isLoading = false;
  String? _productId;

  @override
  void initState() {
    super.initState();
    _productId = widget.productId ?? const Uuid().v4();
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService().client;
      final response = await client
          .from('products')
          .select()
          .eq('id', widget.productId!)
          .single();

      if (response != null && mounted) {
        _titleController.text = response['title'] ?? '';
        _priceController.text = (response['price'] ?? 0).toString();
        _descriptionController.text = response['description'] ?? '';
        _images = List<String>.from(response['images'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one product image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = SupabaseService().client;
      final productData = {
        'id': _productId,
        'title': _titleController.text.trim(),
        'price': double.parse(_priceController.text),
        'description': _descriptionController.text.trim(),
        'images': _images,
        'status': 'active',
        'currency': 'USD',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.productId == null) {
        // Create new product
        await client.from('products').insert(productData);
      } else {
        // Update existing product
        await client.from('products').update(productData).eq('id', widget.productId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'New Product' : 'Edit Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Upload Widget
                    ProductImageUpload(
                      productId: _productId!,
                      existingImages: _images,
                      onImagesUpdated: (images) => setState(() => _images = images),
                      maxImages: 10,
                    ),
                    const SizedBox(height: 24),

                    // Product Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Product Title',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => v!.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Price is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        child: const Text('Save Product'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
```

---

## 🔧 Service API Reference

### ImageUploadService

```dart
final service = ImageUploadService(SupabaseService().client);
```

#### Methods

**Pick and Upload Single Image**
```dart
final image = await service.pickAndUploadImage(
  productId: productId,
  source: ImageSource.gallery, // or ImageSource.camera
  allowCropping: true,
);
```

**Pick and Upload Multiple Images**
```dart
final images = await service.pickAndUploadMultipleImages(
  productId: productId,
  maxImages: 10,
);
```

**Delete Image**
```dart
final success = await service.deleteImage(imageUrl);
```

**Delete Multiple Images**
```dart
final count = await service.deleteMultipleImages(imageUrls);
```

**Get Public URL**
```dart
final url = service.getPublicUrl(storagePath);
```

**List Product Images**
```dart
final urls = await service.listProductImages(
  sellerId: sellerId,
  productId: productId,
);
```

---

## 🗂️ Storage Structure

```
product-images/
└── {user_id}/
    └── {product_id}/
        ├── {uuid}.jpg
        ├── {uuid}.png
        └── {uuid}.webp
```

### URL Format

```
https://{project-ref}.supabase.co/storage/v1/object/public/product-images/{user_id}/{product_id}/{filename}
```

---

## 🔒 Security Policies

### RLS Policies Applied

| Policy | Access | Description |
|--------|--------|-------------|
| Upload | Authenticated | Users can upload to their own folder |
| View (own) | Authenticated | Users can view their own images |
| Update (own) | Authenticated | Users can update their own images |
| Delete (own) | Authenticated | Users can delete their own images |
| View (public) | Public | Anyone can view product images |

### Folder Security

- First folder in path must match `auth.uid()` (user ID)
- Prevents users from accessing other users' images
- Public read access allows product listing pages

---

## 🎯 Best Practices

### Image Guidelines
1. **File Size**: Keep images under 5MB (automatic compression applied)
2. **Format**: Use JPEG for photos, PNG for graphics with transparency
3. **Resolution**: Max 1920px dimension (automatic resizing)
4. **Quantity**: Maximum 10 images per product
5. **Primary Image**: First image is used as thumbnail/primary

### Performance Tips
1. **Caching**: `CachedNetworkImage` automatically caches images
2. **Compression**: Images are compressed before upload
3. **Lazy Loading**: Grid loads images progressively
4. **Thumbnails**: Consider generating thumbnails for listing pages

---

## 🐛 Troubleshooting

### Issue: Upload fails with "User not authenticated"
**Solution**: Ensure user is logged in before uploading images

### Issue: "Bucket not found" error
**Solution**: Run the SQL migration to create the `product-images` bucket

### Issue: Images not showing after upload
**Solution**: Check that RLS policies allow public read access

### Issue: Camera permission denied
**Solution**: Check device settings and grant camera permission

### Issue: Large files failing to upload
**Solution**: Images are automatically compressed, but ensure file is under 5MB

---

## 📝 Next Steps

1. ✅ Run SQL migration in Supabase Dashboard
2. ✅ Test image upload in your product form
3. ✅ Verify images appear in Supabase Storage browser
4. ✅ Test image deletion and cleanup trigger
5. ✅ Customize widget styling to match your theme

---

## 📄 Related Files

- `lib/services/supabase_storage.dart` - Basic storage service (existing)
- `lib/services/image_upload_service.dart` - Enhanced upload service (new)
- `lib/widgets/product_image_upload.dart` - UI widget (new)
- `supabase/migrations/007_product_images_storage.sql` - Database migration (new)

---

**Implementation Complete!** 🎉

For questions or issues, check the Supabase logs and Flutter debug console.
