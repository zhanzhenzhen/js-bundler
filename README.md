# js-bundler

Bundles the specified file and all "required" files into one. Similar to browserify, but no node built-in module shims. So it's lightweight.

Requirements:

Node 0.11.13 or higher.

# Synopsis

```
bundle [-c:<type> <command>]... [-d <require-string>]... <file>
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

To bundle a JavaScript file that "requires" CoffeeScript files, that is, the .js file has `require("coffee-script/register")`:

```bash
bundle -c:coffee 'coffee -bcs' -d 'coffee-script/register' example.js
```

`-d` means "dummy". It will bundle an empty module rather than the real "coffee-script/register" module.

In your code you can prevent a module from being bundled (For instance, the part of the code will only be run at server side). Simply add a `module.` prefix before `require`:

```javascript
if (environmentType === "node") {
    var domain = module.require("domain").create();
}
```
