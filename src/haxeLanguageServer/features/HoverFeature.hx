package haxeLanguageServer.features;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import haxeLanguageServer.vscodeProtocol.Types;
import haxeLanguageServer.HaxeDisplayTypes;

class HoverFeature extends Feature {
    override function init() {
        context.protocol.onHover = onHover;
    }

    function onHover(params:TextDocumentPositionParams, token:CancellationToken, resolve:Hover->Void, reject:ResponseError<Void>->Void) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@type'];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:{range:Range, type:TypeInfo} = try haxe.Json.parse(data) catch (_:Dynamic) return reject(ResponseError.internalError("Invalid JSON data: " + data));

            var result:Hover = {contents: TypePrinter.printType(data.type)};
            if (data.range != null)
                result.range = doc.byteRangeToRange(data.range);

            resolve(result);
        }, function(error) reject(ResponseError.internalError(error)));
    }
}
