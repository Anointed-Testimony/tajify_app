import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/custom_toast.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _buttonController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isEmailMode = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  DateTime? _selectedDate;
  
  // Username availability checking
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String _usernameStatus = '';
  Timer? _usernameCheckTimer;
  
  // Phone number variables
  String _phoneNumber = '';
  String _countryCode = '+234';
  PhoneNumber _phoneNumberObj = PhoneNumber(isoCode: 'NG');
  
  // Country phone number limits
  final Map<String, Map<String, int>> _countryPhoneLimits = {
    'NG': {'min': 10, 'max': 11}, 'US': {'min': 10, 'max': 10},
    'GB': {'min': 10, 'max': 11}, 'CA': {'min': 10, 'max': 10},
    'AU': {'min': 9, 'max': 9}, 'IN': {'min': 10, 'max': 10},
    'ZA': {'min': 9, 'max': 9}, 'KE': {'min': 9, 'max': 9},
    'GH': {'min': 9, 'max': 9}, 'EG': {'min': 10, 'max': 11},
    'MA': {'min': 9, 'max': 9}, 'DZ': {'min': 9, 'max': 9},
    'TN': {'min': 8, 'max': 8}, 'LY': {'min': 8, 'max': 8},
    'SD': {'min': 9, 'max': 9}, 'ET': {'min': 9, 'max': 9},
    'UG': {'min': 9, 'max': 9}, 'TZ': {'min': 9, 'max': 9},
    'RW': {'min': 9, 'max': 9}, 'BI': {'min': 8, 'max': 8},
    'CM': {'min': 9, 'max': 9}, 'CI': {'min': 10, 'max': 10},
    'SN': {'min': 9, 'max': 9}, 'ML': {'min': 8, 'max': 8},
    'BF': {'min': 8, 'max': 8}, 'NE': {'min': 8, 'max': 8},
    'TD': {'min': 8, 'max': 8}, 'CF': {'min': 8, 'max': 8},
    'CG': {'min': 9, 'max': 9}, 'CD': {'min': 9, 'max': 9},
    'AO': {'min': 9, 'max': 9}, 'MZ': {'min': 9, 'max': 9},
    'ZW': {'min': 9, 'max': 9}, 'BW': {'min': 8, 'max': 8},
    'NA': {'min': 9, 'max': 9}, 'SZ': {'min': 8, 'max': 8},
    'LS': {'min': 8, 'max': 8}, 'MG': {'min': 9, 'max': 9},
    'MU': {'min': 8, 'max': 8}, 'SC': {'min': 7, 'max': 7},
    'KM': {'min': 7, 'max': 7}, 'DJ': {'min': 8, 'max': 8},
    'SO': {'min': 8, 'max': 8}, 'ER': {'min': 7, 'max': 7},
    'SS': {'min': 9, 'max': 9},
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Listen to text changes for form validation
    _nameController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
    
    // Listen to username changes for availability checking
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    _logoController.dispose();
    _formController.dispose();
    _buttonController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
    final isValid = _nameController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        (_isEmailMode ? _emailController.text.isNotEmpty : _phoneNumber.isNotEmpty) &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _selectedDate != null &&
        _passwordController.text == _confirmPasswordController.text;
    
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

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  void _onPhoneNumberChanged(PhoneNumber phoneNumber) {
    print('Phone number changed: ${phoneNumber.phoneNumber}');
    print('Country code: ${phoneNumber.dialCode}');
    print('ISO code: ${phoneNumber.isoCode}');
    
    // Only update if the phone number is actually different
    final newPhoneNumber = phoneNumber.phoneNumber ?? '';
    if (newPhoneNumber != _phoneNumber) {
      setState(() {
        _phoneNumber = newPhoneNumber;
        _countryCode = phoneNumber.dialCode ?? '+234';
        _phoneNumberObj = phoneNumber;
      });
      _validateForm();
    }
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    
    // Cancel previous timer
    _usernameCheckTimer?.cancel();
    
    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatus = '';
      });
      return;
    }
    
    if (username.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatus = 'Username must be at least 3 characters';
      });
      return;
    }
    
    // Set checking status
    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = 'Checking availability...';
    });
    
    // Debounce the API call
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(username);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    try {
      final authService = AuthService();
      final response = await authService.checkUsernameAvailability(username);
      
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          if (response['success'] == true) {
            _isUsernameAvailable = response['available'] == true;
            _usernameStatus = _isUsernameAvailable 
                ? 'Username is available' 
                : 'Username is already taken';
          } else {
            _isUsernameAvailable = false;
            _usernameStatus = 'Error checking availability';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = false;
          _usernameStatus = 'Error checking availability';
        });
      }
    }
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

  void _showCountryPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Select Country',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: _countryPhoneLimits.length,
              itemBuilder: (context, index) {
                final countryCode = _countryPhoneLimits.keys.elementAt(index);
                final countryName = _getCountryName(countryCode);
                final dialCode = _getDialCode(countryCode);
                
                return ListTile(
                  title: Text(
                    countryName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    dialCode,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () {
                    setState(() {
                      _countryCode = dialCode;
                      _phoneNumberObj = PhoneNumber(
                        isoCode: countryCode,
                        dialCode: dialCode,
                        phoneNumber: _phoneNumberObj.phoneNumber,
                      );
                    });
                    Navigator.of(context).pop();
                    _validateForm();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getDialCode(String countryCode) {
    final dialCodes = {
      'NG': '+234', 'US': '+1', 'GB': '+44', 'CA': '+1', 'AU': '+61', 'IN': '+91',
      'ZA': '+27', 'KE': '+254', 'GH': '+233', 'EG': '+20', 'MA': '+212',
      'DZ': '+213', 'TN': '+216', 'LY': '+218', 'SD': '+249', 'ET': '+251',
      'UG': '+256', 'TZ': '+255', 'RW': '+250', 'BI': '+257', 'CM': '+237',
      'CI': '+225', 'SN': '+221', 'ML': '+223', 'BF': '+226', 'NE': '+227',
      'TD': '+235', 'CF': '+236', 'CG': '+242', 'CD': '+243', 'AO': '+244',
      'MZ': '+258', 'ZW': '+263', 'BW': '+267', 'NA': '+264', 'SZ': '+268',
      'LS': '+266', 'MG': '+261', 'MU': '+230', 'SC': '+248', 'KM': '+269',
      'DJ': '+253', 'SO': '+252', 'ER': '+291', 'SS': '+211',
      'SL': '+232', 'LR': '+231', 'GN': '+224', 'GW': '+245', 'CV': '+238',
      'GM': '+220', 'TG': '+228', 'BJ': '+229', 'GA': '+241', 'GQ': '+240',
      'ST': '+239',
      'BR': '+55', 'AR': '+54', 'CL': '+56', 'CO': '+57', 'PE': '+51',
      'VE': '+58', 'EC': '+593', 'BO': '+591', 'PY': '+595', 'UY': '+598',
      'GY': '+592', 'SR': '+597', 'GF': '+594', 'FK': '+500',
      'DE': '+49', 'FR': '+33', 'IT': '+39', 'ES': '+34', 'NL': '+31',
      'BE': '+32', 'CH': '+41', 'AT': '+43', 'SE': '+46', 'NO': '+47',
      'DK': '+45', 'FI': '+358', 'PL': '+48', 'CZ': '+420', 'HU': '+36',
      'RO': '+40', 'BG': '+359', 'HR': '+385', 'SI': '+386', 'SK': '+421',
      'LT': '+370', 'LV': '+371', 'EE': '+372', 'IE': '+353', 'PT': '+351',
      'GR': '+30', 'CY': '+357', 'MT': '+356', 'LU': '+352', 'IS': '+354',
      'AL': '+355', 'MK': '+389', 'RS': '+381', 'ME': '+382', 'BA': '+387',
      'XK': '+383', 'MD': '+373', 'UA': '+380', 'BY': '+375', 'RU': '+7',
      'KZ': '+7', 'UZ': '+998', 'KG': '+996', 'TJ': '+992', 'TM': '+993',
      'AZ': '+994', 'GE': '+995', 'AM': '+374',
      'CN': '+86', 'JP': '+81', 'KR': '+82', 'PK': '+92', 'BD': '+880',
      'LK': '+94', 'NP': '+977', 'BT': '+975', 'MV': '+960', 'AF': '+93',
      'IR': '+98', 'IQ': '+964', 'SA': '+966', 'AE': '+971', 'QA': '+974',
      'KW': '+965', 'BH': '+973', 'OM': '+968', 'YE': '+967', 'JO': '+962',
      'LB': '+961', 'SY': '+963', 'PS': '+970', 'IL': '+972', 'TR': '+90',
      'TH': '+66', 'VN': '+84', 'MY': '+60', 'SG': '+65', 'ID': '+62',
      'PH': '+63', 'MM': '+95', 'KH': '+855', 'LA': '+856', 'BN': '+673',
      'TL': '+670', 'MN': '+976', 'KP': '+850', 'TW': '+886', 'HK': '+852',
      'MO': '+853',
      'NZ': '+64', 'FJ': '+679', 'PG': '+675', 'SB': '+677', 'VU': '+678',
      'NC': '+687', 'PF': '+689', 'TO': '+676', 'WS': '+685', 'KI': '+686',
      'TV': '+688', 'NR': '+674', 'PW': '+680', 'FM': '+691', 'MH': '+692',
      'CK': '+682', 'NU': '+683', 'TK': '+690', 'WF': '+681', 'AS': '+1',
      'GU': '+1', 'MP': '+1',
    };
    return dialCodes[countryCode] ?? '+1';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime.now().subtract(const Duration(days: 36500)), // 100 years ago
      lastDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF2A2A2A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _validateForm();
      });
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Debug: Print form data
      print('=== SIGNUP DEBUG ===');
      print('Name: ${_nameController.text}');
      print('Username: ${_usernameController.text}');
      print('Email: ${_emailController.text}');
      print('Phone: $_phoneNumber');
      print('Password: ${_passwordController.text}');
      print('Confirm Password: ${_confirmPasswordController.text}');
      print('Date of Birth: $_selectedDate');
      print('Is Email Mode: $_isEmailMode');
      print('===================');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Prepare registration data
      final registrationData = {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _isEmailMode ? _emailController.text.trim() : '',
        'phone': !_isEmailMode ? _phoneNumber : '',
        'dateOfBirth': _selectedDate!.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
        'password': _passwordController.text,
        'passwordConfirmation': _confirmPasswordController.text,
      };

      print('Registration Data: $registrationData');

      // Call registration API through AuthProvider
      final success = await authProvider.register(registrationData);

      print('Registration success: $success');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          print('Registration successful!');
          
          ToastService.showSuccessToast(context, 'Registration successful! Please check your email for verification.');
          
          // Navigate to OTP verification screen
          context.go('/otp-verification', extra: {
            'email': _isEmailMode ? _emailController.text.trim() : null,
            'phone': !_isEmailMode ? _phoneNumber : null,
            'purpose': 'registration',
            'userId': null, // Will be set during OTP verification
          });
        } else {
          print('Registration failed: ${authProvider.errorMessage}');
          ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Registration failed');
        }
      }
    } catch (e) {
      print('Registration error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastService.showErrorToast(context, 'Registration failed: ${e.toString()}');
      }
    }
  }

  // Social login handlers
  Future<void> _handleGoogleSignup() async {
    try {
      print('=== GOOGLE SIGNUP DEBUG ===');
      print('Starting Google signup process...');
      
      // Step 1: Initialize Google Sign In
      print('Step 1: Initializing Google Sign In...');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser != null) {
        print('✅ Google Sign In successful');
        print('Google User ID: ${googleUser.id}');
        print('Google User Email: ${googleUser.email}');
        print('Google User Display Name: ${googleUser.displayName}');
        print('Google User Photo URL: ${googleUser.photoUrl}');
        
        // Step 2: Get Google Authentication
        print('Step 2: Getting Google authentication...');
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        print('✅ Google authentication successful');
        print('Access Token: ${googleAuth.accessToken?.substring(0, 20)}...');
        print('ID Token: ${googleAuth.idToken?.substring(0, 20)}...');
        
        // Step 3: Prepare data for API call
        print('Step 3: Preparing data for API call...');
        final socialData = {
          'google_id': googleUser.id,
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
          'profile_picture': googleUser.photoUrl,
        };
        print('Social Data to send: $socialData');
        
        // Step 4: Call social login API through AuthProvider
        print('Step 4: Calling social login API through AuthProvider...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        print('AuthProvider instance created');
        
        print('Making API call to googleLogin...');
        final response = await authProvider.socialLogin(socialData);
        
        print('✅ API call completed');
        print('Social login success: $response');
        
        if (response) {
          print('✅ Google signup successful');
          print('User data: ${authProvider.user}');
          print('Token: ${authProvider.token?.substring(0, 20)}...');
          
          // Navigate to home or handle success
          print('Navigating to home screen...');
          // Navigation will be handled by the router redirect
        } else {
          print('❌ Google signup failed');
          print('Error message: ${authProvider.errorMessage}');
          
          // Show error
          ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Google signup failed');
        }
      } else {
        print('❌ Google Sign In cancelled by user');
        print('User cancelled the Google sign-in process');
      }
      
      print('=== END GOOGLE SIGNUP DEBUG ===');
    } catch (e) {
      print('=== GOOGLE SIGNUP ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error stack trace: ${StackTrace.current}');
      print('=== END GOOGLE SIGNUP ERROR ===');
      
      ToastService.showErrorToast(context, 'Google signup error: $e');
    }
  }

  Future<void> _handleFacebookSignup() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final userData = await FacebookAuth.instance.getUserData();
        
        // Call social login API through AuthProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final socialData = {
          'facebook_id': userData['id'],
          'email': userData['email'] ?? '',
          'name': userData['name'] ?? '',
          'profile_picture': userData['picture']?['data']?['url'],
        };
        
        final success = await authProvider.socialLogin(socialData);
        
        if (success) {
          // Navigation will be handled by the router redirect
        } else {
          // Show error
          ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Facebook signup failed');
        }
      }
    } catch (e) {
      ToastService.showErrorToast(context, 'Facebook signup error: $e');
    }
  }

  Future<void> _handleAppleSignup() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      // Call social login API through AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final socialData = {
        'apple_id': credential.userIdentifier ?? '',
        'email': credential.email ?? '',
        'name': '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim(),
      };
      
      final success = await authProvider.socialLogin(socialData);
      
      if (success) {
        // Navigation will be handled by the router redirect
      } else {
        // Show error
        ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Apple signup failed');
      }
    } catch (e) {
      ToastService.showErrorToast(context, 'Apple signup error: $e');
    }
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
                const SizedBox(height: 20),
                
                // Back button and title
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Logo
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2A2A2A),
                          Color(0xFF1A1A1A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/tajify_icon.png',
                        width: 50,
                        height: 50,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Form
                SlideTransition(
                  position: _formSlideAnimation,
                  child: Column(
                    children: [
                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Full Name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Username Field
                      _buildUsernameField(),
                      
                      const SizedBox(height: 20),
                      
                      // Email/Phone Toggle
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
                                    color: _isEmailMode ? Colors.amber : Colors.transparent,
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
                                    color: !_isEmailMode ? Colors.amber : Colors.transparent,
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
                      
                      const SizedBox(height: 20),
                      
                      // Email/Phone Field
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isEmailMode
                            ? _buildTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              )
                            : _buildPhoneField(),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Date of Birth Field
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : 'Date of Birth',
                                    style: TextStyle(
                                      color: _selectedDate != null ? Colors.white : Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Password Field
                      _buildPasswordField(
                        controller: _passwordController,
                        hintText: 'Password',
                        isVisible: _isPasswordVisible,
                        onToggleVisibility: _togglePasswordVisibility,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                            return 'Password must contain uppercase, lowercase, and number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Confirm Password Field
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        isVisible: _isConfirmPasswordVisible,
                        onToggleVisibility: _toggleConfirmPasswordVisibility,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Sign Up Button
                      ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_isLoading ? _handleSignup : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.amber.withOpacity(0.3),
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
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.go('/login');
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Social Login Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(
                            'assets/google.png',
                            'Google',
                            _handleGoogleSignup,
                          ),
                          _buildSocialButton(
                            'assets/facebook.png',
                            'Facebook',
                            _handleFacebookSignup,
                          ),
                          _buildSocialButton(
                            'assets/apple.png',
                            'Apple',
                            _handleAppleSignup,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
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
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
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
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white54),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54,
            ),
            onPressed: onToggleVisibility,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Username',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.alternate_email, color: Colors.white54),
              suffixIcon: _isCheckingUsername
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                    )
                  : _usernameStatus.isNotEmpty
                      ? Icon(
                          _isUsernameAvailable ? Icons.check_circle : Icons.error,
                          color: _isUsernameAvailable ? Colors.green : Colors.red,
                          size: 20,
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a username';
              }
              if (value.length < 3) {
                return 'Username must be at least 3 characters';
              }
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                return 'Username can only contain letters, numbers, and underscores';
              }
              if (_usernameStatus.isNotEmpty && !_isUsernameAvailable && !_isCheckingUsername) {
                return 'Username is already taken';
              }
              return null;
            },
          ),
        ),
        if (_usernameStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              _usernameStatus,
              style: TextStyle(
                color: _isCheckingUsername 
                    ? Colors.amber 
                    : _isUsernameAvailable 
                        ? Colors.green 
                        : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
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
      child: Row(
        children: [
          // Country code selector
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _countryCode,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          // Phone number input
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Enter your phone number',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              validator: _validatePhoneNumber,
              onChanged: (value) {
                setState(() {
                  _phoneNumber = _countryCode + value;
                  _phoneNumberObj = PhoneNumber(
                    isoCode: _phoneNumberObj.isoCode,
                    dialCode: _countryCode,
                    phoneNumber: value,
                  );
                });
                _validateForm();
              },
            ),
          ),
        ],
      ),
    );
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