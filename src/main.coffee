esprima = require("esprima")
resolve = require("resolve")
sourceMap = require("source-map")
fs = require("fs")
path = require("path")
cprocess = require("child_process")
assert = require("assert")
#===============================================================================
mods = []
filePathIndexesInMods = {}
compileCommands = {}
dummies = []
sourceMapEnabled = false
checkCode = (filePath, isDummy = false) ->
    rawCodeType = path.extname(filePath).substr(1) # strip the leading "."
    rawCode = fs.readFileSync(filePath, {encoding: "utf8"})
    baseDirectory = path.dirname(filePath)
    code =
        if isDummy
            ""
        else if rawCodeType == "js"
            rawCode
        else if rawCodeType == "json"
            """
                module.exports =

                #{rawCode}

                ;

            """
        else
            command = compileCommands[rawCodeType]
            if command?
                cprocess.execSync(command, {
                    encoding: "utf8"
                    input: rawCode
                })
            else
                rawCode
    mod = {}
    mods.push(mod)
    mod.code = code
    mod.nameIndexes = {}
    mod.rawFilename = path.basename(filePath)
    filePathIndexesInMods[filePath] = mods.length - 1
    parsed = esprima.parse(code)
    checkTreeNode = (node) ->
        if not (typeof node == "object" and node != null)
            return
        if node.type == "CallExpression" and
                node.callee.type == "Identifier" and
                node.callee.name == "require" and
                node.arguments[0]? and
                node.arguments[0].type == "Literal"
            requireString = node.arguments[0].value
            newFilePath =
                try
                    resolve.sync(requireString, {
                        basedir: baseDirectory
                        extensions: [".js", ".json", ".coffee"]
                    })
                catch # when `require` an inexistent module
                    null
            # when `require` a node core module
            if newFilePath? and newFilePath.search(/^[A-Za-z][A-Za-z0-9\-_]*$/) != -1
                newFilePath = null
            if newFilePath?
                if not filePathIndexesInMods[newFilePath]?
                    checkCode(newFilePath, requireString in dummies)
                mod.nameIndexes[requireString] ?= filePathIndexesInMods[newFilePath]
        if Array.isArray(node)
            node.forEach((m) -> checkTreeNode(m))
        else
            Object.keys(node).forEach((m) -> checkTreeNode(node[m]))
    checkTreeNode(parsed)
#===============================================================================
# "386389655257694535" is to avoid naming conflicts.
# Modifying string constants inside it should be very careful, because
# after that we MUST also modify the `offsetStart`, `offsetModStart` and
# `offsetModEnd` constants to match them.
writeOutput = ->
    modsBodyStr = mods.map((mod) ->
        """
            {
            fun: function(exports, module, require) {

            #{mod.code}

            },
            nameIndexes: #{JSON.stringify(mod.nameIndexes)},
            result: initialModResult_386389655257694535
            }

        """
    ).join(",\n")
    bundleStr = """
        // This wrapper is to prevent global variable assignments. It's not to
        // prevent naming conflicts ("386389655257694535" already does), but to
        // work better with minification tools.
        (function() {
            // `{}` is to guarantee that any subsequent `mod.result` assignment will make
            // the variable different from the initial value.
            var initialModResult_386389655257694535 = {};

            var mods_386389655257694535 = [
            #{modsBodyStr}
            ];

            // This wrapper is to prevent naming conflicts.
            (function() {
                var initialModResult = initialModResult_386389655257694535;
                var mods = mods_386389655257694535;
                var run = function(index) {
                    var mod = mods[index];
                    var theExports = {};
                    var theModule = {exports: theExports};
                    var theRequire = function(name) {

                        // half-way result, for caching & preventing infinite loops
                        mod.result = theModule.exports;

                        var newIndex = mod.nameIndexes[name];
                        if (newIndex === undefined) {
                            throw new Error("Cannot find module " + JSON.stringify(name) + ".");
                        }
                        if (mods[newIndex].result === initialModResult) {
                            run(newIndex);
                        }
                        return mods[newIndex].result;
                    };
                    mod.fun.apply(theExports, [theExports, theModule, theRequire]);
                    mod.result = theModule.exports; // for caching
                };
                run(0);
            })();
        })();

    """
    if sourceMapEnabled then do ->
        offsetStart = 9 # lines before #{modsBodyStr} in the whole bundle string
        offsetModStart = 3 # lines before #{mod.code} in a mod string
        offsetModEnd = 5 + 1 # lines after #{mod.code} in a mod string, plus a line of a comma
        mapGen = new sourceMap.SourceMapGenerator()
        offset = offsetStart
        mods.forEach((mod) ->
            lfCount = 0
            for i in [0...mod.code.length]
                if mod.code[i] == "\n"
                    lfCount++
            lineCount = if mod.code[mod.code.length - 1] == "\n" then lfCount else lfCount + 1
            offset += offsetModStart
            for i in [1..lineCount]
                # The "source-map" package is very strange:
                # `line` starts with 1, but `column` starts with 0.
                mapGen.addMapping(
                    generated:
                        line: offset + i
                        column: null
                    source: mod.rawFilename
                    original:
                        line: i
                        column: null
                )
            offset += lfCount + offsetModEnd
        )
        bundleStr += "\n" + "//# sourceMappingURL=data:application/json;base64," +
                new Buffer(mapGen.toString()).toString("base64") + "\n"
    process.stdout.write(bundleStr)
#===============================================================================
args = process.argv[..]
args.splice(0, 2) # strip "node" and the name of this file
file = null
i = 0
while i < args.length
    arg = args[i]
    if arg.indexOf("-c:") != -1
        compileCommands[arg.split(":")[1]] = args[i + 1]
        i += 2
    else if arg == "-d"
        assert(args[i + 1].search(/^(\/|\.\/|\.\.\/)/) == -1)
        dummies.push(args[i + 1])
        i += 2
    else if arg == "-m"
        sourceMapEnabled = true
        i++
    else
        assert(arg[0] != "-")
        file = arg
        i++
checkCode(path.resolve(file))
writeOutput()
