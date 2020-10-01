part of pdf;

class _CompressedStreamReader {
  //constructor
  _CompressedStreamReader(List<int> data, [bool noWrap]) {
    _data = data;
    _noWrap = noWrap ?? false;
    _initialize();
  }

  //Fields
  List<int> _data;
  bool _noWrap;
  int _offset;
  int _bufferedBits;
  int _buffer;
  List<int> _tempBuffer;
  int _maxUnsingedLimit;
  int _defHeaderMethodMask;
  int _windowSize;
  int _defHeaderInfoMask;
  int _maxValue;
  int _defHeaderFlagsFdict;
  bool _canReadNextBlock;
  bool _readingUncompressed;
  int _uncompressedDataLength;
  int _currentPosition;
  int _dataLength = 0;
  bool _canReadMoreData = true;
  bool _checkSumRead = false;
  int _checkSum = 1;
  List<int> _blockBuffer;
  _DecompressorHuffmanTree _currentLengthTree;
  _DecompressorHuffmanTree _currentDistanceTree;
  static const List<int> def_huffman_dyntree_repeat_bits = <int>[2, 3, 7];
  static const List<int> def_huffman_dyntree_repeat_minimums = <int>[3, 3, 11];
  static const List<int> def_huffman_repeat_length_base = <int>[
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    13,
    15,
    17,
    19,
    23,
    27,
    31,
    35,
    43,
    51,
    59,
    67,
    83,
    99,
    115,
    131,
    163,
    195,
    227,
    258
  ];
  static const List<int> def_huffman_repeat_length_extension = <int>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    1,
    1,
    2,
    2,
    2,
    2,
    3,
    3,
    3,
    3,
    4,
    4,
    4,
    4,
    5,
    5,
    5,
    5,
    0
  ];
  static const List<int> def_huffman_repeat_distanse_base = <int>[
    1,
    2,
    3,
    4,
    5,
    7,
    9,
    13,
    17,
    25,
    33,
    49,
    65,
    97,
    129,
    193,
    257,
    385,
    513,
    769,
    1025,
    1537,
    2049,
    3073,
    4097,
    6145,
    8193,
    12289,
    16385,
    24577
  ];
  static const List<int> def_huffman_repeat_distanse_extension = <int>[
    0,
    0,
    0,
    0,
    1,
    1,
    2,
    2,
    3,
    3,
    4,
    4,
    5,
    5,
    6,
    6,
    7,
    7,
    8,
    8,
    9,
    9,
    10,
    10,
    11,
    11,
    12,
    12,
    13,
    13
  ];
  static const int def_huffman_repeat_max = 258;
  static const int def_huffman_end_block = 256;
  static const int def_huffman_length_minimum_code = 257;
  static const int def_huffman_length_maximum_code = 285;

  //Implementation
  void _initialize() {
    _offset = 0;
    _bufferedBits = 0;
    _buffer = 0;
    _windowSize = 0;
    _maxUnsingedLimit = 4294967295;
    _tempBuffer = List<int>.filled(4, 0, growable: true);
    _canReadNextBlock = true;
    _canReadMoreData = true;
    _readingUncompressed = false;
    _defHeaderMethodMask = 15 << 8;
    _defHeaderInfoMask = 240 << 8;
    _maxValue = 65535;
    _defHeaderFlagsFdict = 32;
    _currentPosition = 0;
    _blockBuffer = List<int>.filled(65535, 0, growable: true);
    if (!_noWrap) {
      _readZlibHeader();
    }
    _decodeBlockHeader();
  }

  void _readZlibHeader() {
    final int header = _readInt16();
    if (header == -1) {
      throw ArgumentError.value(
          header, 'Header of the stream can not be read.');
    }
    if (header % 31 != 0) {
      throw ArgumentError.value(header, 'Header checksum illegal');
    }
    if ((header & _defHeaderMethodMask) != (8 << 8)) {
      throw ArgumentError.value(header, 'Unsupported compression method.');
    }
    _windowSize = pow(2, ((header & _defHeaderInfoMask) >> 12) + 8);
    if (_windowSize > _maxValue) {
      throw ArgumentError.value(
          header, 'Unsupported window size for deflate compression method.');
    }
    if ((header & _defHeaderFlagsFdict) >> 5 == 1) {
      throw ArgumentError.value(
          header, 'Custom dictionary is not supported at the moment.');
    }
  }

  bool _decodeBlockHeader() {
    if (!_canReadNextBlock) {
      return false;
    }
    final int finalBlock = _readBits(1);
    if (finalBlock == -1) {
      return false;
    }
    final int blockType = _readBits(2);
    if (blockType == -1) {
      return false;
    }
    _canReadNextBlock = finalBlock == 0;
    switch (blockType) {
      case 0:
        _readingUncompressed = true;
        _skipToBoundary();
        final int length = _readInt16Inverted();
        final int lengthComplement = _readInt16Inverted();

        if (length != (lengthComplement ^ 0xffff)) {
          throw const FormatException('Wrong block length.');
        }

        if (length > _maxValue) {
          throw ArgumentError.value(
              length, 'Uncompressed block length can not be more than 65535.');
        }

        _uncompressedDataLength = length;
        _currentLengthTree = null;
        _currentDistanceTree = null;
        break;
      case 1:
        _readingUncompressed = false;
        _uncompressedDataLength = -1;
        _currentLengthTree = _DecompressorHuffmanTree.lengthTree;
        _currentDistanceTree = _DecompressorHuffmanTree.distanceTree;
        break;
      case 2:
        _readingUncompressed = false;
        _uncompressedDataLength = -1;
        final Map<String, dynamic> result =
            _decodeDynamicHeader(_currentLengthTree, _currentDistanceTree);
        _currentLengthTree = result['lengthTree'];
        _currentDistanceTree = result['distanceTree'];
        break;
      default:
        throw ArgumentError.value(blockType, 'Wrong block type');
    }
    return true;
  }

  Map<String, dynamic> _decodeDynamicHeader(_DecompressorHuffmanTree lengthTree,
      _DecompressorHuffmanTree distanceTree) {
    List<int> arrDecoderCodeLengths;
    List<int> arrResultingCodeLengths;

    int bLastSymbol = 0;
    int iLengthsCount = _readBits(5);
    int iDistancesCount = _readBits(5);
    int iCodeLengthsCount = _readBits(4);

    if (iLengthsCount < 0 || iDistancesCount < 0 || iCodeLengthsCount < 0) {
      throw ArgumentError.value(iLengthsCount, 'Wrong dynamic huffman codes.');
    }

    iLengthsCount += 257;
    iDistancesCount += 1;

    final int iResultingCodeLengthsCount = iLengthsCount + iDistancesCount;
    arrResultingCodeLengths =
        List<int>.filled(iResultingCodeLengthsCount, 0, growable: true);
    arrDecoderCodeLengths = List<int>.filled(19, 0, growable: true);
    iCodeLengthsCount += 4;
    int iCurrentCode = 0;

    while (iCurrentCode < iCodeLengthsCount) {
      final int len = _readBits(3);

      if (len < 0) {
        throw ArgumentError.value(len, 'Wrong dynamic huffman codes.');
      }

      arrDecoderCodeLengths[
              _Utils.def_huffman_dyntree_codelengths_order[iCurrentCode++]] =
          len.toUnsigned(8);
    }
    final _DecompressorHuffmanTree treeInternalDecoder =
        _DecompressorHuffmanTree(arrDecoderCodeLengths);

    iCurrentCode = 0;

    int symbol = 0;
    for (;;) {
      bool bNeedBreak = false;

      while (((symbol = treeInternalDecoder._unpackSymbol(this)) & ~15) == 0) {
        arrResultingCodeLengths[iCurrentCode++] =
            bLastSymbol = symbol.toUnsigned(8);

        if (iCurrentCode == iResultingCodeLengthsCount) {
          bNeedBreak = true;
          break;
        }
      }

      if (bNeedBreak) {
        break;
      }

      if (symbol < 0) {
        throw ArgumentError.value(symbol, 'Wrong dynamic huffman codes.');
      }

      if (symbol >= 17) {
        bLastSymbol = 0;
      } else if (iCurrentCode == 0) {
        throw ArgumentError.value(iCurrentCode, 'Wrong dynamic huffman codes.');
      }

      final int _iRepSymbol = symbol - 16;
      final int bits = def_huffman_dyntree_repeat_bits[_iRepSymbol];

      int count = _readBits(bits);

      if (count < 0) {
        throw ArgumentError.value(count, 'Wrong dynamic huffman codes.');
      }

      count += def_huffman_dyntree_repeat_minimums[_iRepSymbol];

      if (iCurrentCode + count > iResultingCodeLengthsCount) {
        throw ArgumentError.value(iCurrentCode, 'Wrong dynamic huffman codes.');
      }

      while (count-- > 0) {
        arrResultingCodeLengths[iCurrentCode++] = bLastSymbol;
      }

      if (iCurrentCode == iResultingCodeLengthsCount) {
        break;
      }
    }

    final List<int> tempLengthArray =
        List<int>.filled(iLengthsCount, 0, growable: true);
    List.copyRange(
        tempLengthArray, 0, arrResultingCodeLengths, 0, iLengthsCount);
    lengthTree = _DecompressorHuffmanTree(tempLengthArray);

    final List<int> tempDistanceArray =
        List<int>.filled(iDistancesCount, 0, growable: true);
    List.copyRange(tempDistanceArray, 0, arrResultingCodeLengths, iLengthsCount,
        iLengthsCount + iDistancesCount);
    distanceTree = _DecompressorHuffmanTree(tempDistanceArray);

    return <String, dynamic>{
      'lengthTree': lengthTree,
      'distanceTree': distanceTree
    };
  }

  int _readInt16() {
    int result = _readBits(8) << 8;
    result |= _readBits(8);
    return result;
  }

  int _readBits(int count) {
    final int result = _peekBits(count);
    if (result == -1) {
      return -1;
    }
    _bufferedBits -= count;
    _buffer >>= count;
    return result;
  }

  int _peekBits(int count) {
    if (count < 0 || count > 32) {
      throw ArgumentError.value(count, 'count');
    }
    if (_bufferedBits < count) {
      _fillBuffer();
    }
    if (_bufferedBits < count) {
      return -1;
    }
    final int bitmask = (~(_maxUnsingedLimit << count)).toUnsigned(32);
    final int result = _buffer & bitmask;
    return result;
  }

  void _fillBuffer() {
    final int length =
        4 - (_bufferedBits >> 3) - (((_bufferedBits & 7) != 0) ? 1 : 0);
    if (length == 0) {
      return;
    }
    final Map<String, dynamic> readResult = _readBytes(_tempBuffer, 0, length);
    _tempBuffer = readResult['buffer'];
    final int bytesRead = readResult['count'];
    for (int i = 0; i < bytesRead; i++) {
      _buffer |= _tempBuffer[i].toUnsigned(32) << _bufferedBits;
      _bufferedBits += 8;
    }
  }

  int _readInt16Inverted() {
    int result = _readBits(8);
    result |= _readBits(8) << 8;
    return result;
  }

  int _readInt32() {
    int result = (_readBits(8) << 24).toUnsigned(32);
    result |= (_readBits(8) << 16).toUnsigned(32);
    result |= (_readBits(8) << 8).toUnsigned(32);
    result |= _readBits(8).toUnsigned(32);
    return result;
  }

  Map<String, dynamic> _readBytes(List<int> buffer, int offset, int count) {
    int readedCount = 0;
    if (offset < buffer.length && (offset + count) <= buffer.length) {
      for (int i = 0; i < count; i++) {
        final Map<String, dynamic> readResult = _readByte();
        if (readResult['hasRead']) {
          buffer[offset] = readResult['result'];
          offset++;
          readedCount++;
        } else {
          break;
        }
      }
    }
    return <String, dynamic>{'count': readedCount, 'buffer': buffer};
  }

  Map<String, dynamic> _readByte() {
    if (_offset < _data.length) {
      final int result = _data[_offset];
      _offset++;
      return <String, dynamic>{'hasRead': true, 'result': result};
    } else {
      return <String, dynamic>{'hasRead': false, 'result': -1};
    }
  }

  void _skipToBoundary() {
    _buffer >>= _bufferedBits & 7;
    _bufferedBits &= ~7;
  }

  void _skipBits(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'Bits count can not be less than zero.');
    }
    if (count == 0) {
      return;
    }
    if (count >= _bufferedBits) {
      count -= _bufferedBits;
      _bufferedBits = 0;
      _buffer = 0;
      // if something left, skip it.
      if (count > 0) {
        // Skip entire bytes.
        _offset += count >> 3;
        count &= 7;
        // Skip bits.
        if (count > 0) {
          _fillBuffer();
          _bufferedBits -= count;
          _buffer >>= count;
        }
      }
    } else {
      _bufferedBits -= count;
      _buffer >>= count;
    }
  }

  Map<String, dynamic> _read(List<int> buffer, int offset, int length) {
    ArgumentError.checkNotNull(buffer);
    if (offset < 0 || offset > buffer.length - 1) {
      throw ArgumentError.value(
          offset, 'Offset does not belong to specified buffer.');
    }
    if (length < 0 || length > buffer.length - offset) {
      throw ArgumentError.value(length, 'Length is illegal.');
    }
    final int initialLength = length;
    while (length > 0) {
      if (_currentPosition < _dataLength) {
        final int inBlockPosition = (_currentPosition % _maxValue).toInt();
        int dataToCopy =
            min(_maxValue - inBlockPosition, _dataLength - _currentPosition);
        dataToCopy = min(dataToCopy, length);

        // Copy data.
        List.copyRange(buffer, offset, _blockBuffer, inBlockPosition,
            inBlockPosition + dataToCopy);
        _currentPosition += dataToCopy;
        offset += dataToCopy;
        length -= dataToCopy;
      } else {
        if (!_canReadMoreData) {
          break;
        }

        final int oldDataLength = _dataLength;

        if (!_readingUncompressed) {
          if (!_readHuffman()) {
            break;
          }
        } else {
          if (_uncompressedDataLength == 0) {
            // If there is no more data in stream, just exit.
            if (!(_canReadMoreData = _decodeBlockHeader())) {
              break;
            }
          } else {
            // Position of the data end in block buffer.
            final int inBlockPosition = (_dataLength % _maxValue).toInt();
            final int dataToRead =
                min(_uncompressedDataLength, _maxValue - inBlockPosition);
            final int dataRead =
                _readPackedBytes(_blockBuffer, inBlockPosition, dataToRead);

            if (dataToRead != dataRead) {
              throw ArgumentError.value(
                  dataToRead, 'Not enough data in stream.');
            }

            _uncompressedDataLength -= dataRead;
            _dataLength += dataRead;
          }
        }
        if (oldDataLength < _dataLength) {
          final int start = (oldDataLength % _maxValue).toInt();
          final int end = (_dataLength % _maxValue).toInt();

          if (start < end) {
            _checksumUpdate(_blockBuffer, start, end - start);
          } else {
            _checksumUpdate(_blockBuffer, start, _maxValue - start);

            if (end > 0) {
              _checksumUpdate(_blockBuffer, 0, end);
            }
          }
        }
      }
    }
    if (!_canReadMoreData && !_checkSumRead && !_noWrap) {
      _skipToBoundary();
      if (_readInt32() != _checkSum) {
        throw const FormatException('Checksum check failed.');
      }
      _checkSumRead = true;
    }

    return <String, dynamic>{
      'length': initialLength - length,
      'buffer': buffer
    };
  }

  void _checksumUpdate(List<int> buffer, int offset, int length) {
    _checkSum =
        _ChecksumCalculator._checksumUpdate(_checkSum, buffer, offset, length);
  }

  int _readPackedBytes(List<int> buffer, int offset, int length) {
    ArgumentError.checkNotNull(buffer);

    if (offset < 0 || offset > buffer.length - 1) {
      throw ArgumentError.value(offset, '''Offset can not be less than zero or 
		  greater than buffer length - 1.''');
    }

    if (length < 0) {
      throw ArgumentError.value(length, 'Length can not be less than zero.');
    }

    if (length > buffer.length - offset) {
      throw ArgumentError.value(length, 'Length is too large.');
    }

    if ((_bufferedBits & 7) != 0) {
      throw ArgumentError.value(
          buffer, 'Reading of unalligned data is not supported.');
    }

    if (length == 0) {
      return 0;
    }

    int result = 0;

    while (_bufferedBits > 0 && length > 0) {
      buffer[offset++] = _buffer.toUnsigned(8);
      _bufferedBits -= 8;
      _buffer >>= 8;
      length--;
      result++;
    }

    if (length > 0) {
      final Map<String, dynamic> returnValue = _read(buffer, offset, length);
      result += returnValue['length'];
      buffer = returnValue['buffer'];
    }
    return result;
  }

  bool _readHuffman() {
    int free = _maxValue - (_dataLength - _currentPosition).toInt();
    bool dataRead = false;
    int symbol = 0;
    while (free >= def_huffman_repeat_max) {
      while (((symbol = _currentLengthTree._unpackSymbol(this)) & ~0xff) == 0) {
        _blockBuffer[_dataLength++ % _maxValue] = symbol.toUnsigned(8);
        dataRead = true;
        if (--free < def_huffman_repeat_max) {
          return true;
        }
      }

      if (symbol < def_huffman_length_minimum_code) {
        if (symbol < def_huffman_end_block) {
          throw ArgumentError.value(symbol, 'Illegal code.');
        }
        _canReadMoreData = _decodeBlockHeader();
        return dataRead | _canReadMoreData;
      }

      if (symbol > def_huffman_length_maximum_code) {
        throw ArgumentError.value(symbol, 'Illegal repeat code length.');
      }

      int iRepeatLength = def_huffman_repeat_length_base[
          symbol - def_huffman_length_minimum_code];

      int iRepeatExtraBits = def_huffman_repeat_length_extension[
          symbol - def_huffman_length_minimum_code];

      if (iRepeatExtraBits > 0) {
        final int extra = _readBits(iRepeatExtraBits);
        if (extra < 0) {
          throw ArgumentError.value(extra, 'Wrong data.');
        }
        iRepeatLength += extra;
      }

      // Unpack repeat distance.
      symbol = _currentDistanceTree._unpackSymbol(this);

      if (symbol < 0 || symbol > def_huffman_repeat_distanse_base.length) {
        throw ArgumentError.value(symbol, 'Wrong distance code.');
      }
      int iRepeatDistance = def_huffman_repeat_distanse_base[symbol];
      iRepeatExtraBits = def_huffman_repeat_distanse_extension[symbol];
      if (iRepeatExtraBits > 0) {
        final int extra = _readBits(iRepeatExtraBits);
        if (extra < 0) {
          throw ArgumentError.value(extra, 'Wrong data.');
        }
        iRepeatDistance += extra;
      }
      // Copy data in slow repeat mode
      for (int i = 0; i < iRepeatLength; i++) {
        _blockBuffer[_dataLength % _maxValue] =
            _blockBuffer[(_dataLength - iRepeatDistance) % _maxValue];
        _dataLength++;
        free--;
      }

      dataRead = true;
    }

    return dataRead;
  }
}
