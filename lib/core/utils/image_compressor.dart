import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// ضغط الصورة وتصغير أبعادها لتسريع الرفع والمعالجة بأعلى دقة OCR
  static Future<String> compressAndEncodeBase64(Uint8List rawBytes) async {
    // 1. فك ترميز الصورة
    final image = img.decodeImage(rawBytes);
    if (image == null) {
      return base64Encode(rawBytes);
    }

    // 2. تصغير الأبعاد إذا كانت أكبر من 1024 بكسل مع الحفاظ على النسبة
    img.Image resized = image;
    const int maxDimension = 1024;

    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: maxDimension);
      } else {
        resized = img.copyResize(image, height: maxDimension);
      }
    }

    // 3. ضغط بصيغة JPEG بجودة 80% (ممتازة لقراءة الأرقام وبحجم خفيف جداً ~150KB)
    final compressedBytes = img.encodeJpg(resized, quality: 80);

    // 4. تحويل الناتج إلى Base64
    return base64Encode(compressedBytes);
  }
}