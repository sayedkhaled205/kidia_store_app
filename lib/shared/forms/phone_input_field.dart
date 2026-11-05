bool isPhoneInputField(String key, String autocomplete) =>
    RegExp(r'(^|_)(phone|telephone|tel|mobile)(?:_?\d+)?$')
        .hasMatch(key.toLowerCase()) ||
    autocomplete.toLowerCase().split(RegExp(r'\s+')).any(
      (part) => part == 'tel' || part.startsWith('tel-'),
    );
