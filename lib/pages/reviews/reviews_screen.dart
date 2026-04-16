// ============================================================================
// Aurora Review & Rating System
// ============================================================================
//
// Complete review and rating functionality
// Features:
// - Submit reviews with rating
// - Photo uploads
// - Pros/cons lists
// - Helpful voting
// - Review list with filtering
// - Rating distribution
// ============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ============================================================================
// Review Submission Dialog
// ============================================================================

class ReviewSubmissionDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final Function(String, int, String, String, List<String>, List<String>)?
  onSubmit;

  const ReviewSubmissionDialog({
    super.key,
    required this.productId,
    required this.productName,
    this.onSubmit,
  });

  @override
  State<ReviewSubmissionDialog> createState() => _ReviewSubmissionDialogState();
}

class _ReviewSubmissionDialogState extends State<ReviewSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  final _prosController = TextEditingController();
  final _consController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    _prosController.dispose();
    _consController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles != null) {
        setState(() {
          _images.addAll(pickedFiles.map((f) => File(f.path)).toList());
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Parse pros and cons
    final pros = _prosController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cons = _consController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Submit review
    if (widget.onSubmit != null) {
      await widget.onSubmit!(
        widget.productId,
        _rating,
        _titleController.text,
        _commentController.text,
        pros,
        cons,
      );
    }

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Write a Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  widget.productName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),

                const SizedBox(height: 24),

                // Rating
                const Text(
                  'Your Rating',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Review Title',
                          hintText: 'Summarize your experience',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Comment
                      TextFormField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          labelText: 'Your Review',
                          hintText: 'Share details about your experience',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please write your review';
                          }
                          if (value.length < 10) {
                            return 'Review must be at least 10 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Pros
                      TextFormField(
                        controller: _prosController,
                        decoration: const InputDecoration(
                          labelText: 'Pros',
                          hintText:
                              'Good quality, fast shipping (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Cons
                      TextFormField(
                        controller: _consController,
                        decoration: const InputDecoration(
                          labelText: 'Cons',
                          hintText: 'Expensive, small size (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Image Upload
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Photos',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_a_photo),
                            onPressed: _pickImages,
                          ),
                        ],
                      ),

                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _images[index],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit Review',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Reviews List Screen
// ============================================================================

class ReviewsScreen extends StatefulWidget {
  final String productId;
  final double averageRating;
  final int totalReviews;

  const ReviewsScreen({
    super.key,
    required this.productId,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  String _filterRating = 'all';
  String _sortBy = 'recent';

  // Sample reviews (replace with actual data)
  final List<Map<String, dynamic>> _reviews = [
    {
      'id': '1',
      'userId': 'user1',
      'userName': 'John Doe',
      'userAvatar': null,
      'rating': 5,
      'title': 'Excellent product!',
      'comment':
          'This product exceeded my expectations. High quality and fast shipping.',
      'pros': ['High quality', 'Fast shipping'],
      'cons': ['A bit expensive'],
      'images': [],
      'helpful': 12,
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'verifiedPurchase': true,
    },
    {
      'id': '2',
      'userId': 'user2',
      'userName': 'Jane Smith',
      'userAvatar': null,
      'rating': 4,
      'title': 'Good value for money',
      'comment': 'Great product overall. Works as expected.',
      'pros': ['Good value'],
      'cons': [],
      'images': ['https://via.placeholder.com/100'],
      'helpful': 8,
      'date': DateTime.now().subtract(const Duration(days: 10)),
      'verifiedPurchase': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Rating Summary
          _buildRatingSummary(),

          // Write Review Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showWriteReviewDialog(),
                icon: const Icon(Icons.rate_review),
                label: const Text('Write a Review'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Reviews List
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          // Average Rating
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStarRating(widget.averageRating, size: 24),
                const SizedBox(height: 4),
                Text(
                  '${widget.totalReviews} reviews',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Rating Distribution
          Expanded(
            child: Column(
              children: [
                _buildRatingBar(5, 0.6),
                _buildRatingBar(4, 0.25),
                _buildRatingBar(3, 0.1),
                _buildRatingBar(2, 0.03),
                _buildRatingBar(1, 0.02),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;

        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating > index) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return Icon(icon, color: Colors.amber, size: size);
      }),
    );
  }

  Widget _buildReviewsList() {
    final filteredReviews = _reviews.where((review) {
      final matchesFilter =
          _filterRating == 'all' ||
          review['rating'].toString() == _filterRating;
      return matchesFilter;
    }).toList();

    if (filteredReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReviews.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final review = filteredReviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reviewer Info
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: review['userAvatar'] != null
                  ? ClipOval(
                      child: Image.network(
                        review['userAvatar'] as String,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      (review['userName'] as String)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        review['userName'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (review['verifiedPurchase'] == true) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  _buildStarRating(review['rating'] as double, size: 16),
                ],
              ),
            ),
            Text(
              _formatDate(review['date'] as DateTime),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Review Title
        Text(
          review['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        const SizedBox(height: 8),

        // Review Comment
        Text(
          review['comment'] as String,
          style: TextStyle(color: Colors.grey[800], height: 1.5),
        ),

        // Pros & Cons
        if ((review['pros'] as List).isNotEmpty ||
            (review['cons'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          if ((review['pros'] as List).isNotEmpty)
            _buildProsConsList(
              'Pros',
              review['pros'] as List<String>,
              Colors.green,
            ),
          if ((review['cons'] as List).isNotEmpty)
            _buildProsConsList(
              'Cons',
              review['cons'] as List<String>,
              Colors.red,
            ),
        ],

        // Images
        if ((review['images'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (review['images'] as List).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      (review['images'] as List)[index] as String,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Helpful Button
        Row(
          children: [
            Text(
              'Was this helpful?',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                // Handle helpful vote
              },
              icon: const Icon(Icons.thumb_up_outlined, size: 16),
              label: Text('${review['helpful']}'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProsConsList(String title, List<String> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(color: color, fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Reviews'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Ratings'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('5 Stars'),
              leading: Radio<String>(
                value: '5',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('4 Stars'),
              leading: Radio<String>(
                value: '4',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('3 Stars'),
              leading: Radio<String>(
                value: '3',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('2 Stars'),
              leading: Radio<String>(
                value: '2',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('1 Star'),
              leading: Radio<String>(
                value: '1',
                groupValue: _filterRating,
                onChanged: (value) {
                  setState(() {
                    _filterRating = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWriteReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => ReviewSubmissionDialog(
        productId: widget.productId,
        productName: 'Product Name', // Replace with actual product name
        onSubmit: (productId, rating, title, comment, pros, cons) async {
          // Submit review to backend
          debugPrint('Submitting review: $rating stars');
          debugPrint('Title: $title');
          debugPrint('Comment: $comment');
          debugPrint('Pros: $pros');
          debugPrint('Cons: $cons');

          // TODO: Call backend API to submit review

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Review submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}
