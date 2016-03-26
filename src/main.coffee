esprima = require("esprima")

# All (or nearly all) options in "resolve" package are valid
# in package "browser-resolve", though some are missing in browser-resolve's readme.
resolve = require("browser-resolve")

fs = require("fs")
path = require("path")
cprocess = require("child_process")
assert = require("assert")
packageInfo = require("../package.json")

mods = []
filePathIndexesInMods = {}
compileCommands = {}
dummies = []
informative = false
checkCode = (filePath, isDummy = false) ->
    assert(filePath.indexOf("\"") == -1, "File path can't contain `\"`.")
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
    if code[code.length - 1] != "\n"
        code += "\n"
    mod = {}
    mods.push(mod)
    mod.code = code
    mod.nameIndexes = {}
    mod.rawFilePath = filePath
    filePathIndexesInMods[filePath] = mods.length - 1

    # The function wrapper is just to prevent some parsing error. It is temporary and won't be kept
    # in the output.
    # If the wrapper is missing, the outermost `return` in code (if any) will be treated
    # as illegal so will cause parsing error.
    # An alternative way is to use the `tolerant` option, but I think `tolerant` is not better
    # than this.
    parsed =
        try
            esprima.parse("""
                (function(exports, module, require) {
                #{code}
                })();
            """)
        catch
            throw new Error("Syntax error in \"#{filePath}\".")

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

# "674497323404793172" is to avoid naming conflicts.
writeOutput = ->
    modsBodyStr = mods.map((mod) ->
        info = if informative then path.relative(process.cwd(), mod.rawFilePath) + " " else ""
        """
            {\
            fun: function(exports, module, require) {


            // *****
            // ***** #{info}file-674497323404793172
            // ***** (((

            #{mod.code}
            // ***** ))) file end


            }, \
            nameIndexes: #{JSON.stringify(mod.nameIndexes)}, \
            result: initialModResult_674497323404793172\
            }
        """
    ).join(", ")
    bundleStr = """
        // This wrapper is to prevent global variable assignments. It's not to
        // prevent naming conflicts ("674497323404793172" already does), but to
        // work better with minification tools.
        (function() {
            // `{}` is to guarantee that any subsequent `mod.result` assignment will make
            // the variable different from the initial value.
            var initialModResult_674497323404793172 = {};

            var mods_674497323404793172 = [
            #{modsBodyStr}
            ];

            // This wrapper is to prevent naming conflicts.
            (function() {
                var initialModResult = initialModResult_674497323404793172;
                var mods = mods_674497323404793172;
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
    process.stdout.write(bundleStr)

args = process.argv[..]
args.splice(0, 2) # strip "node" and the name of this file
file = null
doesBundle = true
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
    else if arg == "-i"
        informative = true
        i++
    else if arg in ["--version", "-v"]
        console.log(packageInfo.version)
        doesBundle = false
        i++
    else
        assert(arg[0] != "-", "Invalid argument.")
        file = arg
        i++
if (doesBundle)
    assert(file?, "Must specify a file.")
    checkCode(path.resolve(file))
    writeOutput()
