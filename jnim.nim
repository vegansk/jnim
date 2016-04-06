
import dynlib
import strutils
import typetraits
import macros
import os
import osproc

const jniHeader = "jni.h"

proc jFileOrDirExists(path: string): bool =
    when nimvm:
        let res = when defined(windows):
                staticExec("IF EXISTS \"" & path & "\" ( echo true ) ELSE ( echo false ) ")
            else:
                staticExec("if [ -e \"" & path & "\" ]; then echo true; else echo false; fi")
        result = res == "true"
    else:
        result = fileExists(path) or dirExists(path)

proc jExecProcess(path: string): string =
    when nimvm:
        result = staticExec(path)
    else:
        result = string(execProcess(path))

proc getJavaHome*(): string =
    if getEnv("JAVA_HOME").len > 0:
        result = getEnv("JAVA_HOME")
    elif jFileOrDirExists("/usr/libexec/java_home"):
        result = jExecProcess("/usr/libexec/java_home")
    elif jFileOrDirExists("/usr/lib/jvm/default-java"):
        result = "/usr/lib/jvm/default-java"

const JAVA_HOME = getJavaHome()
static: assert(JAVA_HOME.len > 0, "Java home not found")

{.warning[SmallLshouldNotBeUsed]: off.}

type
    jint* {.header: jniHeader.} = cint
    jsize* {.header: jniHeader.} = jint
    jchar* {.header: jniHeader.} = uint16
    jlong* {.header: jniHeader.} = int64
    jshort* {.header: jniHeader.} = int16
    jbyte* {.header: jniHeader.} = int8
    jfloat* {.header: jniHeader.} = cfloat
    jdouble* {.header: jniHeader.} = cdouble
    jboolean* {.header: jniHeader.} = uint8
    jclass* {.header: jniHeader.} = distinct pointer
    jmethodID* {.header: jniHeader.} = pointer
    jobject* {.header: jniHeader.} = pointer
    jfieldID* {.header: jniHeader.} = pointer
    jstring* {.header: jniHeader.} = jobject
    jthrowable* {.header: jniHeader.} = jobject
    jarray* {.header: jniHeader.} = jobject
    jobjectArray* {.header: jniHeader.} = jarray
    jbooleanArray* {.header: jniHeader.} = jarray
    jbyteArray* {.header: jniHeader.} = jarray
    jcharArray* {.header: jniHeader.} = jarray
    jshortArray* {.header: jniHeader.} = jarray
    jintArray* {.header: jniHeader.} = jarray
    jlongArray* {.header: jniHeader.} = jarray
    jfloatArray* {.header: jniHeader.} = jarray
    jdoubleArray* {.header: jniHeader.} = jarray

    jvalue* {.header: jniHeader, union.} = object
        z: jboolean
        b: jbyte
        c: jchar
        s: jshort
        i: jint
        j: jlong
        f: jfloat
        d: jdouble
        l: jobject

template get*(v: jvalue, T: typedesc): auto =
    when T is jboolean: v.z
    elif T is jbyte: v.b
    elif T is jchar: v.c
    elif T is jshort: v.s
    elif T is jint: v.i
    elif T is jlong: v.j
    elif T is jfloat: v.f
    elif T is jdouble: v.d
    elif T is jobject: v.l
    else:
        {.error: "wrong type".}

const JNINativeInterfaceImportName = when defined(android):
        "struct JNINativeInterface"
    else:
        "struct JNINativeInterface_"

type JavaVMPtr* {.header: jniHeader.} = pointer
type
    JNINativeInterface {.importc: JNINativeInterfaceImportName, nodecl, header: jniHeader, incompleteStruct.} = object
        reserved0: pointer
        reserved1: pointer
        reserved2: pointer
        reserved3: pointer

        GetVersion: proc(env: JNIEnvPtr): jint {.cdecl.}
        DefineClass:  proc(env: JNIEnvPtr, name: cstring, loader: jobject, buf: ptr jbyte, len: jsize): jclass {.cdecl.}

        FindClass: proc(env: JNIEnvPtr, name: cstring): jclass {.cdecl.}
        GetObjectClass: proc(env: JNIEnvPtr, obj: jobject): jclass {.cdecl.}
        NewStringUTF: proc(env: JNIEnvPtr, s: cstring): jstring {.cdecl.}
        GetStringUTFChars: proc(env: JNIEnvPtr, s: jstring, isCopy: ptr jboolean): cstring {.cdecl.}
        ReleaseStringUTFChars: proc(env: JNIEnvPtr, s: jstring, cstr: cstring) {.cdecl.}
        GetMethodID: proc(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID {.cdecl.}
        GetFieldID: proc(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID {.cdecl.}
        GetStaticFieldID: proc(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID {.cdecl.}
        GetObjectField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jobject {.cdecl.}
        GetBooleanField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jboolean {.cdecl.}
        GetByteField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jbyte {.cdecl.}
        GetCharField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jchar {.cdecl.}
        GetShortField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jshort {.cdecl.}
        GetIntField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jint {.cdecl.}
        GetLongField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jlong {.cdecl.}
        GetFloatField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jfloat {.cdecl.}
        GetDoubleField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jdouble {.cdecl.}
        SetObjectField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jobject) {.cdecl.}
        SetBooleanField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jboolean) {.cdecl.}
        SetByteField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jbyte) {.cdecl.}
        SetCharField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jchar) {.cdecl.}
        SetShortField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jshort) {.cdecl.}
        SetIntField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jint) {.cdecl.}
        SetLongField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jlong) {.cdecl.}
        SetFloatField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jfloat) {.cdecl.}
        SetDoubleField: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jdouble) {.cdecl.}
        GetStaticObjectField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jobject {.cdecl.}
        GetStaticBooleanField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jboolean {.cdecl.}
        GetStaticByteField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jbyte {.cdecl.}
        GetStaticCharField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jchar {.cdecl.}
        GetStaticShortField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jshort {.cdecl.}
        GetStaticIntField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jint {.cdecl.}
        GetStaticLongField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jlong {.cdecl.}
        GetStaticFloatField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jfloat {.cdecl.}
        GetStaticDoubleField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jdouble {.cdecl.}
        SetStaticObjectField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jobject) {.cdecl.}
        SetStaticBooleanField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jboolean) {.cdecl.}
        SetStaticByteField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jbyte) {.cdecl.}
        SetStaticCharField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jchar) {.cdecl.}
        SetStaticShortField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jshort) {.cdecl.}
        SetStaticIntField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jint) {.cdecl.}
        SetStaticLongField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jlong) {.cdecl.}
        SetStaticFloatField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jfloat) {.cdecl.}
        SetStaticDoubleField: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jdouble) {.cdecl.}
        GetStaticMethodID: proc(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID {.cdecl.}
        NewObjectArray: proc(env: JNIEnvPtr, size: jsize, clazz: jclass, init: jobject): jobjectArray {.cdecl.}
        GetObjectArrayElement: proc(env: JNIEnvPtr, arr: jobjectArray, index: jsize): jobject {.cdecl.}
        SetObjectArrayElement: proc(env: JNIEnvPtr, arr: jobjectArray, index: jsize, val: jobject) {.cdecl.}
        NewObjectA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}

        CallStaticVoidMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue) {.cdecl.}
        CallVoidMethodA: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue) {.cdecl.}

        CallStaticObjectMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}
        CallStaticBooleanMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jboolean {.cdecl.}
        CallStaticByteMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jbyte {.cdecl.}
        CallStaticCharMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jchar {.cdecl.}
        CallStaticShortMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jshort {.cdecl.}
        CallStaticIntMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jint {.cdecl.}
        CallStaticLongMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jlong {.cdecl.}
        CallStaticFloatMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jfloat {.cdecl.}
        CallStaticDoubleMethodA: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jdouble {.cdecl.}
        CallObjectMethodA: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}
        CallBooleanMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jboolean {.cdecl.}
        CallByteMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jbyte {.cdecl.}
        CallCharMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jchar {.cdecl.}
        CallShortMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jshort {.cdecl.}
        CallIntMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jint {.cdecl.}
        CallLongMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jlong {.cdecl.}
        CallFloatMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jfloat {.cdecl.}
        CallDoubleMethodA: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jdouble {.cdecl.}
        ExceptionOccurred: proc(env: JNIEnvPtr): jthrowable {.cdecl.}
        ExceptionDescribe: proc(env: JNIEnvPtr) {.cdecl.}
        ExceptionClear: proc(env: JNIEnvPtr) {.cdecl.}

        NewBooleanArray: proc(env: JNIEnvPtr, len: jsize): jbooleanArray {.cdecl.}
        NewByteArray: proc(env: JNIEnvPtr, len: jsize): jbyteArray {.cdecl.}
        NewCharArray: proc(env: JNIEnvPtr, len: jsize): jcharArray {.cdecl.}
        NewShortArray: proc(env: JNIEnvPtr, len: jsize): jshortArray {.cdecl.}
        NewIntArray: proc(env: JNIEnvPtr, len: jsize): jintArray {.cdecl.}
        NewLongArray: proc(env: JNIEnvPtr, len: jsize): jlongArray {.cdecl.}
        NewFloatArray: proc(env: JNIEnvPtr, len: jsize): jfloatArray {.cdecl.}
        NewDoubleArray: proc(env: JNIEnvPtr, len: jsize): jdoubleArray {.cdecl.}

        GetBooleanArrayElements: proc(env: JNIEnvPtr, arr: jbooleanArray, isCopy: ptr jboolean): ptr jboolean {.cdecl.}
        GetByteArrayElements: proc(env: JNIEnvPtr, arr: jbyteArray, isCopy: ptr jboolean): ptr jbyte {.cdecl.}
        GetCharArrayElements: proc(env: JNIEnvPtr, arr: jcharArray, isCopy: ptr jboolean): ptr jchar {.cdecl.}
        GetShortArrayElements: proc(env: JNIEnvPtr, arr: jshortArray, isCopy: ptr jboolean): ptr jshort {.cdecl.}
        GetIntArrayElements: proc(env: JNIEnvPtr, arr: jintArray, isCopy: ptr jboolean): ptr jint {.cdecl.}
        GetLongArrayElements: proc(env: JNIEnvPtr, arr: jlongArray, isCopy: ptr jboolean): ptr jlong {.cdecl.}
        GetFloatArrayElements: proc(env: JNIEnvPtr, arr: jfloatArray, isCopy: ptr jboolean): ptr jfloat {.cdecl.}
        GetDoubleArrayElements: proc(env: JNIEnvPtr, arr: jdoubleArray, isCopy: ptr jboolean): ptr jdouble {.cdecl.}

        ReleaseBooleanArrayElements: proc(env: JNIEnvPtr, arr: jbooleanArray, elems: ptr jboolean, mode: jint) {.cdecl.}
        ReleaseByteArrayElements: proc(env: JNIEnvPtr, arr: jbyteArray, elems: ptr jbyte, mode: jint) {.cdecl.}
        ReleaseCharArrayElements: proc(env: JNIEnvPtr, arr: jcharArray, elems: ptr jchar, mode: jint) {.cdecl.}
        ReleaseShortArrayElements: proc(env: JNIEnvPtr, arr: jshortArray, elems: ptr jshort, mode: jint) {.cdecl.}
        ReleaseIntArrayElements: proc(env: JNIEnvPtr, arr: jintArray, elems: ptr jint, mode: jint) {.cdecl.}
        ReleaseLongArrayElements: proc(env: JNIEnvPtr, arr: jlongArray, elems: ptr jlong, mode: jint) {.cdecl.}
        ReleaseFloatArrayElements: proc(env: JNIEnvPtr, arr: jfloatArray, elems: ptr jfloat, mode: jint) {.cdecl.}
        ReleaseDoubleArrayElements: proc(env: JNIEnvPtr, arr: jdoubleArray, elems: ptr jdouble, mode: jint) {.cdecl.}

        GetBooleanArrayRegion: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.cdecl.}
        GetByteArrayRegion: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.cdecl.}
        GetCharArrayRegion: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.cdecl.}
        GetShortArrayRegion: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.cdecl.}
        GetIntArrayRegion: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.cdecl.}
        GetLongArrayRegion: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.cdecl.}
        GetFloatArrayRegion: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.cdecl.}
        GetDoubleArrayRegion: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.cdecl.}

        SetBooleanArrayRegion: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.cdecl.}
        SetByteArrayRegion: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.cdecl.}
        SetCharArrayRegion: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.cdecl.}
        SetShortArrayRegion: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.cdecl.}
        SetIntArrayRegion: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.cdecl.}
        SetLongArrayRegion: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.cdecl.}
        SetFloatArrayRegion: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.cdecl.}
        SetDoubleArrayRegion: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.cdecl.}

        NewGlobalRef: proc(env: JNIEnvPtr, obj: jobject): jobject {.cdecl.}
        NewLocalRef: proc(env: JNIEnvPtr, obj: jobject): jobject {.cdecl.}
        DeleteGlobalRef: proc(env: JNIEnvPtr, obj: jobject) {.cdecl.}
        DeleteLocalRef: proc(env: JNIEnvPtr, obj: jobject) {.cdecl.}

    JNIEnvPtr* = ptr JNIEnv
    JNIEnv* = ptr JNINativeInterface

var currentEnv* : JNIEnvPtr

const JNI_INCLUDE_DIR = JAVA_HOME & "/include"

when defined macosx:
    {.passC: "-I" & JNI_INCLUDE_DIR.}
    {.emit: """
    #include <CoreFoundation/CoreFoundation.h>
    """.}
    {.passC: "-I" & JNI_INCLUDE_DIR & "/darwin".}
    {.passL: "-framework CoreFoundation".}
elif defined windows:
    {.passC: "-I\"" & JNI_INCLUDE_DIR & "\"".}
    {.passC: "-I\"" & JNI_INCLUDE_DIR & "/win32\"".}
elif defined linux:
    {.passC: "-I" & JNI_INCLUDE_DIR.}
    {.passC: "-I" & JNI_INCLUDE_DIR & "/linux".}

type JavaVM* = ref object of RootObj
    env*: JNIEnvPtr

type JavaVMOption* {.header: jniHeader.} = object
    optionString: cstring
    extraInfo: pointer

type JavaError* = object of Exception
    className*: string
    fullStackTrace*: string

proc `isNil`* (x: jclass): bool {.borrow.}

type JavaVMInitArgs* {.header: jniHeader.} = object
    version: jint

    nOptions: jint
    options: ptr JavaVMOption
    ignoreUnrecognized: jboolean

var JNI_VERSION_1_1* {.header: jniHeader.} : jint
var JNI_VERSION_1_2* {.header: jniHeader.} : jint
var JNI_VERSION_1_4* {.header: jniHeader.} : jint
var JNI_VERSION_1_6* {.header: jniHeader.} : jint
var JNI_VERSION_1_8* {.header: jniHeader.} : jint

var JNI_CreateJavaVM: proc (pvm: ptr JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl.}
var JNI_GetDefaultJavaVMInitArgs: proc(vm_args: ptr JavaVMInitArgs): jint {.cdecl.}
var JNI_GetCreatedJavaVMs: proc(vmBuf: ptr JavaVMPtr, bufLen: jsize, nVMs: ptr jsize): jint {.cdecl.}

when not defined(macosx):
    proc linkWithJVMModule(handle: LibHandle) =
        JNI_CreateJavaVM = cast[type(JNI_CreateJavaVM)](symAddr(handle, "JNI_CreateJavaVM"))
        JNI_GetDefaultJavaVMInitArgs = cast[type(JNI_GetDefaultJavaVMInitArgs)](symAddr(handle, "JNI_GetDefaultJavaVMInitArgs"))
        JNI_GetCreatedJavaVMs = cast[type(JNI_GetCreatedJavaVMs)](symAddr(handle, "JNI_GetCreatedJavaVMs"))

    proc findJVMLib(): string =
        let home = getJavaHome()
        when defined(windows):
            result = home & "\\bin\\client\\jvm.dll"
            if fileExists(result): return
            result = home & "\\bin\\server\\jvm.dll"
            if fileExists(result): return
            result = home & "\\jre\\bin\\client\\jvm.dll"
            if fileExists(result): return
            result = home & "\\jre\\bin\\server\\jvm.dll"
            if fileExists(result): return
        else:
            result = home & "/jre/lib/libjvm.so"
            if fileExists(result): return
            result = home & "/jre/lib/libjvm.dylib"
            if fileExists(result): return
            when hostCpu == "amd64":
                # Ubuntu
                result = home & "/jre/lib/amd64/jamvm/libjvm.so"
                if fileExists(result): return
                result = home & "/jre/lib/amd64/server/libjvm.so"
                if fileExists(result): return
        # libjvm not found
        result = nil

proc isJVMLoaded(): bool =
    not JNI_CreateJavaVM.isNil and not JNI_GetDefaultJavaVMInitArgs.isNil and
        not JNI_GetCreatedJavaVMs.isNil

proc linkWithJVMLib() =
    when defined(macosx):
        let libPath {.hint[XDeclaredButNotUsed]: off.}: cstring = getJavaHome() & "/../.."
        {.emit: """
        CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)`libPath`, strlen(`libPath`), true);
        if (url)
        {
            CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
            CFRelease(url);

            if (bundle)
            {
                `JNI_CreateJavaVM` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_CreateJavaVM"));
                `JNI_GetDefaultJavaVMInitArgs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetDefaultJavaVMInitArgs"));
                `JNI_GetCreatedJavaVMs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetCreatedJavaVMs"));
            }
        }
        """.}
    else:
        # First we try to find the JNI functions in the current process. We may already be linked with those.
        var handle = loadLib()
        if not handle.isNil:
            linkWithJVMModule(handle)

        if not isJVMLoaded():
            if not handle.isNil:
                unloadLib(handle)
            let libPath = findJVMLib()
            if not libPath.isNil:
                handle = loadLib(libPath)
                linkWithJVMModule(handle)

    if not isJVMLoaded():
        raise newException(Exception, "JVM could not be loaded")

proc getEnv(vm: JavaVMPtr, env: ptr JNIEnvPtr, version: jint): jint =
    {.emit: "`result` = (*((JavaVM*)`vm`))->GetEnv(`vm`, `env`, `version`);".}

template findClass*(env: JNIEnvPtr, name: cstring): jclass = env.FindClass(env, name)
template getObjectClass*(env: JNIEnvPtr, obj: jobject): jclass = env.GetObjectClass(env, obj)
template newString*(env: JNIEnvPtr, s: cstring): jstring = env.NewStringUTF(env, s)

proc getClassInCurrentEnv*(fullyQualifiedName: cstring): jclass =
    result = currentEnv.findClass(fullyQualifiedName)
    if result.isNil:
        raise newException(Exception, "Can not find class: " & $fullyQualifiedName)

proc getString*(env: JNIEnvPtr, s: jstring): string =
    if s != nil:
        var cstr = env.GetStringUTFChars(env, s, nil)
        result = $cstr
        env.ReleaseStringUTFChars(env, s, cstr)

template newGlobalRef*(env: JNIEnvPtr, obj: jobject): jobject = env.NewGlobalRef(env, obj)
template newLocalRef*(env: JNIEnvPtr, obj: jobject): jobject = env.NewLocalRef(env, obj)
template deleteGlobalRef*(env: JNIEnvPtr, obj: jobject) = env.DeleteGlobalRef(env, obj)
template deleteLocalRef*(env: JNIEnvPtr, obj: jobject) = env.DeleteLocalRef(env, obj)

template getMethodID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID =
    env.GetMethodID(env, clazz, name, sig)
template getFieldID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID =
    env.GetFieldID(env, clazz, name, sig)
template getStaticFieldID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID =
    env.GetStaticFieldID(env, clazz, name, sig)
template getStaticMethodID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID =
    env.GetStaticMethodID(env, clazz, name, sig)
template newObjectArray*(env: JNIEnvPtr, size: jsize, clazz: jclass, init: jobject): jobjectArray =
    env.NewObjectArray(env, size, clazz, init)

template getObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize): jobject =
    env.GetObjectArrayElement(env, arr, index)
template setObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize, val: jobject) =
    env.SetObjectArrayElement(env, arr, index, val)
proc setObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize, str: string) =
    let s = env.newString(str)
    env.setObjectArrayElement(arr, index, s)
    env.deleteLocalRef(s)

{.push stackTrace: off, inline.}
proc newObject*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jobject =
    env.NewObjectA(env, clazz, methodID, cast[ptr jvalue](unsafeAddr args))

proc callStaticVoidMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]) =
    env.CallStaticVoidMethodA(env, clazz, methodID, cast[ptr jvalue](unsafeAddr args))

proc callVoidMethod*(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: openarray[jvalue]) =
    env.CallVoidMethodA(env, obj, methodID, cast[ptr jvalue](unsafeAddr args))
{.pop.}

template exceptionOccurred*(env: JNIEnvPtr): jthrowable = env.ExceptionOccurred(env)
template exceptionDescribe*(env: JNIEnvPtr) = env.ExceptionDescribe(env)
template exceptionClear*(env: JNIEnvPtr) = env.ExceptionClear(env)

template declareProcsForType(T: typedesc, capitalizedTypeName: expr): stmt =
    template `get capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): T =
        env.`Get capitalizedTypeName Field`(env, obj, fieldId)

    template `set capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: T) =
        env.`Set capitalizedTypeName Field`(env, obj, fieldId, val)

    template `getStatic capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): T =
        env.`GetStatic capitalizedTypeName Field`(env, obj, fieldId)

    template `setStatic capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: T) =
        env.`SetStatic capitalizedTypeName Field`(env, obj, fieldId, val)

    template setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: T) =
        env.`set capitalizedTypeName Field`(obj, fieldId, val)

    template setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: T) =
        env.`setStatic capitalizedTypeName Field`(obj, fieldId, val)

    template `get capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): T =
        env.`getStatic capitalizedTypeName Field`(obj, fieldId)

    {.push stackTrace: off, inline.}
    proc `callStatic capitalizedTypeName Method`*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): T =
        env.`CallStatic capitalizedTypeName MethodA`(env, clazz, methodID, cast[ptr jvalue](unsafeAddr args))

    proc `call capitalizedTypeName Method`*(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: openarray[jvalue]): T =
        env.`Call capitalizedTypeName MethodA`(env, obj, methodID, cast[ptr jvalue](unsafeAddr args))
    {.pop.}

    template `call capitalizedTypeName Method`*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): T =
        env.`callStatic capitalizedTypeName Method`(clazz, methodID, args)

template declareProcsForTypeA(T: typedesc, ArrayT: typedesc, capitalizedTypeName: expr): stmt =
    declareProcsForType(T, capitalizedTypeName)

    template `New capitalizedTypeName Array`*(env: JNIEnvPtr, len: jsize): ArrayT =
        env.`New capitalizedTypeName Array`(env, len)

    template `get capitalizedTypeName ArrayElements`*(env: JNIEnvPtr, arr: ArrayT, isCopy: ptr jboolean): ptr T =
        env.`Get capitalizedTypeName ArrayElements`(env, arr, isCopy)

    template `release capitalizedTypeName ArrayElements`*(env: JNIEnvPtr, arr: ArrayT, elems: ptr T, mode: jint) =
        env.`Release capitalizedTypeName ArrayElements`(env, arr, elems, mode)

    template `get capitalizedTypeName ArrayRegion`*(env: JNIEnvPtr, arr: ArrayT, start, len: jsize, buf: ptr T) =
        env.`Get capitalizedTypeName ArrayRegion`(env, arr, start, len, buf)

    template newArrayOfType*(env: JNIEnvPtr, len: jsize, typSelector: typedesc[T]): ArrayT =
        env.`New capitalizedTypeName Array`(env, len)

    template setArrayRegion*(env: JNIEnvPtr, arr: ArrayT, start, len: jsize, buf: ptr T) =
        env.`Set capitalizedTypeName ArrayRegion`(env, arr, start, len, buf)

    template getArrayRegion*(env: JNIEnvPtr, arr: ArrayT, start, len: jsize, buf: ptr T) =
        env.`Get capitalizedTypeName ArrayRegion`(env, arr, start, len, buf)

declareProcsForType(jobject, Object)
declareProcsForTypeA(jint, jintArray, Int)
declareProcsForTypeA(jboolean, jbooleanArray, Boolean)
declareProcsForTypeA(jbyte, jbyteArray, Byte)
declareProcsForTypeA(jshort, jshortArray, Short)
declareProcsForTypeA(jlong, jlongArray, Long)
declareProcsForTypeA(jchar, jcharArray, Char)
declareProcsForTypeA(jfloat, jfloatArray, Float)
declareProcsForTypeA(jdouble, jdoubleArray, Double)

template callVoidMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]) =
    env.callStaticVoidMethod(clazz, methodID, args)

template toJValue*(s: string, res: var jvalue) =
    res.l = currentEnv.newString(s)

template toJValue*(s: cstring, res: var jvalue) =
    res.l = currentEnv.newString(s)

#template toJValue*(i: int, res: var jvalue) = res.i = i.jint

template toJValue*(v: cfloat, res: var jvalue) = res.f = v
template toJValue*(v: jdouble, res: var jvalue) = res.d = v
template toJValue*(v: jint, res: var jvalue) = res.i = v
template toJValue*(v: jlong, res: var jvalue) = res.j = v
template toJValue*(v: jboolean, res: var jvalue) = res.z = v
template toJValue*(v: jbyte, res: var jvalue) = res.b = v
template toJValue*(v: jchar, res: var jvalue) = res.c = v
template toJValue*(v: jshort, res: var jvalue) = res.s = v

proc toJValue*(a: openarray[string], res: var jvalue) =
    res.l = currentEnv.newObjectArray(a.len.jsize, currentEnv.findClass("java/lang/String"), nil)
    for i, v in a:
        currentEnv.setObjectArrayElement(res.l, i.jsize, v)

proc toJValue*(a: openarray[jobject], res: var jvalue) =
    assert(a.len > 0, "Unknown element type")
    let cl = currentEnv.getObjectClass(a[0])
    res.l = currentEnv.newObjectArray(a.len.jsize, cl, nil)
    for i, v in a:
        currentEnv.setObjectArrayElement(res.l, i.jsize, v)

type JPrimitiveType = jint | jfloat | jboolean | jdouble | jshort | jlong | jchar

proc toJValue*[T: JPrimitiveType](a: openarray[T], res: var jvalue) {.inline.} =
    res.l = currentEnv.newArrayOfType(a.len.jsize, T)
    var pt {.noinit.} : ptr T
    {.emit: "`pt` = `a`;".}
    currentEnv.setArrayRegion(res.l, 0, a.len.jsize, pt)

proc newJavaVM*(options: openarray[string] = []): JavaVM =
    linkWithJVMLib()
    result.new()

    var args: JavaVMInitArgs
    args.version = JNI_VERSION_1_6

    var opts = newSeq[JavaVMOption](options.len)
    for i, o in options:
        opts[i].optionString = o

    args.nOptions = options.len.jint
    if options.len > 0:
        args.options = addr opts[0]

    var vm : JavaVMPtr

    let res = JNI_CreateJavaVM(addr vm, cast[ptr pointer](addr result.env), addr args)
    if res < 0:
        result = nil
    else:
        currentEnv = result.env

template methodSignatureForType*(t: typedesc[jlong]): string = "J"
template methodSignatureForType*(t: typedesc[jint]): string = "I"
template methodSignatureForType*(t: typedesc[jboolean]): string = "Z"
template methodSignatureForType*(t: typedesc[bool]): string = "Z"
template methodSignatureForType*(t: typedesc[jbyte]): string = "B"
template methodSignatureForType*(t: typedesc[jchar]): string = "C"
template methodSignatureForType*(t: typedesc[jshort]): string = "S"
template methodSignatureForType*(t: typedesc[jfloat]): string = "F"
template methodSignatureForType*(t: typedesc[jdouble]): string = "D"
template methodSignatureForType*(t: typedesc[string]): string = "Ljava/lang/String;"
template methodSignatureForType*(t: typedesc[void]): string = "V"

proc elementTypeOfOpenArrayType[OpenArrayType](dummy: OpenArrayType = []): auto = dummy[0]
template methodSignatureForType*(t: typedesc[openarray]): string = "[" & methodSignatureForType(type(elementTypeOfOpenArrayType[t]()))

template getFieldOfType*(env: JNIEnvPtr, T: typedesc, o: expr, fieldId: jfieldID): expr =
    when T is jint:
        env.getIntField(o, fieldId)
    elif T is jlong:
        env.getLongField(o, fieldId)
    elif T is jboolean:
        env.getBooleanField(o, fieldId)
    elif T is jchar:
        env.getCharField(o, fieldId)
    elif T is jbyte:
        env.getByteField(o, fieldId)
    elif T is jshort:
        env.getShortField(o, fieldId)
    elif T is jfloat:
        env.getFloatField(o, fieldId)
    elif T is jdouble:
        env.getDoubleField(o, fieldId)
    elif T is string:
        env.getString(currentEnv.getObjectField(o, fieldId))
    else:
        T(env.getObjectField(o, fieldId))

template callMethodOfType*(env: JNIEnvPtr, T: typedesc, o: expr, methodId: jmethodID, args: openarray[jvalue]): expr =
    when T is jint:
        env.callIntMethod(o, methodID, args)
    elif T is jlong:
        env.callLongMethod(o, methodID, args)
    elif T is jboolean or T is bool:
        T(env.callBooleanMethod(o, methodID, args))
    elif T is jchar:
        env.callCharMethod(o, methodID, args)
    elif T is jbyte:
        env.callByteMethod(o, methodID, args)
    elif T is jshort:
        env.callShortMethod(o, methodID, args)
    elif T is jfloat:
        env.callFloatMethod(o, methodID, args)
    elif T is jdouble:
        env.callDoubleMethod(o, methodID, args)
    elif T is string:
        env.getString(currentEnv.callObjectMethod(o, methodID, args))
    elif T is void:
        env.callVoidMethod(o, methodID, args)
    else:
        T(env.callObjectMethod(o, methodID, args))

proc concatStrings(args: varargs[string]): string {.compileTime.} = args.join()

proc propertyGetter(name: string): string {.compileTime.} =
    result = ""
    if name[^1] != '=':
        result = name

proc propertySetter(name: string): string {.compileTime.} =
    result = ""
    if name[^1] == '=':
        result = name[0 .. ^2]

macro appendVarargToCall(c: expr, e: expr): expr =
    result = c
    for a in e.children:
        result.add(a)

proc findRunningVM() =
    if JNI_GetCreatedJavaVMs.isNil:
        linkWithJVMLib()

    var vmBuf: array[8, JavaVMPtr]
    var bufSize : jsize = 0
    discard JNI_GetCreatedJavaVMs(addr vmBuf[0], jsize(vmBuf.len), addr bufSize)
    if bufSize > 0:
        let res = vmBuf[0].getEnv(addr currentEnv, JNI_VERSION_1_6)
        if res != 0:
            raise newException(Exception, "getEnv result: " & $res)
        if currentEnv.isNil:
            raise newException(Exception, "No JVM found")
    else:
        raise newException(Exception, "No JVM is running")

proc checkForException()

template jniImpl(methodName: string, isStatic, isProperty: bool,
        obj: expr, argsSignature: string, args: openarray[jvalue],
        setterType: typedesc): stmt =
    const propGetter = when isProperty: propertyGetter(methodName) else: ""
    const propSetter = propertySetter(methodName)

    const propName = when propGetter.len > 0: propGetter else: propSetter
    const isCtor = methodName == "new"
    const isProp = propSetter.len > 0 or propGetter.len > 0

    const javaSymbolName = when isCtor:
            "<init>"
        elif isProp:
            propName
        else:
            methodName

    if currentEnv.isNil:
        findRunningVM()

    var fieldOrMethodId {.global.} = when isProp: jfieldID(nil) else: jmethodID(nil)

    const fullyQualifiedName = when isStatic:
            fullyQualifiedClassName(obj)
        else:
            fullyQualifiedClassName(type(obj))

    when isStatic:
        var clazz {.global.}: jclass

    if fieldOrMethodId.isNil:
        const retTypeSig = when isCtor or not declared(result):
                "V"
            else:
                methodSignatureForType(type(result))

        const sig = when propGetter.len > 0:
                retTypeSig
            elif propSetter.len > 0:
                argsSignature
            else:
                "(" & argsSignature & ")" & retTypeSig

        when isStatic:
            template localClazz(): var jclass = clazz
        else:
            var lc : jclass
            template localClazz(): var jclass = lc
        localClazz() = getClassInCurrentEnv(fullyQualifiedName)
        when isProp:
            when isStatic:
                const symbolKind = "static field"
                fieldOrMethodId = currentEnv.getStaticFieldID(localClazz(), javaSymbolName, sig)
            else:
                const symbolKind = "field"
                fieldOrMethodId = currentEnv.getFieldID(localClazz(), javaSymbolName, sig)
        elif isStatic and not isCtor:
            const symbolKind = "static method"
            fieldOrMethodId = currentEnv.getStaticMethodID(localClazz(), javaSymbolName, sig)
        else:
            const symbolKind = "method"
            fieldOrMethodId = currentEnv.getMethodID(localClazz(), javaSymbolName, sig)
        if fieldOrMethodId.isNil:
            raise newException(Exception, "Can not find " & symbolKind & ": " & fullyQualifiedName & "::" & javaSymbolName & ", sig: " & sig)

    let o = when isStatic: clazz else: jobject(obj)

    when propGetter.len > 0:
        result = currentEnv.getFieldOfType(type(result), o, fieldOrMethodId)
    elif propSetter.len > 0:
        currentEnv.setField(o, fieldOrMethodId, get(args[0], setterType))
    elif isCtor:
        result = type(result)(currentEnv.newObject(o, fieldOrMethodId, args))
    elif declared(result):
        result = currentEnv.callMethodOfType(type(result), o, fieldOrMethodId, args)
    else:
        currentEnv.callMethodOfType(void, o, fieldOrMethodId, args)

    checkForException()

proc nodeToString(e: NimNode): string {.compileTime.} =
    if e.kind == nnkIdent:
        result = $e
    elif e.kind == nnkAccQuoted:
        result = ""
        for s in e.children:
            result &= nodeToString(s)
    elif e.kind == nnkDotExpr:
        result = nodeToString(e[0]) & "." & nodeToString(e[1])
    elif e.kind == nnkInfix and $(e[0].toStrLit) == "$":
        result = nodeToString(e[1]) & "$" & nodeToString(e[2])
    else:
        echo treeRepr(e)
        assert(false, "Cannot stringize node")

proc consumePropertyPragma(e: NimNode): bool {.compileTime.} =
    let p = e.pragma
    for i in 0 ..< p.len:
        if p[i].kind == nnkIdent and $(p[i]) == "property":
            result = true
            p.del(i)
            break

proc consumeImportcPragma(e: NimNode): string {.compileTime.} =
    result = nil
    let p = e.pragma
    for i in 0 ..< p.len:
        if p[i].kind == nnkExprColonExpr and $(p[i][0]) == "importc":
            result = $(p[i][1])
            p.del(i)
            break

proc generateJNIProc(e: NimNode, exported: bool): NimNode {.compileTime.} =
    result = e
    let isStatic = e.params[1][1].kind == nnkBracketExpr
    let procName = nodeToString(result[0])
    if procName == "new":
        var className = ""
        if not isStatic:
            className = $(result.params[1][1])
        else:
            className = $(result.params[1][1][1])
        result.params[0] = ident(className)
    if exported:
        result[0] = if exported: ident(procName).postfix("*") else: ident(procName)

    let isProp = consumePropertyPragma(result)
    var realName = consumeImportcPragma(result)
    if realName == nil:
      realName = procName

    var numArgs = 0
    for i in 2 .. < result.params.len:
        numArgs += result.params[i].len - 2

    let paramsSym = genSym(nskVar, "params")

    let params = quote do:
        var `paramsSym` {.noinit.} : array[`numArgs`, jvalue]

    let argsSigNode = newCall(bindSym"concatStrings")

    let initParamsNode = newStmtList()
    var iParam = 0
    for i in 2 .. < result.params.len:
        for j in 0 .. < result.params[i].len - 2:
            let p = result.params[i][j]
            argsSigNode.add(newCall("methodSignatureForType", result.params[i][^2]))
            initParamsNode.add quote do:
                toJValue(`p`, `paramsSym`[`iParam`])
            inc iParam

    let setterType = newCall("type", if numArgs > 0:
            result.params[2][0]
        else:
            bindSym "jint"
        )

    let jniImplCall = newCall(bindsym"jniImpl", newLit(realName), newLit(isStatic), newLit(isProp), result.params[1][0], argsSigNode, paramsSym, setterType)

    result.body = newStmtList(params, initParamsNode, jniImplCall)

macro defineJNIType(className: expr, fullyQualifiedName: string, exported: static[bool]): stmt =
    result = newStmtList()
    if not exported:
        result.add quote do: {.push hints: off.}
    let fqn = ($fullyQualifiedName).replace(".", "/")
    let clsName = if exported: className.postfix("*") else: className
    let fqcn = if exported: ident("fullyQualifiedClassName").postfix("*") else: ident"fullyQualifiedClassName"
    let msft = if exported: ident("methodSignatureForType").postfix("*") else: ident"methodSignatureForType"
    let tjv = if exported: ident("toJValue").postfix("*") else: ident"toJValue"
    result.add quote do:
        type `clsName` = distinct jobject
        template `fqcn`(t: typedesc[`className`]): string = `fqn`
        template `msft`(t: typedesc[`className`]): string = "L" & fullyQualifiedClassName(t) & ";"
        template `tjv`(v: `className`, res: var jvalue) = res.l = jobject(v)
    if not exported:
       result.add quote do: {.pop.}

proc generateTypeDefinition(className: NimNode, fullyQualifiedName: string, exported: bool): NimNode {.compileTime.} =
    result = newCall(bindsym"defineJNIType", className, newLit(fullyQualifiedName), newLit(exported))

proc processJnimportNode(e: NimNode, exported: bool): NimNode {.compileTime.} =
    if e.kind == nnkDotExpr:
        result = generateTypeDefinition(e[1], nodeToString(e), exported)
    elif e.kind == nnkInfix:
        let opname = $(e[0].toStrLit)
        if  opname == "$":
            result = generateTypeDefinition(e[2], nodeToString(e), exported)
        elif opname == "as":
            result = generateTypeDefinition(e[2], nodeToString(e[1]), exported)
    elif e.kind == nnkIdent:
        result = generateTypeDefinition(e, $e, exported)
    elif e.kind == nnkImportStmt:
        result = processJnimportNode(e[0], exported)
    elif e.kind == nnkProcDef:
        result = generateJNIProc(e, exported)
    else:
        echo treeRepr(e)
        assert(false, "Invalid use of jnimport")

macro jnimport*(e: expr): stmt =
    if e.kind == nnkStmtList:
        result = newStmtList()
        for c in e.children:
            result.add(processJnimportNode(c, false))
    else:
        result = processJnimportNode(e, false)

macro jnimportEx*(e: expr): stmt =
    if e.kind == nnkStmtList:
        result = newStmtList()
        for c in e.children:
            result.add(processJnimportNode(c, true))
    else:
        result = processJnimportNode(e, true)

jnimport:
    import java.lang.Throwable
    import java.lang.StackTraceElement

    #proc getMessage(t: Throwable): string
    proc toString(t: Throwable): string

proc newExceptionWithJavaException(ex: jthrowable): ref JavaError =
    let mess = Throwable(ex).toString()
    result = newException(JavaError, mess)

proc checkForException() =
    let jex = currentEnv.exceptionOccurred()
    if jex != nil:
        currentEnv.exceptionClear()
        raise newExceptionWithJavaException(jex)
