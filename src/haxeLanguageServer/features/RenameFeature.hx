package haxeLanguageServer.features;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import vscodeProtocol.Types;
import jsonrpc.Types.NoData;

class RenameFeature {
    var context:Context;

    public function new(ctx) {
        context = ctx;
        context.protocol.onRename = onRename;
    }

    function onRename(params:RenameParams, token:CancellationToken, resolve:WorkspaceEdit->Void, reject:ResponseError<NoData>->Void) {
        var doc = context.documents.get(params.textDocument.uri);
        var bytePos = doc.byteOffsetAt(params.position);
        var args = ["--display", '${doc.fsPath}@$bytePos@usage'];
        var stdin = if (doc.saved) null else doc.content;
        context.callDisplay(args, stdin, token, function(data) {
            if (token.canceled)
                return;

            var xml = try Xml.parse(data).firstElement() catch (_:Dynamic) null;
            if (xml == null) return reject(ResponseError.internalError("Invalid xml data: " + data));

            var positions = [for (el in xml.elements()) el.firstChild().nodeValue];
            if (positions.length == 0)
                return resolve({changes: {}});

            var changes = new haxe.DynamicAccess<Array<TextEdit>>();
            var haxePosCache = new Map();
            for (pos in positions) {
                var location = HaxePosition.parse(pos, doc, haxePosCache);
                if (location == null) {
                    trace("Got invalid position: " + pos);
                    continue;
                }
                var edits = changes[location.uri];
                if (edits == null)
                    edits = changes[location.uri] = [];
                edits.push({
                    range: location.range,
                    newText: params.newName
                });
            }

            resolve({changes: changes});
        }, function(error) reject(ResponseError.internalError(error)));
    }
}