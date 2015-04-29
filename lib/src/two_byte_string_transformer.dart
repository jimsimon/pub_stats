part of pub_stats;

class TwoByteStringTransformer extends TypeTransformer {

  @override
  decode(value) {
    return value as String;
  }

  @override
  encode(value) {
    return value as String;
  }
}