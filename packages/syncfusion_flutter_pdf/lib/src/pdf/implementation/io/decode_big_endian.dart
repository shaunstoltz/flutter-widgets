part of pdf;

String _decodeBigEndian(List<int> bytes, [int offset = 0, int length]) {
  final List<int> codeUnits =
      _UtfbeDecoder(bytes, offset, length).decodeRemaining();
  final List<int> result = _convertCodeUnitsToCodePoints(codeUnits);
  return String.fromCharCodes(result);
}

List<int> _convertCodeUnitsToCodePoints(List<int> codeUnits,
    [int offset = 0, int length]) {
  final _UtfCodeUnitDecoder decoder =
      _UtfCodeUnitDecoder(_ByteRange(codeUnits, offset, length));
  final List<int> codePoints = List<int>(decoder.byteRange.remaining);
  int i = 0;
  while (decoder.moveNext) {
    codePoints[i++] = decoder._current;
  }
  if (i == codePoints.length) {
    return codePoints;
  } else {
    final List<int> cpt = List<int>(i);
    cpt.setRange(0, i, codePoints);
    return cpt;
  }
}

class _UtfbeDecoder {
  _UtfbeDecoder(List<int> encodedBytes, [int offset = 0, int length]) {
    length = (length ?? encodedBytes.length - offset);
    byteRange = _ByteRange(encodedBytes, offset, length);
    if (isBeBom(encodedBytes, offset, length)) {
      byteRange.skip(2);
    }
  }
  _ByteRange byteRange;
  final int rcPoint = 0xfffd;
  int _current;

  int get remaining => (byteRange.remaining + 1) ~/ 2;

  bool get moveNext {
    _current = null;
    final int remaining = byteRange.remaining;
    if (remaining == 0) {
      _current = null;
      return false;
    }
    if (remaining == 1) {
      byteRange.moveNext;
      if (rcPoint != null) {
        _current = rcPoint;
        return true;
      } else {
        throw ArgumentError('Invalid byte.');
      }
    }
    _current = decode();
    return true;
  }

  List<int> decodeRemaining() {
    final List<int> codeunits = List<int>(remaining);
    var i = 0;
    while (moveNext) {
      codeunits[i++] = _current;
    }
    if (i == codeunits.length) {
      return codeunits;
    } else {
      final List<int> tcu = List<int>(i);
      tcu.setRange(0, i, codeunits);
      return tcu;
    }
  }

  bool isBeBom(List<int> encodedBytes, [int offset = 0, int length]) {
    final int end = length != null ? offset + length : encodedBytes.length;
    return (offset + 2) <= end &&
        encodedBytes[offset] == 0xfe &&
        encodedBytes[offset + 1] == 0xff;
  }

  int decode() {
    byteRange.moveNext;
    final int first = byteRange.current;
    byteRange.moveNext;
    final int next = byteRange.current;
    return (first << 8) + next;
  }
}

class _ByteRange {
  _ByteRange(List<int> source, int offset, int length) {
    length = (length ?? source.length - offset);
    _source = source;
    _offset = offset - 1;
    _length = length;
    _end = offset + _length;
  }
  List<int> _source;
  int _offset;
  int _length;
  int _end;

  int get current => _source[_offset];
  bool get moveNext => ++_offset < _end;
  int get remaining => _end - _offset - 1;
  void skip([int count = 1]) {
    _offset += count;
  }

  void backup([int byte = 1]) {
    _offset -= byte;
  }
}

class _UtfCodeUnitDecoder {
  _UtfCodeUnitDecoder(this.byteRange);
  final _ByteRange byteRange;
  final int rcPoint = 0xfffd;
  int _current;

  bool get moveNext {
    _current = null;
    if (!byteRange.moveNext) {
      return false;
    }
    int value = byteRange.current;
    if (value < 0) {
      if (rcPoint != null) {
        _current = rcPoint;
      } else {
        throw ArgumentError('Invalid data');
      }
    } else if (value < 0xd800 || (value > 0xdfff && value <= 0xffff)) {
      _current = value;
    } else if (value < 0xdc00 && byteRange.moveNext) {
      final int nextValue = byteRange.current;
      if (nextValue >= 0xdc00 && nextValue <= 0xdfff) {
        value = (value - 0xd800) << 10;
        value += 0x10000 + (nextValue - 0xdc00);
        _current = value;
      } else {
        if (nextValue >= 0xd800 && nextValue < 0xdc00) {
          byteRange.backup();
        }
        if (rcPoint != null) {
          _current = rcPoint;
        } else {
          throw ArgumentError('Invalid data');
        }
      }
    } else if (rcPoint != null) {
      _current = rcPoint;
    } else {
      throw ArgumentError('Invalid data');
    }
    return true;
  }
}

List<int> _encodeBigEndian(String content) {
  final List<int> codeUnits = _codePointsToCodeUnits(content.codeUnits);
  final List<int> encodedBytes = List<int>(2 * codeUnits.length);
  int i = 0;
  for (final int value in codeUnits) {
    encodedBytes[i++] = (value & 0xff00) >> 8;
    encodedBytes[i++] = value & 0xff;
  }
  return encodedBytes;
}

List<int> _codePointsToCodeUnits(List<int> codePoints) {
  int eLength = 0;
  for (int i = 0; i < codePoints.length; i++) {
    final int value = codePoints[i];
    if ((value >= 0 && value < 0xd800) || (value > 0xdfff && value <= 0xffff)) {
      eLength++;
    } else if (value > 0xffff && value <= 0x10ffff) {
      eLength += 2;
    } else {
      eLength++;
    }
  }
  final List<int> buffer = List<int>(eLength);
  int j = 0;
  for (int i = 0; i < codePoints.length; i++) {
    final int value = codePoints[i];
    if ((value >= 0 && value < 0xd800) || (value > 0xdfff && value <= 0xffff)) {
      buffer[j++] = value;
    } else if (value > 0xffff && value <= 0x10ffff) {
      final int temp = value - 0x10000;
      buffer[j++] = 0xd800 + ((temp & 0xffc00) >> 10);
      buffer[j++] = 0xdc00 + (temp & 0x3ff);
    } else {
      buffer[j++] = 0xfffd;
    }
  }
  return buffer;
}
