# js-bundler

Bundles the specified file and all "required" files into one. Similar to browserify, but no Node built-in module shims, no source mapping. So it's lightweight.

Because it doesn't provide shims, please only bundle "browser" or "neutral" packages that don't depend on Node built-in modules.

# Synopsis

```
bundle [-c:<file-type> <command>]... [-d <require-string>]... [-i] <file>
bundle (-v | --version)
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

(Note: `-c` is for Node 0.12 or higher.)

To bundle a JavaScript file that "requires" CoffeeScript files, that is, the .js file has `require("coffee-script/register")`:

```bash
bundle -c:coffee 'coffee -bcs' -d 'coffee-script/register' example.js
```

`-d` means "dummy". It will bundle an empty module rather than the real "coffee-script/register" module.

Sometimes you want to prevent something from being bundled (for instance, it will never be run on browser). There are 3 ways to do that: dummy, the browser field, or a `module.` prefix.

The browser field specification:

https://gist.github.com/defunctzombie/4339901

The `module.` prefix is just a trick:

```javascript
if (environment === "server") {
    var abc = module.require("./abc");
}
```

Note that dummies applies only to require strings, and only to external package modules. Another difference is that a dummy is treated as a module so "require" doesn't throw an error, but if you use `module.` prefix and your condition doesn't prevent the inner code running, then `module.require` will throw an error.

To add informative data (i.e. raw file's relative path to the working directory) to the output:

```bash
bundle -i example.js
```

This is useful in debugging. But for security, we recommend you use this option only for testing, or use a minifier to remove JavaScript comments in its downloadable version, because this option discloses the relative paths.

To print the version:

```bash
bundle -v
```

# Output

The 18-digit number 674497323404793172 in the output is just an identifier of js-bundler related things. When you search for "file-674497323404793172" (representing the start position of every file) while debugging in browser, the results are very accurate. Here's part of an example output:

```javascript
// *****
// ***** sss.coffee file-674497323404793172
// ***** (((

// Generated by CoffeeScript 1.9.1
(function() {
  return console.log("inner");
})();

console.log("done");

// ***** ))) file end
```
