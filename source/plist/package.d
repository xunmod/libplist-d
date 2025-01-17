module plist;

import core.stdc.stdlib;

import std.datetime;
import std.meta;
import std.range;
import std.string;
import std.traits;

import plist.c;

public alias PlistType = plist_type;

public abstract class Plist {
    plist_t handle;
    bool owns;

    this(plist_t handle, bool owns) {
        this.handle = handle;
        this.owns = owns;
    }

    public PlistType nodeType() {
        return plist_get_node_type(handle);
    }

    public static Plist wrap(plist_t handle, bool owns = true) {
        if (!handle) {
            return null;
        }

        Plist obj;
        with (PlistType) final switch (plist_get_node_type(handle)) {
            case PLIST_BOOLEAN:
                obj = new PlistBoolean(handle, owns);
                break;
            case PLIST_UINT:
                obj = new PlistUint(handle, owns);
                break;
            case PLIST_REAL:
                obj = new PlistReal(handle, owns);
                break;
            case PLIST_STRING:
                obj = new PlistString(handle, owns);
                break;
            case PLIST_ARRAY:
                obj = new PlistArray(handle, owns);
                break;
            case PLIST_DICT:
                obj = new PlistDict(handle, owns);
                break;
            case PLIST_DATE:
                obj = new PlistDate(handle, owns);
                break;
            case PLIST_DATA:
                obj = new PlistData(handle, owns);
                break;
            case PLIST_KEY:
                obj = new PlistKey(handle, owns);
                break;
            case PLIST_UID:
                obj = new PlistUid(handle, owns);
                break;
            case PLIST_NONE:
                obj = new PlistNone(handle, owns);
                break;
        }

        return obj;
    }

    public static Plist fromMemory(ubyte[] bin) {
        plist_t handle;
        plist_from_memory(cast(const char*) bin.ptr, cast(uint) bin.length, &handle, null);
        return wrap(handle);
    }

    public static Plist fromXml(string xml) {
        plist_t handle;
        plist_from_xml(cast(const char*) xml.ptr, cast(uint) xml.length, &handle);
        return wrap(handle);
    }

    public static Plist fromBin(ubyte[] bin) {
        plist_t handle;
        plist_from_bin(cast(const char*) bin.ptr, cast(uint) bin.length, &handle);
        return wrap(handle);
    }

    ~this() {
        if (owns && nodeType() != PlistType.PLIST_NONE) {
            plist_free(handle);
        }
    }

    public R copy(this R)() if (!is(T == Plist)) {
        return new R(plist_copy(handle), true);
    }

    public Plist copy() {
        return Plist.wrap(plist_copy(handle), true);
    }

    public string toXml() {
        char* str;
        uint length;
        plist_to_xml(handle, &str, &length);
        auto xml = cast(string) str[0..length].dup;
        plist_to_xml_free(str);
        return xml;
    }

    public string toBin() {
        char* bin;
        uint length;
        plist_to_bin(handle, &bin, &length);
        auto binary = cast(string) bin[0..length].dup;
        plist_to_bin_free(bin);
        return binary;
    }

    mixin template MakeEasyCast(PlistRet, string name) {
        PlistRet _() {
            if (handle) {
                PlistRet res = cast(PlistRet) this;
                if (res) {
                    return res;
                }
            }
            throw new InvalidCastException(this);
        }
        mixin("alias " ~ name ~ " = _;");
    }

    mixin MakeEasyCast!(PlistBoolean, "boolean");
    mixin MakeEasyCast!(PlistUint, "uinteger");
    mixin MakeEasyCast!(PlistReal, "real_");
    mixin MakeEasyCast!(PlistString, "str");
    mixin MakeEasyCast!(PlistArray, "array");
    mixin MakeEasyCast!(PlistDict, "dict");
    mixin MakeEasyCast!(PlistDate, "date");
    mixin MakeEasyCast!(PlistData, "data");
    mixin MakeEasyCast!(PlistKey, "key");
    mixin MakeEasyCast!(PlistUid, "uid");

    static foreach (T; AliasSeq!(bool, ulong, double, string, Plist[], Plist[string], DateTime, ubyte[])) {
        bool opEquals(T elem) {
            return false;
        }
    }

    public Plist opIndex(string key) {
        throw new InvalidCastException(this);
    }

    public override string toString() {
        return this.toXml(); // I would rather use an OpenSTEP style Plist but it would bump the libplist version requirement.
    }
}

// It makes D explodes, like it cannot load the child classes if I use it in Plist
// template NativeType(PlistT: Plist) {
//     alias NativeType = ReturnType!(PlistT.native);
// }

public class PlistBoolean: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(bool val) {
        this(plist_new_bool(val), true);
    }

    public T opCast(T: bool)() {
        ubyte val;
        plist_get_bool_val(handle, &val);
        return cast(T) val;
    }

    public void opAssign(bool val) {
        plist_set_bool_val(handle, val);
    }

    override bool opEquals(bool val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public bool native() {
        return cast(bool) this;
    }
}

class PlistUint: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(ulong val) {
        this(plist_new_uint(val), true);
    }

    public T opCast(T)() if (isUnsigned!T) {
        ulong val;
        plist_get_uint_val(handle, &val);
        return cast(T) val;
    }

    public void opAssign(T)(T val) if (isUnsigned!T) {
        plist_set_uint_val(handle, cast(ulong) val);
    }

    override bool opEquals(ulong val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public ulong native() {
        return cast(ulong) this;
    }
}

class PlistReal: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(double val) {
        this(plist_new_real(val), true);
    }

    public T opCast(T)() if (isFloatingPoint!T) {
        double val;
        plist_get_real_val(handle, &val);
        return cast(T) val;
    }

    public void opAssign(T)(T val) if (isFloatingPoint!T) {
        plist_set_real_val(handle, cast(double) val);
    }

    override bool opEquals(double val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public double native() {
        return cast(double) this;
    }
}

class PlistString: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(string val) {
        this(plist_new_string(val.toStringz), true);
    }

    public T opCast(T)() if (isSomeString!T) {
        char* val;
        plist_get_string_val(handle, &val);
        auto str = val.fromStringz.dup;
        plist_mem_free(val);
        return cast(T) str;
    }

    public void opAssign(T)(T val) if (isSomeString!T) {
        plist_set_string_val(handle, cast(const char*) val.toStringz);
    }

    override bool opEquals(string val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public string native() {
        return cast(string) this;
    }
}

class PlistArray: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this() {
        this(plist_new_array(), true);
    }

    public uint length() {
        return plist_array_get_size(handle);
    }

    public uint opDollar(size_t pos)() {
        return length();
    }

    public Plist opIndex(uint index) {
        return Plist.wrap(plist_array_get_item(handle, index), false);
    }

    public void opIndexAssign(Plist element, uint key) {
        element.owns = false;
        plist_array_set_item(handle, element.handle, key);
    }

    public void opOpAssign(string s: "~")(Plist element) {
        element.owns = false;
        plist_array_append_item(handle, element.handle);
    }

    class PlistArrayIter {
        private plist_array_iter handle;
        private PlistArray array;

        public this(plist_array_iter handle, PlistArray array) {
            this.handle = handle;
            this.array = array;
        }

        ~this() {
            free(handle);
        }

        bool next(out Plist plist) {
            plist_t plist_h;
            plist_array_next_item(array.handle, handle, &plist_h);
            if (!plist_h)
                return false;
            plist = Plist.wrap(plist_h, false);
            return true;
        }
    }

    int opApply(int delegate(Plist element) del) {
        scope iterator = iter();
        Plist val;

        int result = 0;
        while (iterator.next(val)) {
            if ((result = del(val)) != 0) {
                break;
            }
        }

        return result;
    }

    int opApply(int delegate(size_t counter, Plist element) del) {
        size_t counter = 0;
        return opApply((Plist elem) => del(counter++, elem));
    }

    public PlistArrayIter iter() {
        plist_array_iter iter;
        plist_array_new_iter(handle, &iter);
        return new PlistArrayIter(iter, this);
    }

    public void append(Plist[] array) {
        foreach (element; array) {
            this ~= element;
            element.owns = false;
        }
    }

    public T opCast(T = Plist[])() {
        Plist[] array = new Plist[](length());

        foreach (idx, elem; this) {
            array[idx] = elem;
        }
        return array;
    }

    override bool opEquals(Plist[] val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public Plist[] native() {
        return cast(Plist[]) this;
    }
}

class PlistDict: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this() {
        this(plist_new_dict(), true);
    }

    public uint length() {
        return plist_dict_get_size(handle);
    }

    public uint opDollar(size_t pos)() {
        return length();
    }

    public Plist opBinaryRight(string op = "in")(string key) {
        return Plist.wrap(plist_dict_get_item(handle, key.toStringz), false);
    }

    public override Plist opIndex(string key) {
        auto item = plist_dict_get_item(handle, key.toStringz);
        if (item) {
            return Plist.wrap(item, false);
        } else {
            throw new InvalidIndexException(key);
        }
    }

    public void opIndexAssign(Plist element, string key) {
        element.owns = false;
        plist_dict_set_item(handle, key.toStringz, element.handle);
    }

    class PlistDictIter {
        private plist_dict_iter handle;
        private PlistDict dict;

        public this(plist_dict_iter handle, PlistDict dict) {
            this.handle = handle;
            this.dict = dict;
        }

        ~this() {
            free(handle);
        }

        bool next(out Plist plist, out string key) {
            plist_t plist_h = null;
            char* k = null;
            plist_dict_next_item(dict.handle, handle, &k, &plist_h);
            if (!plist_h)
                return false;
            key = k.fromStringz.dup;
            free(k);
            plist = Plist.wrap(plist_h, false);
            return true;
        }
    }

    public PlistDictIter iter() {
        plist_dict_iter iter;
        plist_dict_new_iter(handle, &iter);
        return new PlistDictIter(iter, this);
    }

    public void append(Plist[string] array) {
        foreach (element; array.byKeyValue) {
            if (element.value.owns) {
                element.value.owns = false;
            } else {
                element.value = element.value.copy();
            }
            this[element.key] = element.value;
        }
    }

    public void merge(PlistDict dict) {
        plist_dict_merge(&handle, dict.handle);
    }

    int opApply(int delegate(string key, Plist value) del) {
        int result = 0;

        scope iterator = iter();

        Plist val;
        string key;

        while (iterator.next(val, key)) {
            if ((result = del(key, val)) != 0) {
                break;
            }
        }

        return result;
    }

    override bool opEquals(Plist[string] val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public Plist[string] native() {
        Plist[string] dictionary;

        foreach (key, val; this) {
            dictionary[key] = val;
        }
        return dictionary;
    }

    public static PlistKey getKey(Plist item) {
        return new PlistKey(plist_dict_item_get_key(item.handle), false);
    }
}

class PlistDate: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    // public this() {
    //     this(plist_new_date(), true);
    // }

    public T opCast(T: DateTime)() {
        int sec;
        int usec;
        plist_get_date_val(handle, &sec, &usec);

        return DateTime(2001, 1, 1) + dur!"seconds"(sec) + dur!"usecs"(usec);
    }

    override bool opEquals(DateTime val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public DateTime native() {
        return cast(DateTime) this;
    }
}

class PlistData: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(ubyte[] val) {
        this(plist_new_data(cast(const char*) val.ptr, val.length), true);
    }

    public ubyte[] opCast(T: ubyte[])() {
        char* ptr;
        ulong length;
        plist_get_data_val(handle, &ptr, &length);
        auto data = cast(ubyte[]) ptr[0..cast(size_t) length].dup;
        plist_mem_free(ptr);
        return data;
    }

    public void opAssign(ubyte[] val) {
        plist_set_data_val(handle, cast(const char*) val.ptr, val.length);
    }

    override bool opEquals(ubyte[] val) {
        return native() == val;
    }
    alias opEquals = Plist.opEquals;

    public auto native() {
        return cast(ubyte[]) this;
    }
}

class PlistKey: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public void opAssign(string key) {
        plist_set_key_val(handle, key.toStringz);
    }
}

class PlistUid: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }

    public this(ulong val) {
        this(plist_new_uid(val), true);
    }

    public void opAssign(ulong val) {
        plist_set_uid_val(handle, val);
    }
}

class PlistNone: Plist {
    public this(plist_t handle, bool owns) {
        super(handle, owns);
    }
}

pragma(inline, true) auto pl(bool obj) {
    return new PlistBoolean(obj);
}

pragma(inline, true) auto pl(U)(U obj) if (isIntegral!U) {
    return new PlistUint(obj);
}

pragma(inline, true) auto pl(U)(U obj) if (isFloatingPoint!U) {
    return new PlistReal(obj);
}

pragma(inline, true) auto pl(U)(U obj) if (isSomeString!U) {
    return new PlistString(cast(string) obj);
}

pragma(inline, true) auto pl(T: Plist)(T[] obj) {
    auto array = new PlistArray();
    array.append(cast(Plist[]) obj);
    return array;
}

pragma(inline, true) auto pl(Plist[string] obj) {
    auto dict = new PlistDict();
    dict.append(obj);
    return dict;
}

pragma(inline, true) auto pl(ubyte[] obj) {
    return new PlistData(obj);
}

pragma(inline, true) PlistDict dict(Args...)(Args args) {
    auto dict = new PlistDict();
    static foreach(index; 0..args.length / 2) {
        static if (is(Args[2 * index + 1]: Plist)) {
            dict[args[2 * index]] = args[2 * index + 1];
        } else {
            dict[args[2 * index]] = args[2 * index + 1].pl;
        }
    }
    return dict;
}

class InvalidIndexException: Exception {
    this(string key, string file = __FILE__, size_t line = __LINE__) {
        super(format!"No entry with index `%s` has been found."(key), file, line);
    }
}

class InvalidCastException: Exception {
    this(Plist plist, string file = __FILE__, size_t line = __LINE__) {
        super(format!"Object is a `%s`, and cannot be converted into the specified type."(typeid(plist)), file, line);
    }
}
