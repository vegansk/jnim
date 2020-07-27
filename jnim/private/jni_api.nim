import jni_wrapper, options, macros, strutils

export jni_wrapper

type
  JNIVersion* {.pure.} = enum
    v1_1 = JNI_VERSION_1_1.int,
    v1_2 = JNI_VERSION_1_2.int,
    v1_4 = JNI_VERSION_1_4.int,
    v1_6 = JNI_VERSION_1_6.int,
    v1_8 = JNI_VERSION_1_8.int

var initArgs: JavaVMInitArgs

# Options for another threads
var theVM: JavaVMPtr
var theEnv* {.threadVar}: JNIEnvPtr
var findClassOverride* {.threadVar.}: proc(env: JNIEnvPtr, name: cstring): JClass

proc initJNIThread* {.gcsafe.}

proc initJNIArgs(version: JNIVersion = JNIVersion.v1_6, options: openarray[string] = []) =
  ## Setup JNI API
  jniAssert(initArgs.version == 0, "JNI API already initialized, you must deinitialize it first")
  initArgs.version = version.jint
  initArgs.nOptions = options.len.jint
  if options.len != 0:
    var opts = cast[ptr UncheckedArray[JavaVMOption]](createShared(JavaVMOption, options.len))
    initArgs.options = addr opts[0]
    for i in 0 ..< options.len:
      opts[i].optionString = cast[cstring](allocShared(options[i].len + 1))
      opts[i].optionString[0] = '\0'
      if options[i].len != 0:
        copyMem(addr opts[i].optionString[0], unsafeAddr options[i][0], options[i].len + 1)

proc initJNI*(version: JNIVersion = JNIVersion.v1_6, options: openarray[string] = []) =
  ## Setup JNI API
  initJNIArgs(version, options)
  initJNIThread()

# This is not supported, as it said here: http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/invocation.html#destroy_java_vm:
# "As of JDK/JRE 1.1.2 unloading of the VM is not supported."
# Maybe it can be usefull with alternative implementations of JRE
when false:
  proc deinitJNI* =
    ## Deinitialize JNI API
    if theVM == nil:
      return
    jniCall theVM.DestroyJavaVM(theVM), "Error deinitializing JNI"
    # TODO: dealloc initArgs
    theVM = nil
    theEnv = nil

proc initJNIThread* =
  ## Setup JNI API thread
  if theEnv != nil:
    return
  if initArgs.version == 0:
    raise newJNIException("You must initialize JNI API before using it")

  if theVM == nil:
    # We need to link with JNI and so on
    linkWithJVMLib()
    jniCall JNI_CreateJavaVM(theVM.addr, cast[ptr pointer](theEnv.addr), initArgs.addr), "Error creating VM"
  else:
    # We need to attach current thread to JVM
    jniCall theVM.AttachCurrentThread(theVM, cast[ptr pointer](theEnv.addr), initArgs.addr), "Error attaching thread to VM"

proc deinitJNIThread* =
  ## Deinitialize JNI API thread
  if theEnv == nil:
    return
  discard theVM.DetachCurrentThread(theVM)
  theEnv = nil

proc isJNIThreadInitialized*: bool = theEnv != nil

proc findRunningVM() =
  if theVM.isNil:
    if JNI_GetCreatedJavaVMs.isNil:
        linkWithJVMLib()

    var vmBuf: array[1, JavaVMPtr]
    var bufSize : jsize = 0
    discard JNI_GetCreatedJavaVMs(addr vmBuf[0], jsize(vmBuf.len), addr bufSize)
    if bufSize > 0:
        theVM = vmBuf[0]
    else:
        raise newJNIException("No JVM is running. You must call initJNIThread before using JNI API.")

  let res = theVM.GetEnv(theVM, cast[ptr pointer](theEnv.addr), JNI_VERSION_1_6)
  if res == JNI_EDETACHED:
      initJNIArgs()
      initJNIThread()
  elif res != 0:
      raise newJNIException("GetEnv result: " & $res)
  if theEnv.isNil:
      raise newJNIException("No JVM found")

template checkInit* =
  if theEnv.isNil: findRunningVM()

template deleteLocalRef*(env: JNIEnvPtr, r: jobject) =
  env.DeleteLocalRef(env, r)

template deleteGlobalRef*(env: JNIEnvPtr, r: jobject) =
  env.DeleteGlobalRef(env, r)

template newGlobalRef*[T : jobject](env: JNIEnvPtr, r: T): T =
  cast[T](env.NewGlobalRef(env, r))

####################################################################################################
# Types
type
  JVMMethodID* = distinct jmethodID
  JVMFieldID* = distinct jfieldID
  JVMClass* = ref object
    cls: JClass
  JVMObject* {.inheritable.} = ref object
    obj: jobject
  JnimNonVirtual_JVMObject* {.inheritable.} = object # Not for public use!
    obj*: jobject
    # clazz*: JVMClass

####################################################################################################
# Exception handling

type
  JavaException* = object of Exception
    ex: JVMObject

proc toStringRaw*(o: JVMObject): string

proc newJavaException*(ex: JVMObject): ref JavaException =
  result = newException(JavaException, ex.toStringRaw)
  result.ex = ex

proc newJVMObject*(o: jobject): JVMObject
proc newJVMObjectConsumingLocalRef*(o: jobject): JVMObject

proc raiseJavaException() =
  let ex = theEnv.ExceptionOccurred(theEnv)
  theEnv.ExceptionClear(theEnv)
  raise newJavaException(newJVMObjectConsumingLocalRef(ex))

proc checkJVMException*(e: JNIEnvPtr) {.inline.} =
  if unlikely(theEnv.ExceptionCheck(theEnv) != JVM_FALSE):
    raiseJavaException()

template checkException() =
  assert(not theEnv.isNil)
  checkJVMException(theEnv)

template callVM*(s: untyped): untyped =
  let res = s
  checkException()
  res

####################################################################################################
# JVMMethodID type
template newJVMMethodID*(id: jmethodID): JVMMethodID = JVMMethodID(id)
template get*(id: JVMMethodID): jmethodID = jmethodID(id)

####################################################################################################
# JVMFieldID type
template newJVMFieldID*(id: jfieldID): JVMFieldID = JVMFieldID(id)
template get*(id: JVMFieldID): jfieldID = jfieldID(id)

####################################################################################################
# JVMClass type
proc freeClass(c: JVMClass) =
  if theEnv != nil:
    theEnv.deleteGlobalRef(c.cls)

proc newJVMClass*(c: JClass): JVMClass =
  assert(cast[pointer](c) != nil)
  result.new(freeClass)
  result.cls = theEnv.newGlobalRef(c)

proc findClass*(env: JNIEnvPtr, name: cstring): JClass =
  if not findClassOverride.isNil:
    result = findClassOverride(env, name)
  else:
    result = env.FindClass(env, name)

proc getByFqcn*(T: typedesc[JVMClass], name: cstring): JVMClass =
  ## Finds class by it's full qualified class name
  checkInit
  let c = callVM findClass(theEnv, name)
  result = c.newJVMClass
  theEnv.deleteLocalRef(c)

proc getByName*(T: typedesc[JVMClass], name: string): JVMClass =
  ## Finds class by it's name (not fqcn)
  T.getByFqcn(name.fqcn)

proc getJVMClass*(o: jobject): JVMClass {.inline.} =
  checkInit
  let c = callVM theEnv.GetObjectClass(theEnv, o)
  result = c.newJVMClass
  theEnv.deleteLocalRef(c)

proc get*(c: JVMClass): JClass =
  c.cls

# Static fields

proc getStaticFieldId*(c: JVMClass, name, sig: cstring): JVMFieldID =
  checkInit
  (callVM theEnv.GetStaticFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getStaticFieldId*(c: JVMClass, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getStaticFieldId(c, name, jniSig(t))

proc getFieldId*(c: JVMClass, name, sig: cstring): JVMFieldID =
  checkInit
  (callVM theEnv.GetFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getFieldId*(c: JVMClass, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getFieldId(c, name, jniSig(t))

proc getFieldId*(c: JVMObject, name, sig: cstring): JVMFieldID =
  checkInit
  let clazz = callVM theEnv.GetObjectClass(theEnv, c.obj)
  result = (callVM theEnv.GetFieldID(theEnv, clazz, name, sig)).newJVMFieldID
  theEnv.deleteLocalRef(clazz)

proc getFieldId*(c: JVMObject, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getFieldId(c, name, jniSig(t))

proc getMethodId*(c: JVMClass, name, sig: cstring): JVMMethodID =
  checkInit
  (callVM theEnv.GetMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc getMethodId*(c: JVMObject, name, sig: cstring): JVMMethodID =
  checkInit
  let clazz = callVM theEnv.GetObjectClass(theEnv, c.obj)
  result = (callVM theEnv.GetMethodID(theEnv, clazz, name, sig)).newJVMMethodID
  theEnv.deleteLocalRef(clazz)

proc getStaticMethodId*(c: JVMClass, name, sig: cstring): JVMMethodID =
  checkInit
  (callVM theEnv.GetStaticMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc callVoidMethod*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, id.get, a)
  checkException

proc callVoidMethod*(c: JVMClass, name, sig: cstring, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)
  checkException

proc newObject*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, id.get, a)).newJVMObjectConsumingLocalRef

proc newObject*(c: JVMClass, sig: cstring, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)).newJVMObjectConsumingLocalRef

proc newObjectRaw*(c: JVMClass, sig: cstring, args: openarray[jvalue] = []): jobject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)

####################################################################################################
# JVMObject type

proc jniSig*(T: typedesc[JVMObject]): string = sigForClass"java.lang.Object"

proc freeJVMObject*(o: JVMObject) =
  if o.obj != nil and theEnv != nil:
    theEnv.deleteGlobalRef(o.obj)
    o.obj = nil

proc free*(o: JVMObject) {.deprecated.} =
  o.freeJVMObject()

proc fromJObject*(T: typedesc[JVMObject], o: jobject): T =
  if o != nil:
    result.new(cast[proc(r: T) {.nimcall.}](freeJVMObject))
    checkInit
    result.obj = theEnv.newGlobalRef(o)

proc fromJObjectConsumingLocalRef*(T: typedesc[JVMObject], o: jobject): T =
  if not o.isNil:
    result = T.fromJObject(o)
    theEnv.deleteLocalRef(o)

proc newJVMObject*(o: jobject): JVMObject =
  JVMObject.fromJObject(o)

proc newJVMObjectConsumingLocalRef*(o: jobject): JVMObject =
  if not o.isNil:
    result = newJVMObject(o)
    theEnv.deleteLocalRef(o)

proc create*(t: typedesc[JVMObject], o: jobject): JVMObject = newJVMObject(o)

proc newJVMObject*(s: string): JVMObject =
  result = (callVM theEnv.NewStringUTF(theEnv, s)).newJVMObjectConsumingLocalRef

proc get*(o: JVMObject): jobject =
  assert(not o.obj.isNil)
  o.obj

proc getNoCreate*(o: JVMObject): jobject {.inline.} = o.obj

proc setObj*(o: JVMObject, obj: jobject) =
  assert(obj == nil or theEnv.GetObjectRefType(theEnv, obj) in {JNILocalRefType, JNIWeakGlobalRefType})
  o.obj = obj

proc toJValue*(o: JVMObject): jvalue =
  if not o.isNil:
    result = o.get.toJValue

proc getJVMClass*(o: JVMObject): JVMClass =
  assert(o.get != nil)
  getJVMClass(o.get)

proc equalsRaw*(v1, v2: JVMObject): jboolean =
  # This is low level ``equals`` version
  assert v1.obj != nil
  let cls = theEnv.GetObjectClass(theEnv, v1.obj)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  const sig = "($#)$#" % [jobject.jniSig, jboolean.jniSig]
  let mthId = theEnv.GetMethodID(theEnv, cls, "equals", sig)
  theEnv.deleteLocalRef(cls)
  jniAssertEx(mthId != nil, "Can't find ``equals`` method")
  var v2w = v2.obj.toJValue
  result = theEnv.CallBooleanMethodA(theEnv, v1.obj, mthId, addr v2w)

proc jstringToStringAux(s: jstring): string =
  assert(not s.isNil)
  let numBytes = theEnv.GetStringUTFLength(theEnv, s)
  result = newString(numBytes)
  if numBytes != 0:
    let numChars = theEnv.GetStringLength(theEnv, s)
    theEnv.GetStringUTFRegion(theEnv, s, 0, numChars, addr result[0])

proc toStringRaw(o: jobject): string =
  # This is low level ``toString`` version.
  assert(not o.isNil)
  let cls = theEnv.GetObjectClass(theEnv, o)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  const sig = "()" & string.jniSig
  let mthId = theEnv.GetMethodID(theEnv, cls, "toString", sig)
  theEnv.deleteLocalRef(cls)
  jniAssertEx(mthId != nil, "Can't find ``toString`` method")
  let s = theEnv.CallObjectMethodA(theEnv, o, mthId, nil).jstring
  if s == nil:
    return ""
  result = jstringToStringAux(s)
  theEnv.deleteLocalRef(s)

proc toStringRawConsumingLocalRef(o: jobject): string =
  # This is low level ``toString`` version
  if not o.isNil:
    result = toStringRaw(o)
    theEnv.deleteLocalRef(o)

proc toStringRaw(o: JVMObject): string =
  # This is low level ``toString`` version
  if o.isNil:
    return ""
  toStringRaw(o.obj)

proc callVoidMethod*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallVoidMethodA(theEnv, o.get, id.get, a)
  checkException

proc callVoidMethod*(o: JVMObject, name, sig: cstring, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallVoidMethodA(theEnv, o.get, o.getMethodId(name, sig).get, a)
  checkException

proc callVoidMethod*(o: JnimNonVirtual_JVMObject, c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallNonVirtualVoidMethodA(theEnv, o.obj, c.get, id.get, a)
  checkException

####################################################################################################
# Arrays support

type JVMArray[T] = ref object
  arr: jtypedArray[T]

proc get*[T](arr: JVMArray[T]): jtypedArray[T] = arr.arr
proc jniSig*[T](t: typedesc[JVMArray[T]]): string = "[" & jniSig(T)
proc freeJVMArray[T](a: JVMArray[T]) =
  if a.arr != nil and theEnv != nil:
    theEnv.deleteGlobalRef(a.arr)

proc newArray*(T: typedesc, len: int): JVMArray[T] =
  checkInit
  new(result, freeJVMArray[T])
  let j = callVM theEnv.newArray(T, len.jsize)
  result.arr = theEnv.newGlobalRef(j)
  theEnv.deleteLocalRef(j)

proc len*(arr: JVMArray): jsize =
  callVM theEnv.GetArrayLength(theEnv, arr.get)

template genArrayType(typ, arrTyp: typedesc, typName: untyped): untyped =

  # Creation

  type `JVM typName Array`* {.inject.} = JVMArray[typ]

  when `typ` isnot jobject:
    proc `newJVM typName Array`*(len: jsize): JVMArray[typ] {.inline.} =
      newArray(`typ`, len.int)

  else:

    proc `newJVM typName Array`*(len: jsize, cls = JVMClass.getByName("java.lang.Object")): JVMArray[typ] =
      checkInit
      new(result, freeJVMArray[jobject])
      let j = callVM theEnv.NewObjectArray(theEnv, len, cls.get, nil)
      result.arr = theEnv.newGlobalRef(j)
      theEnv.deleteLocalRef(j)

    proc newArray*(c: JVMClass, len: int): JVMArray[typ] =
      `newJVM typName Array`(len.jsize, c)

    proc newArray*(t: typedesc[JVMObject], len: int): JVMArray[typ] =
      `newJVM typName Array`(len.jsize, JVMClass.getByName("java.lang.Object"))

  proc `newJVM typName Array`*(arr: jobject): JVMArray[typ] =
    checkInit
    new(result, freeJVMArray[typ])
    result.arr = theEnv.newGlobalRef(arr).`arrTyp`

  proc `newJVM typName Array`*(arr: JVMObject): JVMArray[typ] =
    `newJVM typName Array`(arr.get)

  proc newArray*(t: typedesc[typ], arr: jobject): JVMArray[typ] = `newJVM typName Array`(arr)

  proc newArray*(t: typedesc[typ], arr: JVMObject): JVMArray[typ] =
    `newJVM typName Array`(arr.get)

  proc toJVMObject*(a: JVMArray[typ]): JVMObject =
    checkInit
    newJVMObject(a.arr.jobject)

  # getters/setters

  proc `get typName Array`*(c: JVMClass, name: cstring): JVMArray[typ] =
    checkInit
    let j = callVM theEnv.GetStaticObjectField(theEnv, c.get, c.getStaticFieldId(name, seq[`typ`].jniSig).get)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `get typName Array`*(o: JVMObject, name: cstring): JVMArray[typ] =
    checkInit
    let j = callVM theEnv.GetObjectField(theEnv, o.get, o.getFieldId(name, seq[`typ`].jniSig).get)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `set typName Array`*(c: JVMClass, name: cstring, arr: JVMArray[typ]) =
    checkInit
    theEnv.SetStaticObjectField(theEnv, c.get, c.getStaticFieldId(name, seq[`typ`].jniSig).get, arr.arr)
    checkException

  proc `set typName Array`*(o: JVMObject, name: cstring, arr: JVMArray[typ]) =
    checkInit
    theEnv.SetObjectField(theEnv, o.get, o.getFieldId(name, seq[`typ`].jniSig).get, arr.arr)
    checkException

  # Array methods

  when `typ` is jobject:
    proc `[]`*(arr: JVMArray[typ], idx: Natural): JVMObject =
      checkInit
      (callVM theEnv.GetObjectArrayElement(theEnv, arr.get, idx.jsize)).newJVMObjectConsumingLocalRef
    proc `[]=`*(arr: JVMArray[typ], idx: Natural, obj: JVMObject) =
      checkInit
      theEnv.SetObjectArrayElement(theEnv, arr.get, idx.jsize, obj.get)
      checkException
  else:
    proc getArrayRegion*(a: arrTyp, start, length: jint, address: ptr typ) =
      checkInit
      theEnv.getArrayRegion(a, start, length, address)

    proc `[]`*(arr: JVMArray[typ], idx: Natural): `typ` =
      checkInit
      theEnv.getArrayRegion(arr.get, idx.jsize, 1.jsize, addr result)
      checkException
    proc `[]=`*(arr: JVMArray[typ], idx: Natural, v: `typ`) =
      checkInit
      theEnv.`Set typName ArrayRegion`(theEnv, arr.get, idx.jsize, 1.jsize, unsafeAddr v)
      checkException

  # Array methods
  proc `call typName ArrayMethod`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): JVMArray[typ] =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    let j = callVM theEnv.CallStaticObjectMethodA(theEnv, c.get, id.get, a)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `call typName ArrayMethod`*(c: JVMClass, name, sig: cstring, args: openarray[jvalue] = []): JVMArray[typ] =
    `call typName ArrayMethod`(c, c.getStaticMethodId(name, sig), args)

  proc `call typName ArrayMethod`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): JVMArray[typ] =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    let j = callVM theEnv.CallObjectMethodA(theEnv, o.get, id.get, a)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `call typName ArrayMethod`*(o: JVMObject, name, sig: cstring, args: openarray[jvalue] = []): JVMArray[typ] {.inline.} =
    `call typName ArrayMethod`(o, o.getMethodId(name, sig), args)

genArrayType(jchar, jcharArray, Char)
genArrayType(jbyte, jbyteArray, Byte)
genArrayType(jshort, jshortArray, Short)
genArrayType(jint, jintArray, Int)
genArrayType(jlong, jlongArray, Long)
genArrayType(jfloat, jfloatArray, Float)
genArrayType(jdouble, jdoubleArray, Double)
genArrayType(jboolean, jbooleanArray, Boolean)
genArrayType(jobject, jobjectArray, Object)

####################################################################################################
# Fields accessors generation

template genField(typ: typedesc, typName: untyped): untyped =
  proc `get typName`*(c: JVMClass, id: JVMFieldID): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.getStaticField(jobject, c.get, id.get)).newJVMObjectConsumingLocalRef
    else:
      (callVM theEnv.getStaticField(`typ`, c.get, id.get))

  proc `get typName`*(c: JVMClass, name: string): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.getStaticField(jobject, c.get, c.getStaticFieldId(`name`, `typ`).get)).newJVMObjectConsumingLocalRef
    else:
      (callVM theEnv.getStaticField(`typ`, c.get, c.getStaticFieldId(`name`, `typ`).get))

  proc `set typName`*(c: JVMClass, id: JVMFieldID, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.setStaticField(c.get, id.get, v.get)
    else:
      theEnv.setStaticField(c.get, id.get, v)
    checkException

  proc `set typName`*(c: JVMClass, name: string, v: `typ`) =
    `set typName`(c, c.getStaticFieldId(`name`, `typ`), v)

  proc `get typName`*(o: JVMObject, id: JVMFieldID): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.getField(jobject, o.get, id.get)).newJVMObjectConsumingLocalRef
    else:
      (callVM theEnv.getField(`typ`, o.get, id.get))

  proc `get typName`*(o: JVMObject, name: string): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.getField(jobject, o.get, o.getFieldId(`name`, `typ`).get)).newJVMObjectConsumingLocalRef
    else:
      (callVM theEnv.getField(`typ`, o.get, o.getFieldId(`name`, `typ`).get))

  proc `set typName`*(o: JVMObject, id: JVMFieldID, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.setField(o.get, id.get, v.get)
    else:
      theEnv.setField(o.get, id.get, v)
    checkException

  proc `set typName`*(o: JVMObject, name: string, v: `typ`) =
    `set typName`(o, o.getFieldId(`name`, `typ`), v)

  when `typ` isnot JVMObject:
    # Need to find out, why I can't just call `get typName`. Guess it's Nim's bug
    proc getProp*(T: typedesc[`typ`], c: JVMClass, id: JVMFieldID): `typ` =
      checkInit
      (callVM theEnv.getStaticField(`typ`, c.get, id.get))

    proc getProp*(T: typedesc[`typ`], o: JVMObject, id: JVMFieldID): `typ` =
      checkInit
      (callVM theEnv.getField(`typ`, o.get, id.get))

    proc setProp*(T: typedesc[`typ`], o: JVMClass|JVMObject, id: JVMFieldID, v: `typ`) =
      `set typName`(o, id, v)


genField(JVMObject, Object)
genField(jchar, Char)
genField(jbyte, Byte)
genField(jshort, Short)
genField(jint, Int)
genField(jlong, Long)
genField(jfloat, Float)
genField(jdouble, Double)
genField(jboolean, Boolean)

proc getPropRaw*(T: typedesc[JVMObject], c: JVMClass, id: JVMFieldID): jobject =
  # deprecated
  checkInit
  (callVM theEnv.getStaticField(jobject, c.get, id.get))

proc getPropRaw*(T: typedesc[JVMObject], o: JVMObject, id: JVMFieldID): jobject =
  # deprecated
  checkInit
  (callVM theEnv.getField(jobject, o.get, id.get))

proc setPropRaw*(T: typedesc[JVMObject], c: JVMClass, id: JVMFieldID, v: jobject) =
  # deprecated
  checkInit
  theEnv.setStaticField(c.get, id.get, v)
  checkException

proc setPropRaw*(T: typedesc[JVMObject], o: JVMObject, id: JVMFieldID, v: jobject) =
  # deprecated
  checkInit
  theEnv.setField(o.get, id.get, v)
  checkException

####################################################################################################
# Methods generation

template genMethod(typ: typedesc, typName: untyped): untyped =
  proc `call typName Method`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.callStaticMethod(jobject, c.get, id.get, args)).newJVMObjectConsumingLocalRef
    else:
      callVM theEnv.callStaticMethod(`typ`, c.get, id.get, args)

  proc `call typName Method`*(c: JVMClass, name, sig: string, args: openarray[jvalue] = []): `typ` {.inline.} =
    `call typName Method`(c, c.getStaticMethodId(name, sig), args)

  proc `call typName Method`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.callMethod(jobject, o.get, id.get, args)).newJVMObjectConsumingLocalRef
    else:
      callVM theEnv.callMethod(`typ`, o.get, id.get, args)

  proc `call typName Method`*(o: JVMObject, name, sig: cstring, args: openarray[jvalue] = []): `typ` {.inline.} =
    `call typName Method`(o, o.getMethodId(name, sig), args)

  proc `call typName Method`*(o: JnimNonVirtual_JVMObject, c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.callNonVirtualMethod(jobject, o.obj, c.get, id.get, args)).newJVMObjectConsumingLocalRef
    else:
      callVM theEnv.callNonVirtualMethod(`typ`, o.obj, c.get, id.get, args)

genMethod(JVMObject, Object)
genMethod(jchar, Char)
genMethod(jbyte, Byte)
genMethod(jshort, Short)
genMethod(jint, Int)
genMethod(jlong, Long)
genMethod(jfloat, Float)
genMethod(jdouble, Double)
genMethod(jboolean, Boolean)

proc callObjectMethodRaw*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): jobject = # Deprecated
  callVM theEnv.callStaticMethod(jobject, c.get, id.get, args)

proc callObjectMethodRaw*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): jobject = # Deprecated
  callVM theEnv.callMethod(jobject, o.get, id.get, args)

proc callObjectMethodRaw*(o: JnimNonVirtual_JVMObject, c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): jobject = # Deprecated
  callVM theEnv.callNonvirtualMethod(jobject, o.obj, c.get, id.get, args)

####################################################################################################
# Helpers

proc getJVMException*(ex: JavaException): JVMObject =
  ex.ex

proc toJVMObject*(s: string): JVMObject {.inline.} =
  newJVMObject(s)

type JPrimitiveType = jint | jfloat | jboolean | jdouble | jshort | jlong | jchar | jbyte

proc toJVMObject*[T](a: openarray[T]): JVMObject =
  when T is JVMObject:
    var arr = JVMObject.newArray(a.len)
    for i, v in a:
      arr[i] = v
    result = arr.toJVMObject
  elif compiles(toJVMObject(a[0])):
    var arr = JVMObject.newArray(a.len)
    for i, v in a:
      arr[i] = v.toJVMObject
    result = arr.toJVMObject
  elif T is JPrimitiveType:
    var arr = T.newArray(a.len)
    for i, v in a:
      arr[i] = v
    result = arr.toJVMObject
  else:
    {.error: "define toJVMObject method for the openarray element type".}

template jarrayToSeqImpl[T](arr: jarray, res: var seq[T]) =
  checkInit
  if arr == nil:
    return
  let length = theEnv.GetArrayLength(theEnv, arr)
  res = newSeq[T](length.int)
  when T is JPrimitiveType:
    type TT = T
    getArrayRegion(jtypedArray[TT](arr), 0, length, addr(res[0]))
  elif T is JVMObject:
    type TT = T
    for i in 0..<res.len:
      res[i] = fromJObjectConsumingLocalRef(TT, theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize))
  elif T is string:
    for i in 0..<res.len:
      res[i] = toStringRawConsumingLocalRef(theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize))
  else:
    {.fatal: "Sequences is not supported for the supplied type".}

proc jarrayToSeqConsumingLocalRef[T](arr: jarray, t: typedesc[seq[T]]): seq[T] {.inline.} =
  jarrayToSeqImpl(arr, result)
  theEnv.deleteLocalRef(arr)

template getPropValue*(T: typedesc, o: untyped, id: JVMFieldID): untyped =
  when T is bool:
    (jboolean.getProp(o, id) != JVM_FALSE)
  elif T is JPrimitiveType:
    T.getProp(o, id)
  elif T is string:
    toStringRawConsumingLocalRef(JVMObject.getPropRaw(o, id))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, JVMObject.getPropRaw(o, id))
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(JVMObject.getPropRaw(o, id).jarray, T))
  else:
    {.error: "Unknown property type".}

template setPropValue*(T: typedesc, o: untyped, id: JVMFieldID, v: T) =
  when T is bool:
    jboolean.setProp(o, id, if v: JVM_TRUE else: JVM_FALSE)
  elif T is JPrimitiveType:
    T.setProp(o, id, v)
  elif compiles(toJVMObject(v)):
    JVMObject.setPropRaw(o, id, toJVMObject(v).get)
  else:
    {.error: "Unknown property type".}

template callMethod*(T: typedesc, o: untyped, methodId: JVMMethodID, args: openarray[jvalue]): untyped =
  when T is void:
    o.callVoidMethod(methodId, args)
  elif T is jchar:
    o.callCharMethod(methodId, args)
  elif T is jbyte:
    o.callByteMethod(methodId, args)
  elif T is jshort:
    o.callShortMethod(methodId, args)
  elif T is jint:
    o.callIntMethod(methodId, args)
  elif T is jlong:
    o.callLongMethod(methodId, args)
  elif T is jfloat:
    o.callFloatMethod(methodId, args)
  elif T is jdouble:
    o.callDoubleMethod(methodId, args)
  elif T is jboolean:
    o.callBooleanMethod(methodId, args)
  elif T is bool:
    (o.callBooleanMethod(methodId, args) != JVM_FALSE)
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(o.callObjectMethodRaw(methodId, args).jarray, T))
  elif T is string:
    toStringRawConsumingLocalRef(o.callObjectMethodRaw(methodId, args))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, o.callObjectMethodRaw(methodId, args))
  else:
    {.error: "Unknown return type".}

template callNonVirtualMethod*(T: typedesc, o: untyped, c: JVMClass, methodId: JVMMethodID, args: openarray[jvalue]): untyped =
  when T is void:
    o.callVoidMethod(c, methodId, args)
  elif T is jchar:
    o.callCharMethod(c, methodId, args)
  elif T is jbyte:
    o.callByteMethod(c, methodId, args)
  elif T is jshort:
    o.callShortMethod(c, methodId, args)
  elif T is jint:
    o.callIntMethod(c, methodId, args)
  elif T is jlong:
    o.callLongMethod(c, methodId, args)
  elif T is jfloat:
    o.callFloatMethod(c, methodId, args)
  elif T is jdouble:
    o.callDoubleMethod(c, methodId, args)
  elif T is jboolean:
    o.callBooleanMethod(c, methodId, args)
  elif T is bool:
    (o.callBooleanMethod(c, methodId, args) != JVM_FALSE)
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(o.callObjectMethodRaw(c, methodId, args).jarray, T))
  elif T is string:
    toStringRawConsumingLocalRef(o.callObjectMethodRaw(c, methodId, args))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, o.callObjectMethodRaw(c, methodId, args))
  else:
    {.error: "Unknown return type".}

proc instanceOfRaw*(obj: JVMObject, cls: JVMClass): bool =
  checkInit
  callVM theEnv.IsInstanceOf(theEnv, obj.obj, cls.cls) != JVM_FALSE

proc `$`*(s: jstring): string =
  checkInit
  if s != nil:
    result = jstringToStringAux(s)
