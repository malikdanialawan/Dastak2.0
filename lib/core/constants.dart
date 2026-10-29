import 'package:flutter/material.dart';

// ============================================================================
// 1. APP BRANDING & UI PALETTE (Inspired by Premium Card UI)
// ============================================================================
// The design language uses soft squircles, subtle shadows, vibrant coral/orange
// gradients, and clean, high-contrast typography.

const String kAppName = 'Dastak';

class AppColors {
  // Brand Colors (Gradients & Accents)
  static const Color primary = Color(0xFFFF5E3A); // Vibrant Coral/Orange
  static const Color primaryLight = Color(0xFFFF8C42);
  static const Color secondary =
      Color(0xFF1A1A1A); // Deep Charcoal for contrast

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8F9FA); // Soft off-white
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards
  static const Color surfaceMuted =
      Color(0xFFF0F2F5); // Slightly darker off-white

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color info = Color(0xFF1976D2);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Gradients for Tickets/Premium Cards
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C3E50), Color(0xFF000000)],
  );
}

class AppTextStyles {
  static const String fontFamily = 'Roboto'; // Fallback to system font

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

// ============================================================================
// 2. GENERAL CONSTANTS
// ============================================================================

// --- Resident Setup ---
const List<String> kSocieties = [
  'Bahria Town',
  'Bahria Enclave',
  'DHA Islamabad',
  'Gulberg Greens',
  'Gulberg Residencia',
  'Capital Smart City',
  'Park View City',
  'Top City-1',
  'Naval Anchorage',
  'Media Town',
  'PWD Housing Society',
  'CBR Town',
  'Jinnah Gardens',
  'Pakistan Town',
  'Soan Garden',
  'Defence Residency',
  'Zaraj Housing Scheme',
  'The Centaurus Residence (F-8)',
  'Silver Oaks Apartments (F-10)',
  'Sector F-6',
  'Sector F-7',
  'Sector F-10',
  'Sector F-11',
  'Sector E-11',
  'Sector G-11',
  'Sector G-13',
  'Sector I-8',
];

const List<String> kBlockHints = [
  'Street 7, Phase 4',
  'Block C, Phase 2',
  'Sector A, Street 12',
  'Tower 3, Floor 5',
  'Street 22, Block B',
  'Park Road Block',
  'Civic Centre, Phase 7',
  'Street 9, Block D',
];

const List<String> kHouseHints = [
  '14',
  'A-203',
  '7-B',
  '112',
  'Flat 5',
  '36',
  'B-12',
  '241',
];

// --- Visitor Passes ---
const String kTypeGuest = 'Guest';
const String kTypeDelivery = 'Delivery';
const String kTypeCab = 'Cab / Ride';
const String kTypeDomestic = 'Domestic Help';
const String kTypeMaintenance = 'Maintenance';
const String kTypeRelative = 'Relative';

const List<String> kVisitorTypes = [
  kTypeGuest,
  kTypeDelivery,
  kTypeCab,
  kTypeDomestic,
  kTypeMaintenance,
  kTypeRelative,
];

const List<String> kDeliveryCompanies = [
  'foodpanda',
  'Daraz',
  'TCS',
  'Leopards Courier',
  'Trax',
  'PostEx',
  'Cheetay',
  'Bykea',
  'Pakistan Post',
  'Other',
];

const List<String> kRideServices = [
  'Careem',
  'inDrive',
  'Yango',
  'Bykea',
  'Private Taxi',
  'Other',
];

List<String> kCompaniesFor(String visitorType) {
  if (visitorType == kTypeDelivery) return kDeliveryCompanies;
  if (visitorType == kTypeCab) return kRideServices;
  return const [];
}

const Map<String, List<String>> kPurposeByType = {
  kTypeGuest: [
    'Family dinner',
    'Social visit',
    'Birthday party',
    'Business meeting',
    'Tutoring'
  ],
  kTypeDelivery: [
    'Food delivery',
    'Parcel delivery',
    'Grocery drop-off',
    'Document courier'
  ],
  kTypeCab: ['Pickup', 'Drop-off', 'Airport transfer'],
  kTypeDomestic: [
    'Daily household work',
    'Cooking',
    'Cleaning',
    'Driver duty',
    'Child care'
  ],
  kTypeMaintenance: [
    'AC servicing',
    'Plumbing repair',
    'Electrician visit',
    'Internet / PTCL fix',
    'Solar panel cleaning',
    'Water tank cleaning'
  ],
  kTypeRelative: [
    'Weekend stay',
    'Eid visit',
    'Family gathering',
    'Hospital visit'
  ],
};

// --- Recurring Passes (V2 Feature) ---
const Map<int, String> kRecurrenceDays = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

String formatRecurrence(List<int> days) {
  if (days.isEmpty) return 'One-time';
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && !days.contains(6) && !days.contains(7))
    return 'Weekdays';
  if (days.length == 2 && days.contains(6) && days.contains(7))
    return 'Weekends';

  final sorted = List<int>.from(days)..sort();
  return sorted.map((d) => kRecurrenceDays[d] ?? '').join(', ');
}

// --- Events ---
const List<String> kEventTypes = [
  'Wedding',
  'Mehndi',
  'Barat',
  'Walima',
  'Conference',
  'Corporate Dinner',
  'Seminar',
  'Birthday Party',
  'Concert',
  'Exhibition',
  'Iftar Dinner',
  'Other',
];

const List<String> kVenueTypes = [
  'Marquee',
  'Hotel',
  'Convention Centre',
  'Club',
  'Farmhouse',
  'Open Lawn',
  'Other',
];

const List<String> kVenueSuggestions = [
  'Serena Hotel Islamabad',
  'Islamabad Marriott Hotel',
  'Islamabad Club',
  'Jinnah Convention Centre',
  'Pak-China Friendship Centre',
  'Envoy Continental Hotel',
  'Ramada by Wyndham Islamabad',
  'Park Lane Hotel',
  'Hotel Margala',
  'Royal Marquee, Expressway',
  'Grand Orchid Marquee, I-8',
];

const List<String> kEventAddressHints = [
  'Khayaban-e-Suhrawardy, Islamabad',
  'Aga Khan Road, F-5/1, Islamabad',
  'Kashmir Highway, Sector G-6, Islamabad',
  'Islamabad Expressway, Zone 5',
  'Main Murree Road, Islamabad',
  'Sector I-8 Markaz, Islamabad',
];

const List<String> kTicketTiers = [
  'General',
  'VIP',
  'VVIP',
  'Family',
  'Speaker',
  'Staff / Crew',
  'Press',
];

const List<String> kPassCategories = [
  'Guest',
  'VIP',
  'Family',
  'Speaker',
  'Staff',
  'Press',
  'Vendor',
];

const List<String> kAgeRestrictions = ['None', '12+', '16+', '18+', '21+'];

const List<String> kDressCodes = [
  'Traditional (Shalwar Kameez)',
  'Formal',
  'Business Formal',
  'Semi-formal',
  'Casual',
  'Bridal Colours (Mehndi: yellow / green)',
];

// --- Guard & Verification ---
const List<String> kGateNames = [
  'Main Gate',
  'Gate 1',
  'Gate 2',
  'Service Gate',
  'Back Gate',
  'VIP Entrance',
  'Parking Entrance',
];

const List<String> kRejectReasons = [
  'Photo does not match',
  'Pass expired',
  'Pass already used',
  'Resident denied entry',
  'Wrong gate',
  'Suspicious behaviour',
  'Other',
];

// ============================================================================
// 3. EXAMPLE DATA (For rotating placeholders)
// ============================================================================

const List<String> kMaleFirstNames = [
  'Ahmed',
  'Bilal',
  'Hamza',
  'Usman',
  'Faisal',
  'Ali',
  'Zain',
  'Saad',
  'Omar',
  'Imran',
  'Talha',
  'Haider',
  'Shahid',
  'Adeel',
  'Waqas',
  'Danish',
];

const List<String> kFemaleFirstNames = [
  'Ayesha',
  'Fatima',
  'Hira',
  'Sana',
  'Maryam',
  'Nimra',
  'Rabia',
  'Zainab',
  'Mehwish',
  'Iqra',
  'Sadia',
  'Amna',
  'Khadija',
  'Laiba',
  'Noor',
  'Areeba',
];

const List<String> kSurnames = [
  'Khan',
  'Malik',
  'Chaudhry',
  'Qureshi',
  'Butt',
  'Siddiqui',
  'Awan',
  'Abbasi',
  'Mirza',
  'Gillani',
  'Raja',
  'Niazi',
  'Satti',
  'Rana',
  'Sheikh',
  'Bhatti',
];

const List<String> kSectorExamples = [
  'F-6',
  'F-7',
  'F-8',
  'F-10',
  'F-11',
  'G-6',
  'G-9',
  'G-10',
  'G-11',
  'E-7',
  'E-11',
  'D-12',
  'I-8',
  'I-10',
  'B-17',
];

const List<String> kPlateLetters = [
  'AB',
  'LE',
  'RK',
  'AX',
  'BC',
  'CD',
  'MN',
  'TS',
  'WA',
  'KZ',
];

const List<String> kOperatorPrefixes = [
  '0300',
  '0301',
  '0302',
  '0321',
  '0333',
  '0345',
  '0312',
  '0315',
  '0331',
  '0346',
];
