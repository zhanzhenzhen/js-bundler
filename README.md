# js-bundler

Bundles the specified file and all "required" files into one. Similar to browserify, but no Node built-in module shims, no source mapping. So it's lightweight.

Because it doesn't provide shims, please only bundle "browser" or "neutral" packages that don't depend on Node built-in modules.

# Synopsis

```
bundle [-c:<file-type> <command>]... [-d <require-string>]... [-i] <file>
bundle -v
```

# Examples

```bash
bundle example.js
```

This will send the bundled output to stdout.

To output to a file:

```bash
bundle example.js > bundle.js
```

To bundle CoffeeScript:

```bash
bundle -c:coffee 'coffee -bcs' example.coffee
```

(Note: `-c` is for Node 0.11.13 or higher.)

To bundle a JavaScript file that "requires" CoffeeScript files, that is, the .js file has `require("coffee-script/register")`:

```bash
bundle -c:coffee 'coffee -bcs' -d 'coffee-script/register' example.js
```

`-d` means "dummy". It will bundle an empty module rather than the real "coffee-script/register" module.

To prevent a module from being bundled (for instance, it will never be run on browser), either use `-d` in the command or add a `module.` prefix before `require` in the code:

```javascript
if (environment === "server") {
    var abc = module.require("./abc");
}
```

Their runtime behaviors are similar, except that a dummy is treated as a module so "require" doesn't throw an error, but if you use `module.` prefix and your condition doesn't prevent the inner code running, then `module.require` will throw an error.

To add raw file's relative path (to the working directory) to the output:

```bash
bundle -i example.js
```

This is useful in debugging. But for security, we recommend you only use this option in testing, or use some tools to remove comments in the public downloadable bundle file, because this option makes the raw file's relative path disclosed.

To show the version:

```bash
bundle -v
```
