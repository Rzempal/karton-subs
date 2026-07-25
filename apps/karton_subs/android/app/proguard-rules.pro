# Reguly R8 dla buildu release.

# ML Kit Text Recognition (szybka sciezka skanu, ADR-017): wtyczka Fluttera
# odwoluje sie do wszystkich wariantow jezykowych, a my dolaczamy tylko alfabet
# lacinski (com.google.mlkit:text-recognition). Pozostale sa deklarowane jako
# compileOnly, wiec R8 ich nie znajduje - i slusznie. Ma o nich nie krzyczec.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
