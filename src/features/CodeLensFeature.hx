package features;

import vscode.BasicTypes;
import vscode.ProtocolTypes;
import jsonrpc.Protocol;
import jsonrpc.ErrorCodes;

import Uri.uriToFsPath;

interface I {
    public function test():Void;
    public function test2(i:Int):Void;
}

class C implements I { }

class CodeLensFeature extends Feature {
    override function init() {
        context.protocol.onCodeLens = onCodeLens;
    }

    function onCodeLens(params:DocumentSymbolParams, token:RequestToken, resolve:Array<CodeLens>->Void, reject:RejectHandler) {
        var doc = context.getDocument(params.textDocument.uri);
        var filePath = uriToFsPath(params.textDocument.uri);
        var args = [
            "--display", '$filePath@0@missing-interface-fields'
        ];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:Array<{location:HaxeLocation, fields:Array<String>}> =
                try haxe.Json.parse(data) catch (e:Dynamic) {
                    trace("INVALID document-symbols: " + e);
                    trace("First 4096 symbols:\n" + data.substr(0, 4096));
                    return reject(ErrorCodes.internalError("Error parsing document symbol response: " + e));
                }

            var result = new Array<CodeLens>();
            var haxePosCache = new Map();
            for (v in data) {
                if (v.location == null) {
                    context.protocol.sendShowMessage({type: Error, message: "Unknown location for " + haxe.Json.stringify(v)});
                    continue;
                }
                var pos = locationToHaxePosition(v.location);
                var item:CodeLens = {
                    command : {
                        title: "implement missing fields",
                        command: "haxe.implementMissingFields",
                        arguments: [v.fields]
                    },
                    range: pos.toRange(haxePosCache)
                };
                result.push(item);
            }


            resolve(result);
        });
    }

    // this is temporary, we're gonna remove HaxePosition after we'll be using JSON display API
    static function locationToHaxePosition(l:HaxeLocation):HaxePosition {
        return {
            file: l.file,
            line: l.start.line,
            startLine: l.start.line,
            endLine: l.end.line,
            startByte: l.start.character,
            endByte: l.end.character,
        };
    }
}

private typedef HaxeLocation = {
    >Range,
    var file:String;
}
