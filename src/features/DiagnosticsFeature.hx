package features;

import vscode.ProtocolTypes;
import vscode.BasicTypes;
import jsonrpc.Protocol;
import jsonrpc.Types;

@:enum abstract DiagnosticsKind<T>(Int) from Int to Int {
    var DKUnusedImport:DiagnosticsKind<Void> = 0;
    var DKUnresolvedIdentifier:DiagnosticsKind<Array<String>> = 1;

    public inline function new(i:Int) {
        this = i;
    }

    public function getMessage() {
        return switch ((this : DiagnosticsKind<T>)) {
            case DKUnusedImport: "Unused import";
            case DKUnresolvedIdentifier: "Unresolved identifier";
        }
    }
}

typedef HaxeDiagnostics<T> = {
    var kind:DiagnosticsKind<T>;
    var range:Range;
    var args:T;
}

typedef DiagnosticsMapKey = {code: Int, range:Range};

class DiagnosticsMap<T> extends haxe.ds.BalancedTree<DiagnosticsMapKey, T> {
    override function compare(k1:DiagnosticsMapKey, k2:DiagnosticsMapKey) {
        var start1 = k1.range.start;
        var start2 = k2.range.start;
        var end1 = k1.range.end;
        var end2 = k2.range.end;
        inline function compare(i1, i2, e) return i1 < i2 ? -1 : i1 > i2 ? 1 : e;
        return compare(k1.code, k2.code, compare(start1.line, start2.line, compare(start1.character, start2.character,
            compare(end1.line, end2.line, compare(end1.character, end2.character, 0)
        ))));
    }
}

class DiagnosticsFeature extends Feature {

    var diagnosticsArguments:DiagnosticsMap<Dynamic>;

    public function new(context:Context) {
        super(context);
        context.protocol.onCodeAction = onCodeAction;
        diagnosticsArguments = new DiagnosticsMap();
    }

    public function getDiagnostics(uri:String) {
        var doc = context.documents.get(uri);
        function processReply(s:String) {
            diagnosticsArguments = new DiagnosticsMap();
            var data:Array<HaxeDiagnostics<Dynamic>> =
                try haxe.Json.parse(s)
                catch (e:Dynamic) {
                    trace("Error parsing diagnostics response: " + e);
                    return;
                }

            var diagnostics:Array<Diagnostic> = data.map(function (hxDiag) {
                var diag = {
                    range: doc.byteRangeToRange(hxDiag.range),
                    source: "haxe",
                    code: (hxDiag.kind : Int),
                    severity: Warning,
                    message: hxDiag.kind.getMessage()
                }
                diagnosticsArguments.set({code: diag.code, range: diag.range}, hxDiag.args);
                return diag;
            });

            context.protocol.sendPublishDiagnostics({uri: uri, diagnostics: diagnostics});
        }
        function processError(error:String) {
            context.protocol.sendLogMessage({type: Error, message: error});
        }
        callDisplay(["--display", doc.fsPath + "@0@diagnostics"], null, new CancellationToken(), processReply, processError);
    }

    function getDiagnosticsArguments<T>(kind:DiagnosticsKind<T>, range:Range):T {
        return diagnosticsArguments.get({code: kind, range: range});
    }

    function onCodeAction<T>(params:CodeActionParams, token:CancellationToken, resolve:Array<Command> -> Void, reject:ResponseError<Dynamic> -> Void) {

        var ret:Array<Command> = [];
        for (d in params.context.diagnostics) {
            var code = new DiagnosticsKind<T>(Std.parseInt(d.code));
            switch (code) {
                case DKUnusedImport:
                    ret.push({
                        title: "Remove import",
                        command: "haxe.applyFixes",
                        arguments: [params.textDocument.uri, 0 /*TODO*/, [{range: d.range, newText: ""}]]
                    });
                case DKUnresolvedIdentifier:
                    var args = getDiagnosticsArguments(code, d.range);
                    for (arg in args) {
                        ret.push({
                            title: "import " + arg,
                            command: "haxe.applyFixes", // TODO
                            arguments: []
                        });
                    }
            }
        }
        resolve(ret);
    }
}