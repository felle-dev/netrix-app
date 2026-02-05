class NetworkUtils {
  static String getCountryFlag(String country) {
    // First check the country name to ISO code mapping
    final countryCode = _getCountryCode(country);

    if (countryCode != null && countryCode.length == 2) {
      // Convert ISO code to flag emoji
      // Flag emoji = Regional Indicator Symbol Letter
      // Each letter is represented by a Unicode code point
      return _convertCountryCodeToFlag(countryCode);
    }

    // Fallback to globe emoji
    return '🌍';
  }

  static String? _getCountryCode(String country) {
    // Comprehensive country name to ISO 3166-1 alpha-2 code mapping
    final countryToCode = {
      // Americas
      'United States': 'US',
      'USA': 'US',
      'Canada': 'CA',
      'Mexico': 'MX',
      'Brazil': 'BR',
      'Argentina': 'AR',
      'Chile': 'CL',
      'Colombia': 'CO',
      'Peru': 'PE',
      'Venezuela': 'VE',
      'Ecuador': 'EC',
      'Bolivia': 'BO',
      'Paraguay': 'PY',
      'Uruguay': 'UY',
      'Costa Rica': 'CR',
      'Panama': 'PA',
      'Cuba': 'CU',
      'Dominican Republic': 'DO',
      'Jamaica': 'JM',
      'Puerto Rico': 'PR',

      // Europe
      'Albania': 'AL',
      'United Kingdom': 'GB',
      'UK': 'GB',
      'Germany': 'DE',
      'GERMAN': 'DE', // Added alternate name
      'France': 'FR',
      'FRANCE': 'FR', // Added uppercase variant
      'Italy': 'IT',
      'Spain': 'ES',
      'SPANISH': 'ES', // Added alternate name
      'Portugal': 'PT',
      'The Netherlands': 'NL',
      'Netherlands': 'NL', // Added
      'DUTCH': 'NL', // Added alternate name
      'Belgium': 'BE',
      'Switzerland': 'CH',
      'SWITZERLAND': 'CH', // Added uppercase variant
      'Austria': 'AT',
      'AUSTRIA': 'AT', // Added uppercase variant
      'Sweden': 'SE',
      'SWEDEN': 'SE', // Added uppercase variant
      'Norway': 'NO',
      'Denmark': 'DK',
      'DENMARK': 'DK', // Added uppercase variant
      'Finland': 'FI',
      'FINLAND': 'FI', // Added uppercase variant
      'Poland': 'PL',
      'POLAND': 'PL', // Added uppercase variant
      'Czech Republic': 'CZ',
      'Czechia': 'CZ',
      'CEKO': 'CZ', // Added alternate name
      'Hungary': 'HU',
      'HUNGARIA': 'HU', // Added alternate name
      'Romania': 'RO',
      'ROMANIA': 'RO', // Added uppercase variant
      'Bulgaria': 'BG',
      'BULGARIA': 'BG', // Added uppercase variant
      'Greece': 'GR',
      'Ireland': 'IE',
      'Iceland': 'IS',
      'ICELAND': 'IS', // Added uppercase variant
      'Croatia': 'HR',
      'Serbia': 'RS',
      'Ukraine': 'UA',
      'Russia': 'RU',
      'RUSIA': 'RU', // Added alternate spelling
      'Russian Federation': 'RU',
      'Belarus': 'BY',
      'Estonia': 'EE',
      'Latvia': 'LV',
      'Lithuania': 'LT',
      'Slovakia': 'SK',
      'SLOVAKIA': 'SK', // Added uppercase variant
      'Slovenia': 'SI',
      'Luxembourg': 'LU',
      'Malta': 'MT',
      'Cyprus': 'CY',

      // Asia
      'China': 'CN',
      'Japan': 'JP',
      'JAPAN': 'JP', // Added uppercase variant
      'South Korea': 'KR',
      'Korea, Republic of': 'KR',
      'North Korea': 'KP',
      'India': 'IN',
      'Indonesia': 'ID',
      'Thailand': 'TH',
      'Vietnam': 'VN',
      'Philippines': 'PH',
      'Malaysia': 'MY',
      'Singapore': 'SG',
      'SINGAPURA': 'SG', // Added alternate name
      'Taiwan': 'TW',
      'Hong Kong': 'HK',
      'Pakistan': 'PK',
      'Bangladesh': 'BD',
      'Sri Lanka': 'LK',
      'Myanmar': 'MM',
      'Cambodia': 'KH',
      'Laos': 'LA',
      'Mongolia': 'MN',
      'Nepal': 'NP',
      'Afghanistan': 'AF',

      // Middle East
      'Turkey': 'TR',
      'Israel': 'IL',
      'Iran': 'IR',
      'Iraq': 'IQ',
      'Saudi Arabia': 'SA',
      'UAE': 'AE',
      'United Arab Emirates': 'AE',
      'Kuwait': 'KW',
      'Qatar': 'QA',
      'Bahrain': 'BH',
      'Oman': 'OM',
      'Jordan': 'JO',
      'Lebanon': 'LB',
      'Syria': 'SY',
      'Yemen': 'YE',

      // Africa
      'Egypt': 'EG',
      'South Africa': 'ZA',
      'Nigeria': 'NG',
      'Kenya': 'KE',
      'Ethiopia': 'ET',
      'Morocco': 'MA',
      'Algeria': 'DZ',
      'Tunisia': 'TN',
      'Libya': 'LY',
      'Ghana': 'GH',
      'Tanzania': 'TZ',
      'Uganda': 'UG',
      'Senegal': 'SN',
      'Zimbabwe': 'ZW',
      'Angola': 'AO',
      'Mozambique': 'MZ',

      // Oceania
      'Australia': 'AU',
      'AUSTRALIA': 'AU', // Added uppercase variant
      'New Zealand': 'NZ',
      'Papua New Guinea': 'PG',
      'Fiji': 'FJ',
      'New Caledonia': 'NC',
      'French Polynesia': 'PF',
    };

    return countryToCode[country];
  }

  static String _convertCountryCodeToFlag(String countryCode) {
    // Convert 2-letter country code to flag emoji
    // Flag emoji uses Regional Indicator Symbol Letters
    // 🇦 = U+1F1E6 (A), 🇧 = U+1F1E7 (B), etc.

    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌍';

    final firstLetter = code.codeUnitAt(0);
    final secondLetter = code.codeUnitAt(1);

    // Regional Indicator Symbol base is 0x1F1E6 (🇦)
    // Offset from 'A' (0x41)
    const regionalBase = 0x1F1E6;
    const letterA = 0x41;

    if (firstLetter < letterA ||
        firstLetter > letterA + 25 ||
        secondLetter < letterA ||
        secondLetter > letterA + 25) {
      return '🌍';
    }

    return String.fromCharCode(regionalBase + (firstLetter - letterA)) +
        String.fromCharCode(regionalBase + (secondLetter - letterA));
  }

  static String maskIP(String ip, bool showFull) {
    if (ip == 'Unknown' || showFull) {
      return ip;
    }
    if (ip.length <= 8) {
      return ip;
    }
    return '${ip.substring(0, 4)}***.${ip.substring(ip.length - 4)}';
  }
}
