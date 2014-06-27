# js-bundler

Bundles the specified file and all required files into one. Similar to browerify, but no shims, no other weird side-effects.

```bash
bundle example.js
```

This will send the bundled output to stdout.

To output to a file:

```bash
bundle example.js > bundle.js
```

To input from stdin:

```bash
bundle -
```
