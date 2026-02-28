# 📸 Product Image Upload - Complete Setup Guide

## ✅ What Was Created

### **1. Permissions System** (`lib/services/permissions.dart`)

**Requests on First App Launch:**
- ✅ **Camera** - Take product photos
- ✅ **Storage** - Access gallery (Android < 13)
- ✅ **Photos** - Access gallery (Android >= 13, iOS)
- ✅ **Location** - Already in your app

**Usage:**
```dart
// In main.dart - runs automatically on first launch
await AppPermissions.requestPermissions();
```

**Permission Dialog:**
- Shows on first launch
- User can grant or deny
- Logs status to console

---

### **2. Supabase Storage Service** (`lib/services/supabase_storage.dart`)

**Features:**
- Upload product images to Supabase Storage
- Generate unique filenames (UUID)
- Organize by seller ID and product ID
- Get public URLs for images
- Delete images

**Usage:**
```dart
final storage = SupabaseStorage(Supabase.instance.client);

// Upload single image
final imageUrl = await storage.uploadProductImage(
  imageFile: imageFile,
  sellerId: sellerId,
  productId: productId,
);

// Upload multiple images
final imageUrls = await storage.uploadMultipleImages(
  images: [file1, file2, file3],
  sellerId: sellerId,
  productId: productId,
);

// Delete image
await storage.deleteImage(imageUrl);
```

**Storage Structure:**
```
product-images/
├── {seller_id_1}/
│   ├── {product_id_1}/
│   │   ├── uuid1.jpg
│   │   └── uuid2.jpg
│   └── {product_id_2}/
│       └── uuid3.jpg
└── {seller_id_2}/
    └── {product_id_3}/
        └── uuid4.jpg
```

---

### **3. Android Permissions** (`android/app/src/main/AndroidManifest.xml`)

**Added:**
```xml
<!-- Camera -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />

<!-- Storage (Android < 13) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Photos (Android >= 13) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

---

### **4. iOS Permissions** (`ios/Runner/Info.plist`)

**Added:**
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos of your products</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select product images</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save product photos to your library</string>
```

---

## 🚀 SETUP STEPS

### **Step 1: Install Packages**

```powershell
cd "c:\Users\yn098\youssef's project\Aurora\flutter\aurora_ecommerse\aurora\aurora"
flutter pub get
```

---

### **Step 2: Create Supabase Storage Bucket**

**Option A: Via Supabase Dashboard**
1. Go to: https://supabase.com/dashboard/project/ofovfxsfazlwvcakpuer/storage
2. Click **"New Bucket"**
3. Name: `product-images`
4. Toggle **"Public bucket"** ✅
5. File size limit: `10485760` (10 MB)
6. Click **"Create bucket"**

**Option B: Via SQL Editor**
```sql
-- Run in SQL Editor
insert into storage.buckets (id, name, public, file_size_limit)
values ('product-images', 'product-images', true, 10485760);
```

**Option C: Automatic (in code)**
The `SupabaseStorage` class will create it automatically on first use.

---

### **Step 3: Add Storage Policies**

In Supabase Dashboard → Storage → `product-images` → Policies:

```sql
-- Allow authenticated users to upload
CREATE POLICY "Users can upload product images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'product-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to read their own images
CREATE POLICY "Users can read own images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to delete their own images
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
USING (bucket_id = 'product-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow public read (optional - for public product images)
CREATE POLICY "Public read"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');
```

---

## 📱 HOW TO USE IN PRODUCT FORM

### **Add Image Picker to ProductFormScreen:**

```dart
class _ProductFormScreenState extends State<ProductFormScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _productImages = [];

  // Pick image from camera
  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        // Crop image
        final cropped = await ImageCropper().cropImage(
          sourcePath: photo.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Image',
            ),
          ],
        );

        if (cropped != null) {
          setState(() {
            _productImages.add(File(cropped.path));
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (final image in images) {
        setState(() {
          _productImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  // Upload images to Supabase
  Future<List<String>> _uploadImages(String sellerId, String productId) async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final storage = SupabaseStorage(supabaseProvider.client);
    
    final urls = await storage.uploadMultipleImages(
      images: _productImages,
      sellerId: sellerId,
      productId: productId,
    );
    
    return urls;
  }
}
```

---

### **UI for Image Picker:**

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Add Product'),
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveProduct,
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image Picker Section
        _buildImagePickerSection(),
        const SizedBox(height: 24),
        
        // Product Details Form
        _buildTextField(...),
        // ... rest of form
      ],
    ),
  );
}

Widget _buildImagePickerSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Product Images',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      
      if (_productImages.isEmpty)
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No images yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            ],
          ),
        )
      else
        Column(
          children: [
            // Image Grid
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _productImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _productImages[index],
                            height: 200,
                            width: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_circle,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _productImages.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Add more buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Add More'),
                ),
              ],
            ),
          ],
        ),
    ],
  );
}
```

---

## 🎯 Complete Flow

```
1. User opens app
   ↓
2. Permissions requested automatically
   ↓
3. User grants camera & storage permissions ✅
   ↓
4. User navigates to Products → Add Product
   ↓
5. User clicks "Camera" or "Gallery"
   ↓
6. Takes photo or selects from gallery
   ↓
7. Image is cropped (optional)
   ↓
8. Image preview shown
   ↓
9. User fills product details
   ↓
10. Clicks "Save"
    ↓
11. Product created in database (ASIN & SKU generated)
    ↓
12. Images uploaded to Supabase Storage
    ↓
13. Image URLs saved to product record
    ↓
14. Product appears in list with images ✅
```

---

## 📋 Next Steps

The infrastructure is ready! Now you need to:

1. **Add image picker UI** to `ProductFormScreen`
2. **Connect upload** to save product flow
3. **Display images** in product list and details
4. **Test** on real device (permissions need real device)

---

## 🧪 Testing

### **Test Permissions:**
```powershell
flutter run
# First launch should show permission dialog
```

### **Test Image Upload:**
1. Create product-images bucket in Supabase
2. Add storage policies
3. Run app
4. Grant permissions
5. Take photo
6. Save product
7. Check Supabase Storage → product-images bucket

---

## ✅ Summary

| Feature | Status |
|---------|--------|
| **Permissions** | ✅ Auto-requested on first launch |
| **Camera** | ✅ Ready to use |
| **Gallery** | ✅ Ready to use |
| **Supabase Storage** | ✅ Service created |
| **Image Cropping** | ✅ Package added |
| **Android Permissions** | ✅ Added to manifest |
| **iOS Permissions** | ✅ Added to Info.plist |

**All infrastructure is ready! Just add the UI components to your product form.** 🎉
