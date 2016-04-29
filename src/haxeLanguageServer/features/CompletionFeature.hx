package haxeLanguageServer.features;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import haxeLanguageServer.vscodeProtocol.Types;
import haxeLanguageServer.HaxeDisplayTypes;

class CompletionFeature extends Feature {
    override function init() {
        context.protocol.onCompletion = onCompletion;
    }

    function onCompletion(params:TextDocumentPositionParams, token:CancellationToken, resolve:Array<CompletionItem>->Void, reject:ResponseError<Void>->Void) {
        var doc = context.documents.get(params.textDocument.uri);
        var r = calculateCompletionPosition(doc.content, doc.offsetAt(params.position));
        var bytePos = doc.offsetToByteOffset(r.pos);
        var args = ["--display", '${doc.fsPath}@$bytePos' + (if (r.toplevel) "@toplevel" else "")];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;
            var data:Dynamic = try haxe.Json.parse(data) catch (_:Dynamic) return reject(ResponseError.internalError("Invalid JSON data: " + data));
            resolve(if (r.toplevel) parseToplevelCompletion(data) else parseFieldCompletion(data));
        }, function(error) reject(ResponseError.internalError(error)));
    }

    static var reFieldPart = ~/\.(\w*)$/;
    static function calculateCompletionPosition(text:String, index:Int):CompletionPosition {
        text = text.substring(0, index);
        if (reFieldPart.match(text))
            return {
                pos: index - reFieldPart.matched(1).length,
                toplevel: false,
            };
        else
            return {
                pos: index,
                toplevel: true,
            };
    }

    static function parseToplevelCompletion(completion:Array<ToplevelCompletionItem>):Array<CompletionItem> {
        var result = [];
        for (el in completion) {
            var kind:CompletionItemKind, name, fullName = null, type = null;
            switch (el.kind) {
                case TCLocal:
                    kind = Variable;
                    name = el.name;
                    type = el.type;
                case TCMember | TCStatic:
                    kind = Field;
                    name = el.name;
                    type = el.type;
                case TCEnum:
                    kind = Enum;
                    name = el.name;
                    type = el.type;
                case TCGlobal:
                    kind = Variable;
                    name = el.name;
                    type = el.type;
                    fullName = TypePrinter.printTypePath(el.parent) + "." + el.name;
                case TCType:
                    kind = Class;
                    name = el.path.name;
                    fullName = TypePrinter.printTypePath(el.path);
                case TCPackage:
                    kind = Module;
                    name = el.name;
            }

            if (fullName == name)
                fullName = null;

            var item:CompletionItem = {
                label: name,
                kind: kind,
            }

            if (type != null || fullName != null) {
                var parts = [];
                if (fullName != null)
                    parts.push('($fullName)');
                if (type != null)
                    parts.push(TypePrinter.printTypeInner(type));
                item.detail = parts.join(" ");
            }

            if (el.doc != null)
                item.documentation = el.doc;

            result.push(item);
        }
        return result;
    }

    static function parseFieldCompletion(completion:Array<FieldCompletionItem>):Array<CompletionItem> {
        var result = [];
        for (el in completion) {
            var item:CompletionItem = {
                label: el.name,
                kind: switch (el.kind) {
                    case FCVar: Field;
                    case FCMethod: Method;
                    case FCType: Class;
                    case FCPackage: Module;
                }
            };
            if (el.doc != null) item.documentation = el.doc;
            if (el.type != null) item.detail = TypePrinter.printTypeInner(el.type);
            result.push(item);
        }
        return result;
    }
}

private typedef CompletionPosition = {
    var pos:Int;
    var toplevel:Bool;
}
