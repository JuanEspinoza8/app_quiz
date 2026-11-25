# flutter_local_notifications guarda los avisos programados con Gson. Sin
# estas reglas, R8 borra la información de tipos genéricos en el build de
# release y el plugin falla con "Missing type parameter": los recordatorios no
# se programan y, al actualizar o reiniciar el teléfono, el receptor que los
# reprograma cierra la app ("keeps stopping").
# Reglas de la documentación del plugin y de Gson.

-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Los modelos del plugin se serializan por reflexión: si R8 les cambia los
# nombres de los campos, lo guardado por una versión no lo lee la siguiente.
-keep class com.dexterous.** { *; }
