class KeyCase {
  const KeyCase(this.key, this.mask);
  final String key;
  final int mask;

  bool get command => mask & 1 != 0;
  bool get control => mask & 2 != 0;
  bool get option => mask & 4 != 0;
  bool get shift => mask & 8 != 0;

  String get chord => [
    if (command) 'super',
    if (control) 'ctrl',
    if (option) 'alt',
    if (shift) 'shift',
    key,
  ].join('+');

  String get browserChord => [
    if (command) 'Cmd',
    if (control) 'Ctrl',
    if (option) 'Alt',
    if (shift) 'Shift',
    if (key.length == 1 && RegExp('[a-z]').hasMatch(key))
      'Key${key.toUpperCase()}'
    else if (key.length == 1 && RegExp('[0-9]').hasMatch(key))
      'Digit$key'
    else
      const {
            'Return': 'Enter',
            'KP_Enter': 'NumpadEnter',
            'BackSpace': 'Backspace',
            'Left': 'ArrowLeft',
            'Right': 'ArrowRight',
            'Up': 'ArrowUp',
            'Down': 'ArrowDown',
            'Page_Up': 'PageUp',
            'Page_Down': 'PageDown',
            'space': 'Space',
            'minus': 'Minus',
            'equal': 'Equal',
            'bracketleft': 'BracketLeft',
            'bracketright': 'BracketRight',
            'semicolon': 'Semicolon',
            'apostrophe': 'Quote',
            'comma': 'Comma',
            'period': 'Period',
            'slash': 'Slash',
            'backslash': 'Backslash',
            'grave': 'Backquote',
          }[key] ??
          key,
  ].join('+');

  String? get manualReason {
    if (command &&
        const ['q', 'w', 'h', 'm', 'n', 'Tab', 'space'].contains(key)) {
      return 'Application, window or system command';
    }
    if (control &&
        const ['space', 'Up', 'Down', 'Left', 'Right'].contains(key)) {
      return 'Input source or Mission Control';
    }
    if (command && control && key == 'f') return 'Full screen';
    if (command && option && key == 'd') return 'Dock visibility';
    if (command && key == 'grave') return 'Cycle application windows';
    if (command &&
        control &&
        option &&
        const [
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          'comma',
          'period',
        ].contains(key)) {
      return 'Accessibility or display shortcut';
    }
    if (command && option && key == 'Escape') return 'Force Quit';
    if (command && shift && const ['3', '4', '5', '6'].contains(key)) {
      return 'Screenshot';
    }
    if (key.startsWith('F')) return 'Function or system key';
    return null;
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'mask': mask,
    'chord': chord,
    'browserChord': browserChord,
    'manualReason': manualReason,
  };
}

final matrixKeys = <String>[
  for (var code = 97; code <= 122; code++) String.fromCharCode(code),
  for (var n = 0; n <= 9; n++) '$n',
  'Return',
  'KP_Enter',
  'Tab',
  'Escape',
  'BackSpace',
  'Delete',
  'Left',
  'Right',
  'Up',
  'Down',
  'Home',
  'End',
  'Page_Up',
  'Page_Down',
  'space',
  'minus',
  'equal',
  'bracketleft',
  'bracketright',
  'semicolon',
  'apostrophe',
  'comma',
  'period',
  'slash',
  'backslash',
  'grave',
  for (var n = 1; n <= 12; n++) 'F$n',
];

List<KeyCase> buildKeyMatrix() => [
  for (var mask = 0; mask < 16; mask++)
    for (final key in matrixKeys) KeyCase(key, mask),
];
