package haxeLanguageServer;

import haxeLanguageServer.vscodeProtocol.Types.Location;

class HaxePosition {
    static var properFileNameCaseCache:Map<String,String>;
    static var isWindows = (Sys.systemName() == "Windows");

    public static function parse(pos:HaxeDisplayTypes.Pos, doc:TextDocument, cache:Map<String,Array<String>>):Null<Location> {
        if (pos == null)
            return null;

        var file = getProperFileNameCase(pos.file);
        var uri, getLine;
        if (file == doc.fsPath) {
            uri = doc.uri;
            getLine = doc.lineAt;
        } else {
            uri = Uri.fsPathToUri(file);
            var lines;
            if (cache == null) {
                lines = sys.io.File.getContent(file).split("\n");
            } else {
                lines = cache[file];
                if (lines == null)
                    lines = cache[file] = sys.io.File.getContent(file).split("\n");
            }
            getLine = function(n) return lines[n];
        }

        var line = getLine(pos.start.line);
        var startChar = byteOffsetToCharacterOffset(line, pos.start.character);
        if (pos.end.line != pos.start.line)
            line = getLine(pos.end.line);
        var endChar = byteOffsetToCharacterOffset(line, pos.end.character);

        return {
            uri: uri,
            range: {
                start: {line: pos.start.line, character: startChar},
                end: {line: pos.end.line, character: endChar},
            }
        };
    }

    public static inline function byteOffsetToCharacterOffset(string:String, byteOffset:Int):Int {
        var buf = new js.node.Buffer(string, "utf-8");
        return buf.toString("utf-8", 0, byteOffset).length;
    }

    static function getProperFileNameCase(normalizedPath:String):String {
        if (!isWindows) return normalizedPath;
        if (properFileNameCaseCache == null) {
            properFileNameCaseCache = new Map();
        } else {
            var cached = properFileNameCaseCache[normalizedPath];
            if (cached != null)
                return cached;
        }
        var result = normalizedPath;
        var parts = normalizedPath.split("\\");
        if (parts.length > 1) {
            var acc = parts[0];
            for (i in 1...parts.length) {
                var part = parts[i];
                for (realFile in sys.FileSystem.readDirectory(acc)) {
                    if (realFile.toLowerCase() == part) {
                        part = realFile;
                        break;
                    }
                }
                acc = acc + "/" + part;
            }
            result = acc;
        }
        return properFileNameCaseCache[normalizedPath] = result;
    }
}
