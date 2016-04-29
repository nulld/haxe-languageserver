package haxeLanguageServer;

typedef Pos = {
    >haxeLanguageServer.vscodeProtocol.Types.Range,
    file:String
}

@:enum abstract TypeKind(Int) {
    var TKClass = 1;
    var TKInterface = 2;
    var TKEnum = 3;
    var TKTypedef = 4;
    var TKAbstract = 5;
    var TKFunction = 6;
    var TKAnon = 7;
    var TKDynamic = 8;
    var TKExpr = 9;
    var TKMono = 10;
    var TKClassStatics = 11;
    var TKAbstractStatics = 12;
    var TKEnumStatics = 13;
}

typedef TypeInfo = {
    kind:TypeKind,

    // referencing by path
    ?path:TypePath,

    // applied params
    ?params:Array<TypeInfo>,

    // for expression type params
    ?expr:String,

    // for monomorphs
    ?index:Int,

    // for anons
    ?fields:Array<FieldOrArg>,
    ?open:Bool,

    // for functions
    ?args:Array<FieldOrArg>,
    ?ret:TypeInfo,
}

typedef TypePath = {
    ?pack:Array<String>,
    name:String
}

typedef FieldOrArg = {
    name:String,
    type:TypeInfo,
    ?opt:Bool,
}

@:enum abstract ToplevelCompletionKind(Int) {
    var TCLocal = 1;
    var TCMember = 2;
    var TCStatic = 3;
    var TCEnum = 4;
    var TCGlobal = 5;
    var TCType = 6;
    var TCPackage = 7;
}

typedef ToplevelCompletionItem = {
    var kind:ToplevelCompletionKind;
    @:optional var name:String;
    @:optional var doc:String;
    @:optional var type:TypeInfo;
    @:optional var parent:TypePath;
    @:optional var path:TypePath;
}

@:enum abstract FieldCompletionKind(Int) {
    var FCVar = 1;
    var FCMethod = 2;
    var FCType = 3;
    var FCPackage = 4;
}

typedef FieldCompletionItem = {
    var kind:FieldCompletionKind;
    var name:String;
    @:optional var type:TypeInfo;
    @:optional var path:String;
    @:optional var doc:String;
}

class TypePrinter {

    // TODO: print Null<T> differently?
    public static function printType(type:TypeInfo):String {
        return switch (type.kind) {
            case TKClass | TKClassStatics:
                "(class) " + printTypePath(type.path) + printTypeParams(type.params);
            case TKInterface:
                "(interface) " + printTypePath(type.path) + printTypeParams(type.params);
            case TKEnum | TKEnumStatics:
                "(enum) " + printTypePath(type.path) + printTypeParams(type.params);
            case TKTypedef:
                "(typedef) " + printTypePath(type.path) + printTypeParams(type.params);
            case TKAbstract | TKAbstractStatics:
                "(abstract) " + printTypePath(type.path) + printTypeParams(type.params);
            case TKFunction:
                 printFunctionSignature(type.args, type.ret);
            case TKAnon:
                "(anonymous) " + printAnonymous(type.fields);
            case TKDynamic:
                "Dynamic" + printTypeParams(type.params);
            case TKExpr:
                type.expr;
            case TKMono:
                "(unknown) #" + type.index;
        }
    }

    public static function printTypePath(path:TypePath):String {
        var r = path.name;
        if (path.pack != null)
            r = path.pack.join(".") + "." + r;
        return r;
    }

    static function printTypeParams(params:Array<TypeInfo>):String {
        if (params == null)
            return "";
        var result = [];
        for (param in params)
            result.push(printTypeInner(param));
        return '<${result.join(",")}>';
    }

    public static function printTypeInner(type:TypeInfo, inArrowFunction = false):String {
        return switch (type.kind) {
            case TKClass | TKClassStatics | TKInterface | TKEnum | TKEnumStatics | TKTypedef | TKAbstract | TKAbstractStatics:
                printTypePath(type.path) + printTypeParams(type.params);
            case TKFunction:
                var r = printFunctionArrow(type.args, type.ret);
                if (inArrowFunction) '($r)' else r;
            case TKAnon:
                printAnonymous(type.fields);
            case TKDynamic:
                "Dynamic" + printTypeParams(type.params);
            case TKExpr:
                type.expr;
            case TKMono:
                'Unknown<${type.index}>';
        }
    }

    static function printAnonymous(fields:Array<FieldOrArg>):String {
        var result = [];
        for (field in fields) {
            var s = field.name + ":" + printTypeInner(field.type);
            if (field.opt)
                s = "?" + s;
            result.push(s);
        }
        return '{${result.join(", ")}}';
    }

    public static function printFunctionSignature(args:Array<FieldOrArg>, ret:TypeInfo):String {
        var result = new StringBuf();
        result.add("function(");
        var first = true;
        for (i in 0...args.length) {
            if (first)
                first = false;
            else
                result.add(", ");
            result.add(printFunctionArgument(args[i], i));
        }
        result.add(")");
        if (ret.kind != TKMono) {
            result.add(":");
            result.add(printTypeInner(ret));
        }
        return result.toString();
    }

    public static function printFunctionArgument(arg:FieldOrArg, i = 0):String {
        var result = new StringBuf();
        var type = arg.type;
        if (arg.opt) {
            result.add("?");
            type = stripNull(type);
        }

        if (arg.name.length > 0)
            result.add(arg.name);
        else
            result.add(std.String.fromCharCode('a'.code + i));

        if (type.kind != TKMono) {
            result.add(":");
            result.add(printTypeInner(type));
        }
        return result.toString();
    }

    static function printFunctionArrow(args:Array<FieldOrArg>, ret:TypeInfo):String {
        var result = [];
        if (args.length == 0)
            result.push("Void");
        else
            for (arg in args) {
                var s, type = arg.type;
                if (arg.opt) {
                    s = "?";
                    type = stripNull(type);
                } else {
                    s = "";
                }
                if (arg.name.length > 0)
                    s += arg.name + ":";
                s += printTypeInner(type, true);
                result.push(s);
            }
        result.push(printTypeInner(ret));
        return result.join("->");
    }

    static function stripNull(type:TypeInfo):TypeInfo {
        if (type.kind == TKTypedef && type.path.name == "Null" && type.path.pack == null)
            return type.params[0];
        return type;
    }
}
