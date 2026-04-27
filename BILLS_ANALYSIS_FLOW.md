# Aurora E-Commerce - Bills & Analysis Flow

## Overview
This document describes the complete flow from bill creation to analysis generation for the seller account.

## Architecture Flow Tree

```
┌─────────────────────────────────────────────────────────────────┐
│                        SELLER ACCOUNT                            │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│   Customers   │    │    Providers  │    │   Products    │
│   Management  │    │  Management   │    │  Management   │
└───────┬───────┘    └───────┬───────┘    └───────┬───────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Bills Page     │
                    │  (Creation)     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
     ┌────────────┐ ┌────────────┐ ┌────────────┐
     │  Select    │ │   Add      │ │  Payment   │
     │  Customer  │ │   Items    │ │  Details   │
     └─────┬──────┘ └─────┬──────┘ └─────┬──────┘
           │              │              │
           └──────────────┼──────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Create Bill    │
                 │  (Save to DB)   │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Bills List     │
                 │  (Display All)  │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Trigger         │
                 │ Analysis Engine │
                 └────────┬────────┘
                          │
                          ▼
          ┌───────────────────────────────┐
          │    ANALYSIS ENGINE            │
          │                               │
          │  ┌─────────────────────────┐  │
          │  │  Input Data:            │  │
          │  │  - Bills List           │  │
          │  │  - Customers List       │  │
          │  │  - Providers List       │  │
          │  └─────────────────────────┘  │
          │                               │
          │  ┌─────────────────────────┐  │
          │  │  Processing:            │  │
          │  │  - Calculate KPIs       │  │
          │  │  - RFM Analysis         │  │
          │  │  - Segmentation         │  │
          │  │  - Trend Analysis       │  │
          │  │  - Churn Prediction     │  │
          │  └─────────────────────────┘  │
          │                               │
          │  ┌─────────────────────────┐  │
          │  │  Output:                │  │
          │  │  - Customer Analysis    │  │
          │  │  - Provider Analysis    │  │
          │  │  - Business Summary     │  │
          │  └─────────────────────────┘  │
          └───────────────┬───────────────┘
                          │
                          ▼
          ┌───────────────────────────────┐
          │  Generate JSON Data           │
          │  {                            │
          │    "analysis": [              │
          │      {                        │
          │        "type": "customers",   │
          │        "data": [...]          │
          │      },                       │
          │      {                        │
          │        "type": "providers",   │
          │        "data": [...]          │
          │      }                        │
          │    ],                         │
          │    "summary": {               │
          │      "totalCustomers": ...,   │
          │      "totalRevenue": ...,     │
          │      ...                      │
          │    }                          │
          │  }                            │
          └───────────────┬───────────────┘
                          │
                          ▼
          ┌───────────────────────────────┐
          │  ANALYSIS STORAGE SERVICE     │
          │                               │
          │  Save to:                     │
          │  /documents/{uuid}/           │
          │            {username}.json    │
          │                               │
          │  Example:                     │
          │  /documents/                  │
          │    abc-123-def-456/           │
          │      seller_john.json         │
          └───────────────┬───────────────┘
                          │
                          ▼
          ┌───────────────────────────────┐
          │   Analysis Page               │
          │   (View Results)              │
          │                               │
          │  - Business Summary           │
          │  - Customer Analysis          │
          │  - Provider Analysis          │
          │  - KPI Metrics                │
          │  - Charts & Visualizations    │
          └───────────────────────────────┘
```

## Detailed Component Flow

### 1. Customer Management Flow
```
CustomersPage
├── Load customers from database
├── Display customer list with stats
├── Add new customer
│   └── CustomerFormScreen
│       ├── Name (required)
│       ├── Phone Number (required)
│       ├── Address (optional)
│       └── Notes (optional)
├── Edit existing customer
└── Delete customer
```

### 2. Provider Management Flow
```
ProvidersPage (To be implemented)
├── Load providers from database
├── Display provider list
├── Add new provider
│   └── ProviderFormScreen
│       ├── Company Name
│       ├── Contact Name
│       ├── Phone Number
│       ├── Email
│       ├── Address
│       └── Notes
└── Manage provider relationships
```

### 3. Bill Creation Flow
```
BillsPage
├── Create New Bill
│   └── BillCreationScreen
│       ├── Step 1: Select Customer
│       │   ├── Choose from existing customers
│       │   └── OR Add new customer inline
│       │
│       ├── Step 2: Add Products
│       │   ├── Select product from list
│       │   ├── Enter quantity
│       │   ├── Auto-calculate line total
│       │   └── Add multiple items
│       │
│       ├── Step 3: Payment Details
│       │   ├── Payment Method (cash/card/transfer)
│       │   └── Payment Status (pending/paid/partial)
│       │
│       ├── Step 4: Review
│       │   ├── Subtotal
│       │   ├── Tax (10%)
│       │   └── Total
│       │
│       └── Step 5: Create Bill
│           └── Save to database
│
└── View Bills List
    └── BillDetailsScreen
        ├── Bill information
        ├── Customer details
        ├── Items breakdown
        └── Payment summary
```

### 4. Analysis Engine Flow
```
AnalysisEngine
├── Input: Bills, Customers, Providers
│
├── Customer Analysis
│   ├── Calculate total purchases per customer
│   ├── Count total orders
│   ├── Determine last purchase date
│   ├── Calculate average order value
│   ├── Segment customers (VIP/Loyal/Regular/New)
│   ├── Calculate KPIs:
│   │   ├── Retention Score
│   │   ├── Frequency Score
│   │   ├── Monetary Score
│   │   ├── RFM Segment (Recency-Frequency-Monetary)
│   │   ├── Churn Risk (High/Medium/Low/Very Low)
│   │   ├── Lifetime Value (annual projection)
│   │   └── Growth Trend (Growing/Stable/Declining)
│   └── Generate CustomerAnalysisData objects
│
├── Provider Analysis
│   ├── Calculate total supply value
│   ├── Count total supplies
│   ├── Determine last supply date
│   ├── Rate providers (Preferred/Standard/New)
│   ├── Calculate KPIs:
│   │   ├── Reliability Score
│   │   ├── Cost Efficiency
│   │   ├── Delivery Performance
│   │   ├── Quality Score
│   │   └── Partnership Duration
│   └── Generate ProviderAnalysisData objects
│
└── Export to JSON
    ├── analysis[] array with customer & provider data
    └── summary object with aggregate metrics
```

### 5. Storage Flow
```
AnalysisStorageService
├── saveAnalysisData()
│   ├── Get app documents directory
│   ├── Create UUID folder: /documents/{uuid}/
│   ├── Create JSON file: {username}.json
│   └── Write analysis data as formatted JSON
│
├── loadAnalysisData()
│   ├── Read from /documents/{uuid}/{username}.json
│   └── Parse JSON to Map<String, dynamic>
│
├── listAnalysisFiles()
│   └── List all .json files in UUID folder
│
└── getAllAnalysisData()
    └── Aggregate all user analysis files
```

### 6. Analysis Display Flow
```
AnalysisPage
├── Load analysis data from storage
├── Display Business Summary Card
│   ├── Total Customers
│   ├── Total Providers
│   ├── Total Revenue
│   ├── VIP Customers count
│   └── Loyal Customers count
│
├── Customer Analysis Section
│   └── For each customer:
│       ├── Name & Avatar
│       ├── Order count & Total spent
│       ├── Segment badge (color-coded)
│       └── Expandable KPI details:
│           ├── Average Order Value
│           ├── Last Purchase Date
│           ├── Churn Risk
│           ├── Growth Trend
│           ├── Lifetime Value
│           └── RFM Segment
│
└── Provider Analysis Section
    └── For each provider:
        ├── Name & Avatar
        ├── Supply count & Total value
        ├── Rating badge
        └── Expandable KPI details:
            ├── Reliability Score
            ├── Cost Efficiency
            └── Partnership Duration
```

## File Structure

```
lib/
├── models/
│   ├── aurora_customer.dart      # Customer model with analysis fields
│   ├── product_provider.dart     # Provider model with analysis fields
│   └── bill.dart                 # Bill and BillItem models
│
├── engine/
│   └── analysis_engine.dart      # Core analysis logic & KPI calculations
│
├── services/
│   └── analysis_storage_service.dart  # JSON file storage operations
│
└── screens/
    ├── customers/
    │   └── customers_page.dart    # Customer management UI
    ├── providers/
    │   └── providers_page.dart    # Provider management UI (to implement)
    ├── bills/
    │   └── bills_page.dart        # Bill creation & list UI
    └── analysis/
        └── analysis_page.dart     # Analysis results display UI
```

## Data Flow Sequence

1. **User creates customer** → Saved to database
2. **User creates bill** → Select customer + Add products → Save bill to database
3. **User triggers analysis** → AnalysisEngine processes all bills
4. **Engine calculates KPIs** → Generates analysis objects
5. **Export to JSON** → Structured data format
6. **Save to storage** → `/documents/{uuid}/{username}.json`
7. **User views analysis** → AnalysisPage loads and displays insights

## Key Features

### For Seller Account Only
- ✅ Customer management with segmentation
- ✅ Bill creation with customer & product selection
- ✅ Inline customer creation during billing
- ✅ Automatic KPI calculation
- ✅ RFM (Recency-Frequency-Monetary) analysis
- ✅ Churn risk assessment
- ✅ Customer lifetime value projection
- ✅ Provider performance tracking
- ✅ JSON export to isolated user folders
- ✅ Visual analysis dashboard

### Security & Isolation
- Each seller's data stored in UUID-named folder
- Username-based JSON files prevent conflicts
- Local storage ensures offline access
- Data isolation between different sellers

## Next Steps for Implementation

1. Integrate with actual database (Supabase/Firebase)
2. Implement provider management pages
3. Add product selector dialog in bill creation
4. Connect auth system for UUID/username retrieval
5. Add charts and visualizations to analysis page
6. Implement data export/sharing features
7. Add push notifications for low-stock/high-churn alerts
