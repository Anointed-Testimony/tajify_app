import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/custom_toast.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _buttonController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isEmailMode = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  
  // Phone number variables
  String _phoneNumber = '';
  String _countryCode = '+234'; // Default to Nigeria
  PhoneNumber _phoneNumberObj = PhoneNumber(isoCode: 'NG');
  
  // Social authentication
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // Country phone number limits (min, max)
  final Map<String, Map<String, int>> _countryPhoneLimits = {
    // Africa
    'NG': {'min': 10, 'max': 11}, // Nigeria
    'ZA': {'min': 9, 'max': 9},   // South Africa
    'KE': {'min': 9, 'max': 9},   // Kenya
    'GH': {'min': 9, 'max': 9},   // Ghana
    'EG': {'min': 10, 'max': 11}, // Egypt
    'MA': {'min': 9, 'max': 9},   // Morocco
    'DZ': {'min': 9, 'max': 9},   // Algeria
    'TN': {'min': 8, 'max': 8},   // Tunisia
    'LY': {'min': 8, 'max': 8},   // Libya
    'SD': {'min': 9, 'max': 9},   // Sudan
    'ET': {'min': 9, 'max': 9},   // Ethiopia
    'UG': {'min': 9, 'max': 9},   // Uganda
    'TZ': {'min': 9, 'max': 9},   // Tanzania
    'RW': {'min': 9, 'max': 9},   // Rwanda
    'BI': {'min': 8, 'max': 8},   // Burundi
    'CM': {'min': 9, 'max': 9},   // Cameroon
    'CI': {'min': 10, 'max': 10}, // Ivory Coast
    'SN': {'min': 9, 'max': 9},   // Senegal
    'ML': {'min': 8, 'max': 8},   // Mali
    'BF': {'min': 8, 'max': 8},   // Burkina Faso
    'NE': {'min': 8, 'max': 8},   // Niger
    'TD': {'min': 8, 'max': 8},   // Chad
    'CF': {'min': 8, 'max': 8},   // Central African Republic
    'CG': {'min': 9, 'max': 9},   // Republic of the Congo
    'CD': {'min': 9, 'max': 9},   // Democratic Republic of the Congo
    'AO': {'min': 9, 'max': 9},   // Angola
    'MZ': {'min': 9, 'max': 9},   // Mozambique
    'ZW': {'min': 9, 'max': 9},   // Zimbabwe
    'BW': {'min': 8, 'max': 8},   // Botswana
    'NA': {'min': 9, 'max': 9},   // Namibia
    'SZ': {'min': 8, 'max': 8},   // Eswatini
    'LS': {'min': 8, 'max': 8},   // Lesotho
    'MG': {'min': 9, 'max': 9},   // Madagascar
    'MU': {'min': 8, 'max': 8},   // Mauritius
    'SC': {'min': 7, 'max': 7},   // Seychelles
    'KM': {'min': 7, 'max': 7},   // Comoros
    'DJ': {'min': 8, 'max': 8},   // Djibouti
    'SO': {'min': 8, 'max': 8},   // Somalia
    'ER': {'min': 7, 'max': 7},   // Eritrea
    'SS': {'min': 9, 'max': 9},   // South Sudan
    'SL': {'min': 8, 'max': 8},   // Sierra Leone
    'LR': {'min': 8, 'max': 8},   // Liberia
    'GN': {'min': 8, 'max': 8},   // Guinea
    'GW': {'min': 7, 'max': 7},   // Guinea-Bissau
    'CV': {'min': 7, 'max': 7},   // Cape Verde
    'GM': {'min': 7, 'max': 7},   // Gambia
    'TG': {'min': 8, 'max': 8},   // Togo
    'BJ': {'min': 8, 'max': 8},   // Benin
    'GA': {'min': 8, 'max': 8},   // Gabon
    'GQ': {'min': 9, 'max': 9},   // Equatorial Guinea
    'ST': {'min': 7, 'max': 7},   // São Tomé and Príncipe
    
    // North America
    'US': {'min': 10, 'max': 10}, // United States
    'CA': {'min': 10, 'max': 10}, // Canada
    'MX': {'min': 10, 'max': 10}, // Mexico
    'GT': {'min': 8, 'max': 8},   // Guatemala
    'BZ': {'min': 7, 'max': 7},   // Belize
    'SV': {'min': 8, 'max': 8},   // El Salvador
    'HN': {'min': 8, 'max': 8},   // Honduras
    'NI': {'min': 8, 'max': 8},   // Nicaragua
    'CR': {'min': 8, 'max': 8},   // Costa Rica
    'PA': {'min': 8, 'max': 8},   // Panama
    'CU': {'min': 8, 'max': 8},   // Cuba
    'JM': {'min': 7, 'max': 7},   // Jamaica
    'HT': {'min': 8, 'max': 8},   // Haiti
    'DO': {'min': 10, 'max': 10}, // Dominican Republic
    'PR': {'min': 10, 'max': 10}, // Puerto Rico
    'TT': {'min': 7, 'max': 7},   // Trinidad and Tobago
    'BB': {'min': 7, 'max': 7},   // Barbados
    'GD': {'min': 7, 'max': 7},   // Grenada
    'LC': {'min': 7, 'max': 7},   // Saint Lucia
    'VC': {'min': 7, 'max': 7},   // Saint Vincent and the Grenadines
    'AG': {'min': 7, 'max': 7},   // Antigua and Barbuda
    'KN': {'min': 7, 'max': 7},   // Saint Kitts and Nevis
    'DM': {'min': 7, 'max': 7},   // Dominica
    
    // South America
    'BR': {'min': 10, 'max': 11}, // Brazil
    'AR': {'min': 10, 'max': 10}, // Argentina
    'CL': {'min': 9, 'max': 9},   // Chile
    'CO': {'min': 10, 'max': 10}, // Colombia
    'PE': {'min': 9, 'max': 9},   // Peru
    'VE': {'min': 10, 'max': 10}, // Venezuela
    'EC': {'min': 9, 'max': 9},   // Ecuador
    'BO': {'min': 8, 'max': 8},   // Bolivia
    'PY': {'min': 9, 'max': 9},   // Paraguay
    'UY': {'min': 8, 'max': 8},   // Uruguay
    'GY': {'min': 7, 'max': 7},   // Guyana
    'SR': {'min': 7, 'max': 7},   // Suriname
    'GF': {'min': 9, 'max': 9},   // French Guiana
    'FK': {'min': 5, 'max': 5},   // Falkland Islands
    
    // Europe
    'GB': {'min': 10, 'max': 11}, // United Kingdom
    'DE': {'min': 10, 'max': 12}, // Germany
    'FR': {'min': 10, 'max': 10}, // France
    'IT': {'min': 10, 'max': 10}, // Italy
    'ES': {'min': 9, 'max': 9},   // Spain
    'NL': {'min': 9, 'max': 9},   // Netherlands
    'BE': {'min': 9, 'max': 9},   // Belgium
    'CH': {'min': 9, 'max': 9},   // Switzerland
    'AT': {'min': 10, 'max': 13}, // Austria
    'SE': {'min': 9, 'max': 9},   // Sweden
    'NO': {'min': 8, 'max': 8},   // Norway
    'DK': {'min': 8, 'max': 8},   // Denmark
    'FI': {'min': 9, 'max': 9},   // Finland
    'PL': {'min': 9, 'max': 9},   // Poland
    'CZ': {'min': 9, 'max': 9},   // Czech Republic
    'HU': {'min': 9, 'max': 9},   // Hungary
    'RO': {'min': 9, 'max': 9},   // Romania
    'BG': {'min': 9, 'max': 9},   // Bulgaria
    'HR': {'min': 9, 'max': 9},   // Croatia
    'SI': {'min': 8, 'max': 8},   // Slovenia
    'SK': {'min': 9, 'max': 9},   // Slovakia
    'LT': {'min': 8, 'max': 8},   // Lithuania
    'LV': {'min': 8, 'max': 8},   // Latvia
    'EE': {'min': 8, 'max': 8},   // Estonia
    'IE': {'min': 9, 'max': 9},   // Ireland
    'PT': {'min': 9, 'max': 9},   // Portugal
    'GR': {'min': 10, 'max': 10}, // Greece
    'CY': {'min': 8, 'max': 8},   // Cyprus
    'MT': {'min': 8, 'max': 8},   // Malta
    'LU': {'min': 9, 'max': 9},   // Luxembourg
    'IS': {'min': 7, 'max': 7},   // Iceland
    'AL': {'min': 9, 'max': 9},   // Albania
    'MK': {'min': 8, 'max': 8},   // North Macedonia
    'RS': {'min': 9, 'max': 9},   // Serbia
    'ME': {'min': 8, 'max': 8},   // Montenegro
    'BA': {'min': 8, 'max': 8},   // Bosnia and Herzegovina
    'XK': {'min': 8, 'max': 8},   // Kosovo
    'MD': {'min': 8, 'max': 8},   // Moldova
    'UA': {'min': 9, 'max': 9},   // Ukraine
    'BY': {'min': 9, 'max': 9},   // Belarus
    'RU': {'min': 10, 'max': 10}, // Russia
    'KZ': {'min': 10, 'max': 10}, // Kazakhstan
    'UZ': {'min': 9, 'max': 9},   // Uzbekistan
    'KG': {'min': 9, 'max': 9},   // Kyrgyzstan
    'TJ': {'min': 9, 'max': 9},   // Tajikistan
    'TM': {'min': 8, 'max': 8},   // Turkmenistan
    'AZ': {'min': 9, 'max': 9},   // Azerbaijan
    'GE': {'min': 9, 'max': 9},   // Georgia
    'AM': {'min': 8, 'max': 8},   // Armenia
    
    // Asia
    'CN': {'min': 11, 'max': 11}, // China
    'JP': {'min': 10, 'max': 11}, // Japan
    'KR': {'min': 10, 'max': 11}, // South Korea
    'IN': {'min': 10, 'max': 10}, // India
    'PK': {'min': 10, 'max': 10}, // Pakistan
    'BD': {'min': 10, 'max': 11}, // Bangladesh
    'LK': {'min': 9, 'max': 9},   // Sri Lanka
    'NP': {'min': 10, 'max': 10}, // Nepal
    'BT': {'min': 8, 'max': 8},   // Bhutan
    'MV': {'min': 7, 'max': 7},   // Maldives
    'AF': {'min': 9, 'max': 9},   // Afghanistan
    'IR': {'min': 10, 'max': 10}, // Iran
    'IQ': {'min': 10, 'max': 10}, // Iraq
    'SA': {'min': 9, 'max': 9},   // Saudi Arabia
    'AE': {'min': 9, 'max': 9},   // United Arab Emirates
    'QA': {'min': 8, 'max': 8},   // Qatar
    'KW': {'min': 8, 'max': 8},   // Kuwait
    'BH': {'min': 8, 'max': 8},   // Bahrain
    'OM': {'min': 8, 'max': 8},   // Oman
    'YE': {'min': 9, 'max': 9},   // Yemen
    'JO': {'min': 9, 'max': 9},   // Jordan
    'LB': {'min': 8, 'max': 8},   // Lebanon
    'SY': {'min': 9, 'max': 9},   // Syria
    'PS': {'min': 9, 'max': 9},   // Palestine
    'IL': {'min': 9, 'max': 9},   // Israel
    'TR': {'min': 10, 'max': 10}, // Turkey
    'TH': {'min': 9, 'max': 9},   // Thailand
    'VN': {'min': 9, 'max': 10},  // Vietnam
    'MY': {'min': 9, 'max': 10},  // Malaysia
    'SG': {'min': 8, 'max': 8},   // Singapore
    'ID': {'min': 9, 'max': 12},  // Indonesia
    'PH': {'min': 10, 'max': 10}, // Philippines
    'MM': {'min': 9, 'max': 10},  // Myanmar
    'KH': {'min': 9, 'max': 9},   // Cambodia
    'LA': {'min': 10, 'max': 10}, // Laos
    'BN': {'min': 7, 'max': 7},   // Brunei
    'TL': {'min': 8, 'max': 8},   // Timor-Leste
    'MN': {'min': 8, 'max': 8},   // Mongolia
    'KP': {'min': 10, 'max': 10}, // North Korea
    'TW': {'min': 9, 'max': 9},   // Taiwan
    'HK': {'min': 8, 'max': 8},   // Hong Kong
    'MO': {'min': 8, 'max': 8},   // Macau
    
    // Oceania
    'AU': {'min': 9, 'max': 9},   // Australia
    'NZ': {'min': 8, 'max': 10},  // New Zealand
    'FJ': {'min': 7, 'max': 7},   // Fiji
    'PG': {'min': 8, 'max': 8},   // Papua New Guinea
    'SB': {'min': 7, 'max': 7},   // Solomon Islands
    'VU': {'min': 7, 'max': 7},   // Vanuatu
    'NC': {'min': 6, 'max': 6},   // New Caledonia
    'PF': {'min': 8, 'max': 8},   // French Polynesia
    'TO': {'min': 7, 'max': 7},   // Tonga
    'WS': {'min': 7, 'max': 7},   // Samoa
    'KI': {'min': 8, 'max': 8},   // Kiribati
    'TV': {'min': 7, 'max': 7},   // Tuvalu
    'NR': {'min': 7, 'max': 7},   // Nauru
    'PW': {'min': 7, 'max': 7},   // Palau
    'FM': {'min': 7, 'max': 7},   // Micronesia
    'MH': {'min': 7, 'max': 7},   // Marshall Islands
    'CK': {'min': 5, 'max': 5},   // Cook Islands
    'NU': {'min': 4, 'max': 4},   // Niue
    'TK': {'min': 4, 'max': 4},   // Tokelau
    'WF': {'min': 6, 'max': 6},   // Wallis and Futuna
    'AS': {'min': 10, 'max': 10}, // American Samoa
    'GU': {'min': 10, 'max': 10}, // Guam
    'MP': {'min': 10, 'max': 10}, // Northern Mariana Islands
    'PW': {'min': 7, 'max': 7},   // Palau
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Listen to text changes for form validation
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    
    // Check if already authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        context.go('/home');
      }
    });
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _formController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _buttonController.forward();
    });
  }

  void _validateForm() {
    final isValid = _isEmailMode 
        ? _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty
        : _phoneNumber.isNotEmpty && _passwordController.text.isNotEmpty;
    
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isEmailMode = !_isEmailMode;
      _validateForm();
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _onPhoneNumberChanged(PhoneNumber phoneNumber) {
    setState(() {
      _phoneNumber = phoneNumber.phoneNumber ?? '';
      _countryCode = phoneNumber.dialCode ?? '+234';
      _phoneNumberObj = phoneNumber;
    });
    _validateForm();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    
    // Remove any non-digit characters for length validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Get country limits
    final countryCode = _phoneNumberObj.isoCode ?? 'NG';
    final limits = _countryPhoneLimits[countryCode];
    
    if (limits != null) {
      final minLength = limits['min']!;
      final maxLength = limits['max']!;
      
      if (digitsOnly.length < minLength) {
        return 'Phone number must be at least $minLength digits for ${_getCountryName(countryCode)}';
      }
      
      if (digitsOnly.length > maxLength) {
        return 'Phone number cannot exceed $maxLength digits for ${_getCountryName(countryCode)}';
      }
    } else {
      // Default validation for countries not in our list
      if (digitsOnly.length < 8) {
        return 'Please enter a valid phone number';
      }
      if (digitsOnly.length > 15) {
        return 'Phone number is too long';
      }
    }
    
    return null;
  }

  String _getCountryName(String countryCode) {
    final countryNames = {
      'NG': 'Nigeria', 'US': 'United States', 'GB': 'United Kingdom',
      'CA': 'Canada', 'AU': 'Australia', 'IN': 'India', 'ZA': 'South Africa',
      'KE': 'Kenya', 'GH': 'Ghana', 'EG': 'Egypt', 'MA': 'Morocco',
      'DZ': 'Algeria', 'TN': 'Tunisia', 'LY': 'Libya', 'SD': 'Sudan',
      'ET': 'Ethiopia', 'UG': 'Uganda', 'TZ': 'Tanzania', 'RW': 'Rwanda',
      'BI': 'Burundi', 'CM': 'Cameroon', 'CI': 'Ivory Coast', 'SN': 'Senegal',
      'ML': 'Mali', 'BF': 'Burkina Faso', 'NE': 'Niger', 'TD': 'Chad',
      'CF': 'Central African Republic', 'CG': 'Republic of the Congo',
      'CD': 'Democratic Republic of the Congo', 'AO': 'Angola',
      'MZ': 'Mozambique', 'ZW': 'Zimbabwe', 'BW': 'Botswana',
      'NA': 'Namibia', 'SZ': 'Eswatini', 'LS': 'Lesotho', 'MG': 'Madagascar',
      'MU': 'Mauritius', 'SC': 'Seychelles', 'KM': 'Comoros', 'DJ': 'Djibouti',
      'SO': 'Somalia', 'ER': 'Eritrea', 'SS': 'South Sudan',
      'SL': 'Sierra Leone', 'LR': 'Liberia', 'GN': 'Guinea', 'GW': 'Guinea-Bissau',
      'CV': 'Cape Verde', 'GM': 'Gambia', 'TG': 'Togo', 'BJ': 'Benin',
      'GA': 'Gabon', 'GQ': 'Equatorial Guinea', 'ST': 'São Tomé and Príncipe',
      'BR': 'Brazil', 'AR': 'Argentina', 'CL': 'Chile', 'CO': 'Colombia',
      'PE': 'Peru', 'VE': 'Venezuela', 'EC': 'Ecuador', 'BO': 'Bolivia',
      'PY': 'Paraguay', 'UY': 'Uruguay', 'GY': 'Guyana', 'SR': 'Suriname',
      'GF': 'French Guiana', 'FK': 'Falkland Islands',
      'DE': 'Germany', 'FR': 'France', 'IT': 'Italy', 'ES': 'Spain',
      'NL': 'Netherlands', 'BE': 'Belgium', 'CH': 'Switzerland', 'AT': 'Austria',
      'SE': 'Sweden', 'NO': 'Norway', 'DK': 'Denmark', 'FI': 'Finland',
      'PL': 'Poland', 'CZ': 'Czech Republic', 'HU': 'Hungary', 'RO': 'Romania',
      'BG': 'Bulgaria', 'HR': 'Croatia', 'SI': 'Slovenia', 'SK': 'Slovakia',
      'LT': 'Lithuania', 'LV': 'Latvia', 'EE': 'Estonia', 'IE': 'Ireland',
      'PT': 'Portugal', 'GR': 'Greece', 'CY': 'Cyprus', 'MT': 'Malta',
      'LU': 'Luxembourg', 'IS': 'Iceland', 'AL': 'Albania', 'MK': 'North Macedonia',
      'RS': 'Serbia', 'ME': 'Montenegro', 'BA': 'Bosnia and Herzegovina',
      'XK': 'Kosovo', 'MD': 'Moldova', 'UA': 'Ukraine', 'BY': 'Belarus',
      'RU': 'Russia', 'KZ': 'Kazakhstan', 'UZ': 'Uzbekistan', 'KG': 'Kyrgyzstan',
      'TJ': 'Tajikistan', 'TM': 'Turkmenistan', 'AZ': 'Azerbaijan', 'GE': 'Georgia',
      'AM': 'Armenia',
      'CN': 'China', 'JP': 'Japan', 'KR': 'South Korea', 'IN': 'India',
      'PK': 'Pakistan', 'BD': 'Bangladesh', 'LK': 'Sri Lanka', 'NP': 'Nepal',
      'BT': 'Bhutan', 'MV': 'Maldives', 'AF': 'Afghanistan', 'IR': 'Iran',
      'IQ': 'Iraq', 'SA': 'Saudi Arabia', 'AE': 'United Arab Emirates',
      'QA': 'Qatar', 'KW': 'Kuwait', 'BH': 'Bahrain', 'OM': 'Oman',
      'YE': 'Yemen', 'JO': 'Jordan', 'LB': 'Lebanon', 'SY': 'Syria',
      'PS': 'Palestine', 'IL': 'Israel', 'TR': 'Turkey', 'TH': 'Thailand',
      'VN': 'Vietnam', 'MY': 'Malaysia', 'SG': 'Singapore', 'ID': 'Indonesia',
      'PH': 'Philippines', 'MM': 'Myanmar', 'KH': 'Cambodia', 'LA': 'Laos',
      'BN': 'Brunei', 'TL': 'Timor-Leste', 'MN': 'Mongolia', 'KP': 'North Korea',
      'TW': 'Taiwan', 'HK': 'Hong Kong', 'MO': 'Macau',
      'AU': 'Australia', 'NZ': 'New Zealand', 'FJ': 'Fiji', 'PG': 'Papua New Guinea',
      'SB': 'Solomon Islands', 'VU': 'Vanuatu', 'NC': 'New Caledonia',
      'PF': 'French Polynesia', 'TO': 'Tonga', 'WS': 'Samoa', 'KI': 'Kiribati',
      'TV': 'Tuvalu', 'NR': 'Nauru', 'PW': 'Palau', 'FM': 'Micronesia',
      'MH': 'Marshall Islands', 'CK': 'Cook Islands', 'NU': 'Niue', 'TK': 'Tokelau',
      'WF': 'Wallis and Futuna', 'AS': 'American Samoa', 'GU': 'Guam',
      'MP': 'Northern Mariana Islands', 'PW': 'Palau',
    };
    return countryNames[countryCode] ?? countryCode;
  }

  int _getMaxLengthForCountry(String countryCode) {
    final limits = _countryPhoneLimits[countryCode];
    return limits?['max'] ?? 15; // Default max length
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== LOGIN DEBUG ===');
      print('Starting login process...');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool success = false;

      if (_isEmailMode) {
        print('Using email login mode');
        success = await authProvider.loginWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        print('Using phone login mode');
        success = await authProvider.loginWithPhone(
          _phoneNumber,
          _passwordController.text,
        );
      }

      print('Login success: $success');
      print('AuthProvider error message: ${authProvider.errorMessage}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          print('Login successful, showing success toast');
          ToastService.showSuccessToast(context, 'Login successful!');
          
          // Force a small delay to ensure the auth state is properly set
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Force router refresh by navigating to home
          if (mounted) {
            context.go('/home');
          }
        } else {
          print('Login failed, showing error toast');
          final errorMessage = authProvider.errorMessage ?? 'Login failed';
          print('Error message to show: $errorMessage');
          ToastService.showErrorToast(context, errorMessage);
        }
      }
    } catch (e) {
      print('Login exception: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastService.showErrorToast(context, 'Login failed: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _buttonController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Logo and Title
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2A2A2A),
                              Color(0xFF1A1A1A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFB875FB).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/tajify_icon.png',
                            width: 80,
                            height: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue your journey',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Form
                SlideTransition(
                  position: _formSlideAnimation,
                  child: Column(
                    children: [
                      // Auth Mode Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleAuthMode,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isEmailMode ? Color(0xFFB875FB) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Email',
                                      style: TextStyle(
                                        color: _isEmailMode ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleAuthMode,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isEmailMode ? Color(0xFFB875FB) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Phone',
                                      style: TextStyle(
                                        color: !_isEmailMode ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Email/Phone Field
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isEmailMode
                            ? _buildEmailField()
                            : _buildPhoneField(),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Password Field
                      _buildPasswordField(),
                      
                      const SizedBox(height: 32),
                      
                      // Login Button
                      ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_isLoading ? _handleLogin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFB875FB),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Color(0xFFB875FB).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Forgot Password
                      TextButton(
                        onPressed: () {
                          context.go('/forgot-password');
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFB875FB).withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.go('/signup');
                            },
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Color(0xFFB875FB),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildEmailField() {
    return Container(
      key: const ValueKey('email'),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: 'Enter your email',
          hintStyle: TextStyle(color: Colors.white54),
          prefixIcon: Icon(Icons.email_outlined, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    final currentCountryCode = _phoneNumberObj.isoCode ?? 'NG';
    final maxLength = _getMaxLengthForCountry(currentCountryCode);
    
    return Container(
      key: const ValueKey('phone'),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InternationalPhoneNumberInput(
        onInputChanged: _onPhoneNumberChanged,
        initialValue: _phoneNumberObj,
        selectorConfig: const SelectorConfig(
          selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
          showFlags: true,
          setSelectorButtonAsPrefixIcon: true,
        ),
        inputDecoration: const InputDecoration(
          hintText: 'Enter your phone number',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        formatInput: false,
        keyboardType: TextInputType.phone,
        inputBorder: InputBorder.none,
        cursorColor: Colors.white,
        textStyle: const TextStyle(color: Colors.white, fontSize: 16),
        autoValidateMode: AutovalidateMode.disabled,
        selectorTextStyle: const TextStyle(color: Colors.white),
        searchBoxDecoration: const InputDecoration(
          hintText: 'Search country',
          hintStyle: TextStyle(color: Colors.white54),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Enter your password',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white54),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54,
            ),
            onPressed: _togglePasswordVisibility,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  // Social Login Handlers
  Future<void> _handleGoogleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final response = await _authService.googleLogin(
          googleId: googleUser.id,
          email: googleUser.email,
          name: googleUser.displayName ?? 'User',
          profilePicture: googleUser.photoUrl,
        );

        if (response['success']) {
          await _storageService.saveUserData(response['data']['user']);
          if (mounted) {
            context.go('/home');
          }
        } else {
          if (mounted) {
            ToastService.showErrorToast(context, response['message'] ?? 'Google login failed');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showErrorToast(context, 'Google login failed: ${e.toString()}');
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final userData = await FacebookAuth.instance.getUserData();
        
        final response = await _authService.facebookLogin(
          facebookId: userData['id'],
          email: userData['email'] ?? '',
          name: userData['name'] ?? 'User',
          profilePicture: userData['picture']?['data']?['url'],
        );

        if (response['success']) {
          await _storageService.saveUserData(response['data']['user']);
          if (mounted) {
            context.go('/home');
          }
        } else {
          if (mounted) {
            ToastService.showErrorToast(context, response['message'] ?? 'Facebook login failed');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showErrorToast(context, 'Facebook login failed: ${e.toString()}');
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final response = await _authService.appleLogin(
        appleId: credential.userIdentifier ?? '',
        email: credential.email ?? '',
        name: '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim(),
        profilePicture: null, // Apple doesn't provide profile picture
      );

      if (response['success']) {
        await _storageService.saveUserData(response['data']['user']);
        if (mounted) {
          context.go('/home');
        }
      } else {
        if (mounted) {
          ToastService.showErrorToast(context, response['message'] ?? 'Apple login failed');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showErrorToast(context, 'Apple login failed: ${e.toString()}');
      }
    }
  }

  Widget _buildSocialButton(String imagePath, String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            width: 28,
            height: 28,
          ),
        ),
      ),
    );
  }
} 