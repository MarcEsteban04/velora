# ML Kit's text recognizer references the Chinese, Devanagari, Japanese and
# Korean models, which Velora doesn't bundle (receipts use Latin script).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
