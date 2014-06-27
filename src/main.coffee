esprima = require("esprima")
resolve = require("resolve")
fs = require("fs")
path = require("path")
#===============================================================================
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
#===============================================================================
writeOutput = ->
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
#===============================================================================
code = baseDirectory = filePath = null
generate = ->
    checkCode(code, baseDirectory, filePath)
    writeOutput()
#===============================================================================
args = process.argv[..]
args.splice(0, 2) # strip "node" and the name of this file
file = args[0]
if file == "-"
    code = ""
    baseDirectory = path.resolve(".")
    filePath = null
    process.stdin.setEncoding("utf8")
    process.stdin.on("readable", ->
        chunk = process.stdin.read()
        if chunk?
            code += chunk
    )
    process.stdin.on("end", ->
        generate()
    )
else
    code = fs.readFileSync(file, {encoding: "utf8"})
    filePath = path.resolve(file)
    baseDirectory = path.dirname(filePath)
    generate()
