package haxeLanguageServer.features;

import haxe.extern.EitherType;
import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import haxeLanguageServer.vscodeProtocol.Types;
import haxeLanguageServer.HaxeDisplayTypes;

class GotoDefinitionFeature extends Feature {
    override function init() {
        context.protocol.onGotoDefinition = onGotoDefinition;
    }

    function onGotoDefinition(params:TextDocumentPositionParams, token:CancellationToken, resolve:EitherType<Location,Array<Location>>->Void, reject:ResponseError<Void>->Void) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@position'];
        var stdin = if (doc.saved) null else doc.content;
        callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var data:Array<Pos> = try haxe.Json.parse(data) catch (_:Dynamic) return reject(ResponseError.internalError("Invalid JSON data: " + data));

            var results = [];
            for (pos in data) {
                var location = HaxePosition.parse(pos, doc, null); // no cache because this right now only returns one position
                if (location == null) {
                    trace("Got invalid position: " + pos);
                    continue;
                }
                results.push(location);
            }

            return resolve(results);
        }, function(error) reject(ResponseError.internalError(error)));
    }
}
