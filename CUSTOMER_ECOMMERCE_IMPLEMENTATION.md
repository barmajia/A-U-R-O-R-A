# Customer E-commerce Implementation

## Overview
This implementation adds a complete customer-facing e-commerce flow to the Aurora platform, separate from seller/factory features. The system uses a wallet-based payment method as the primary way to pay during checkout.

## Architecture

### Models Created
1. **Wallet Model** (`lib/models/wallet.dart`)
   - `Wallet`: User's digital wallet with balance tracking
   - `WalletTransaction`: Transaction history (credit/debit/refund)
   - `WalletProvider`: State management for wallet operations

2. **Cart Model** (`lib/models/cart.dart`)
   - `CartItem`: Individual items in shopping cart
   - `CartProvider`: State management for cart operations

### Pages Created
1. **Cart Page** (`lib/pages/customer/cart_page.dart`)
   - View cart items with quantity controls
   - Update/remove items
   - Order summary with total calculation
   - Navigate to checkout

2. **Checkout Page** (`lib/pages/customer/checkout_page.dart`)
   - Order summary
   - Wallet payment method selection
   - Real-time balance validation
   - Add funds functionality
   - Order placement with wallet deduction

3. **Wallet Page** (`lib/pages/customer/wallet_page.dart`)
   - Display current balance
   - Transaction history
   - Quick add funds
   - Wallet creation for new users

### Navigation Updates
- Updated `AppDrawer` with fixed customer section:
  - **Shop**: Browse products (UserHomePage)
  - **Cart**: Shopping cart with item count badge
  - **Wallet**: Digital wallet management

### Provider Integration
Added to `main.dart`:
```dart
ChangeNotifierProvider(create: (_) => WalletProvider()),
ChangeNotifierProvider(create: (_) => CartProvider()),
```

### Routes Added
```dart
'/cart': (context) => const CartPage(),
'/checkout': (context) => const CheckoutPage(),
```

## User Flow

### Shopping Flow
1. User browses products on Shop page
2. Adds items to cart
3. Views cart with item management
4. Proceeds to checkout

### Payment Flow
1. User reviews order summary
2. System checks wallet balance
3. If insufficient funds:
   - Warning displayed
   - Option to add funds
4. If sufficient funds:
   - "Place Order" button enabled
   - Payment processed from wallet
   - Cart cleared
   - Order confirmation shown

### Wallet Management
1. View current balance
2. See transaction history
3. Add funds via dialog
4. Quick amount presets ($10, $20, $50, $100, etc.)

## Key Features

### Wallet System
- **Balance Tracking**: Real-time balance updates
- **Transaction Types**: Credit, Debit, Refund
- **Transaction Status**: Pending, Completed, Failed, Cancelled
- **Security**: Balance validation before payment

### Cart System
- **Quantity Management**: Increment/decrement controls
- **Item Persistence**: Ready for database integration
- **Total Calculation**: Automatic subtotal/total updates
- **Empty State**: User-friendly empty cart UI

### Checkout Process
- **Wallet-Only Payment**: Primary payment method
- **Insufficient Funds Handling**: Clear warnings and add funds option
- **Order Processing**: Atomic transaction (deduct + clear cart)
- **Success/Error Feedback**: Dialogs and snackbars

## Database Schema (TODO)

### Wallets Table
```sql
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  balance DECIMAL(10,2) DEFAULT 0.00,
  currency TEXT DEFAULT 'USD',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Wallet Transactions Table
```sql
CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES wallets(id),
  user_id UUID REFERENCES auth.users(id),
  amount DECIMAL(10,2) NOT NULL,
  type TEXT CHECK (type IN ('credit', 'debit', 'refund')),
  status TEXT CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  description TEXT,
  reference_id TEXT, -- Order ID, payment ID, etc.
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Cart Items Table
```sql
CREATE TABLE cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  product_id UUID REFERENCES products(id),
  product_name TEXT,
  product_image TEXT,
  price DECIMAL(10,2),
  quantity INTEGER DEFAULT 1,
  seller_id UUID REFERENCES sellers(id),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

## Next Steps

### Immediate (Phase 1)
1. ✅ Create wallet model and provider
2. ✅ Create cart model and provider
3. ✅ Build cart page UI
4. ✅ Build checkout page UI
5. ✅ Build wallet page UI
6. ✅ Update drawer navigation
7. ✅ Register providers in main.dart
8. ⏳ Connect to Supabase database
9. ⏳ Implement actual product browsing with "Add to Cart"

### Short-term (Phase 2)
1. Database migrations for wallet, transactions, cart
2. Sync local state with Supabase
3. Implement offline-first caching
4. Add shipping address management
5. Order creation and tracking

### Future Enhancements
1. Multiple payment methods (credit card, PayPal, etc.)
2. Promo codes and discounts
3. Shipping cost calculation
4. Tax calculation
5. Order history for customers
6. Product reviews and ratings
7. Wishlist functionality
8. Push notifications for order updates

## Testing Checklist
- [ ] Add item to cart
- [ ] Update cart item quantity
- [ ] Remove item from cart
- [ ] Clear entire cart
- [ ] View cart with items
- [ ] View empty cart state
- [ ] Navigate to checkout
- [ ] View order summary
- [ ] Check wallet balance display
- [ ] Test insufficient funds warning
- [ ] Add funds to wallet
- [ ] Complete purchase with wallet
- [ ] Verify balance deduction
- [ ] Verify cart cleared after purchase
- [ ] View transaction history
- [ ] Test wallet creation for new user

## Notes
- All database operations currently use stub delays (TODO markers)
- Wallet is the only payment method implemented
- Cart persists in memory (ready for database integration)
- UI follows Material Design 3 guidelines
- Supports both light and dark themes
- Ready for localization (uses AppLocalizations where applicable)
