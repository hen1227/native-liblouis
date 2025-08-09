#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <cstring>

// Include liblouis headers
extern "C" {
#include "liblouis/liblouis.h"
}

#define LOG_TAG "LibLouisJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

static std::string lastError;

// Helper function to convert Java string to C string
std::string jstring2string(JNIEnv *env, jstring jStr) {
    if (!jStr) return "";

    const jclass stringClass = env->GetObjectClass(jStr);
    const jmethodID getBytes = env->GetMethodID(stringClass, "getBytes", "(Ljava/lang/String;)[B");
    const jbyteArray stringJbytes = (jbyteArray) env->CallObjectMethod(jStr, getBytes, env->NewStringUTF("UTF-8"));

    size_t length = (size_t) env->GetArrayLength(stringJbytes);
    jbyte* bytes = env->GetByteArrayElements(stringJbytes, JNI_FALSE);
    std::string ret = std::string((char*)bytes, length);
    env->ReleaseByteArrayElements(stringJbytes, bytes, JNI_FALSE);

    env->DeleteLocalRef(stringJbytes);
    env->DeleteLocalRef(stringClass);
    return ret;
}

// Helper function to convert C string to Java string
jstring string2jstring(JNIEnv *env, const std::string &str) {
    return env->NewStringUTF(str.c_str());
}

// Helper function to convert UTF-16 string to jstring
jstring utf16string2jstring(JNIEnv *env, const widechar *str, int len) {
    if (!str || len <= 0) return env->NewStringUTF("");

    // Convert widechar (uint16_t) to jchar
    std::vector<jchar> jchars(len);
    for (int i = 0; i < len; i++) {
        jchars[i] = static_cast<jchar>(str[i]);
    }

    return env->NewString(jchars.data(), len);
}

// Helper function to convert jstring to UTF-16
std::vector<widechar> jstring2utf16(JNIEnv *env, jstring jStr, int &outLen) {
    if (!jStr) {
        outLen = 0;
        return std::vector<widechar>();
    }

    const jchar* chars = env->GetStringChars(jStr, nullptr);
    jsize len = env->GetStringLength(jStr);

    std::vector<widechar> result(len);
    for (int i = 0; i < len; i++) {
        result[i] = static_cast<widechar>(chars[i]);
    }

    env->ReleaseStringChars(jStr, chars);
    outLen = len;
    return result;
}

// Fixed JNI function names to match the correct package name and @JvmStatic
extern "C" JNIEXPORT jboolean JNICALL
Java_com_henhen1227_nativeliblouis_NativeLiblouisModule_nativeSetDataPath(
    JNIEnv *env, jclass clazz, jstring jPath) {

    std::string path = jstring2string(env, jPath);
    LOGI("Setting liblouis data path to: %s", path.c_str());

    // Set log level for debugging
    lou_setLogLevel(LOU_LOG_ALL);

    // Set the data path
    char* cPath = const_cast<char*>(path.c_str());
    lou_setDataPath(cPath);

    LOGI("✅ Liblouis data path set successfully");
    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_henhen1227_nativeliblouis_NativeLiblouisModule_nativeTranslate(
    JNIEnv *env, jclass clazz, jstring jText, jstring jTable) {

    if (!jText || !jTable) {
        lastError = "Input text or table is null";
        LOGE("%s", lastError.c_str());
        return nullptr;
    }

    std::string table = jstring2string(env, jTable);

    // Convert input text to UTF-16
    int inLen;
    std::vector<widechar> inBuf = jstring2utf16(env, jText, inLen);

    if (inBuf.empty()) {
        return env->NewStringUTF("");
    }

    // Prepare output buffer (4x size should be sufficient)
    std::vector<widechar> outBuf(inLen * 4 + 1);
    int outLen = outBuf.size();
    int actualInLen = inLen;

    LOGD("Translating with table: %s, input length: %d", table.c_str(), inLen);

    // Call liblouis translate function
    int result = lou_translateString(
        table.c_str(),
        inBuf.data(), &actualInLen,
        outBuf.data(), &outLen,
        nullptr, nullptr, 0
    );

    if (result == 0) {
        lastError = "liblouis translation failed for table: " + table;
        LOGE("%s", lastError.c_str());
        return nullptr;
    }

    LOGD("Translation successful, output length: %d", outLen);

    // Convert result back to jstring
    return utf16string2jstring(env, outBuf.data(), outLen);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_henhen1227_nativeliblouis_NativeLiblouisModule_nativeBackTranslate(
    JNIEnv *env, jclass clazz, jstring jDots, jstring jTable) {

    if (!jDots || !jTable) {
        lastError = "Input dots or table is null";
        LOGE("%s", lastError.c_str());
        return nullptr;
    }

    std::string table = jstring2string(env, jTable);

    // Convert input dots to UTF-16
    int inLen;
    std::vector<widechar> inBuf = jstring2utf16(env, jDots, inLen);

    if (inBuf.empty()) {
        return env->NewStringUTF("");
    }

    // Prepare output buffer
    std::vector<widechar> outBuf(inLen * 4 + 1);
    int outLen = outBuf.size();
    int actualInLen = inLen;

    LOGD("Back-translating with table: %s, input length: %d", table.c_str(), inLen);

    // Call liblouis back-translate function
    int result = lou_backTranslateString(
        table.c_str(),
        inBuf.data(), &actualInLen,
        outBuf.data(), &outLen,
        nullptr, nullptr, 0
    );

    if (result == 0) {
        lastError = "liblouis back-translation failed for table: " + table;
        LOGE("%s", lastError.c_str());
        return nullptr;
    }

    LOGD("Back-translation successful, output length: %d", outLen);

    // Convert result back to jstring
    return utf16string2jstring(env, outBuf.data(), outLen);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_henhen1227_nativeliblouis_NativeLiblouisModule_nativeGetLastError(
    JNIEnv *env, jclass clazz) {

    if (lastError.empty()) {
        return nullptr;
    }

    jstring result = string2jstring(env, lastError);
    lastError.clear(); // Clear after reading
    return result;
}
