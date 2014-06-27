esprima = require("esprima")
resolve = require("resolve")
fs = require("fs")
path = require("path")
args = process.argv[..]
args.splice(0, 2) # strip "node" and the name of this file
#========================================
mods = []
filePathIndexesInMods = {}
checkCode = (code, baseDirectory, filePath) ->
    mod = {}
    mods.push(mod)
    mod.code = code
    mod.nameIndexes = {}
    if filePath?
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
            newFilePath = resolve.sync(requireString, {basedir: baseDirectory})
            if not filePathIndexesInMods[newFilePath]?
                checkCode(
                    fs.readFileSync(newFilePath, {encoding: "utf8"}),
                    path.dirname(newFilePath),
                    newFilePath
                )
            mod.nameIndexes[requireString] ?= filePathIndexesInMods[newFilePath]
        if Array.isArray(node)
            node.forEach((m) -> checkTreeNode(m))
        else
            Object.keys(node).forEach((m) -> checkTreeNode(node[m]))
    checkTreeNode(parsed)
#========================================
file = args[0]
[code, baseDirectory, filePath] =
    if file == "-" then [
        process.stdin.read()
        path.resolve(".")
        null
    ] else [
        fs.readFileSync(file, {encoding: "utf8"})
        path.dirname(path.resolve(file))
        path.resolve(file)
    ]
checkCode(code, baseDirectory, filePath)
#========================================
modsBodyStr = mods.map((mod) ->
    """
        {
        fun: function(exports, module, require) {

        #{mod.code}

        },
        nameIndexes: #{JSON.stringify(mod.nameIndexes)},
        result: null
        }

    """
).join(",\n")
# "386389655257694535" is to avoid naming conflict.
bundleStr = """
    var mods_386389655257694535 = [
    #{modsBodyStr}
    ];

    (function() {
        var run = function(index) {
            var mods = mods_386389655257694535;
            var mod = mods[index];
            var theExports = {};
            var theModule = {exports: theExports};
            var theRequire = function(name) {
                var newIndex = mod.nameIndexes[name];
                if (mods[newIndex].result === null) {
                    return run(newIndex);
                } else {
                    return mods[newIndex].result;
                }
            };
            mod.fun.apply(theExports, [theExports, theModule, theRequire]);
            mod.result = theModule.exports;
            return mod.result;
        };
        run(0);
    })();

"""
process.stdout.write(bundleStr)
