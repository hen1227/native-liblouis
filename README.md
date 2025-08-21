# native-liblouis
[![NPM Version](https://img.shields.io/npm/v/native-liblouis.svg)](https://www.npmjs.com/package/native-liblouis)
[![License](https://img.shields.io/npm/l/native-liblouis.svg)](https://github.com/hen1227/native-liblouis/blob/main/LICENSE)


Use the [Liblouis](https://liblouis.io/) braille translation engine in React Native + Expo (iOS, Android) and on the web (WASM). Out of the box, the package bundles:

- UEB Uncontracted (`en-ueb-g1.ctb`)
- UEB Contracted (`en-ueb-g2.ctb`)
- Their required `include` dependencies

You can add more tables and ship them with your app.

---

## Table of Contents
- [Live Demo](#live-demo)
- [Install](#install)
- [API](#api)
    - [`lou_translateString`](#lou_translatestringinput-string-table-string-string)
    - [`lou_translateBackString`](#lou_translatebackstringinput-string-table-string-string)
    - [`lou_initialize` (web only)](#lou_initialize-promisevoid-web-only)
    - [`lou_isInitialized`](#lou_isinitialized-boolean)
- [Managing Tables](#managing-tables)
    - [Add/Remove with the CLI](#addremove-with-the-cli)
    - [Sync native modules](#sync-native-modules)
- [Using your locally built package](#using-your-locally-built-package)
    - [Pack and install in your app](#pack-and-install-in-your-app)
    - [Monorepo/dev alt](#monorepodev-alt)
- [TODO](#todo)
- [License](#license)

---


## Live Demo

**Website:** https://hen1227.github.io/native-liblouis/

## Install

```sh
# Using npm
npm install native-liblouis

# Or using yarn
yarn add native-liblouis
```

> Want to use a locally modified build (e.g., with extra/other tables)? See [Using your locally built package](#using-your-locally-built-package).

## API

**LibLouis** provides a lot of functionality. However, **native-liblouis** *only* exposes the following functions:

### `lou_translateString(input: string, table: string): string`

Translates a string using the specified LibLouis table.
Returns the translated string in Braille ASCII format.

```ts
import { lou_translateString } from 'native-liblouis';

const table = 'unicode.dis,en-ueb-g2.ctb'; // includes ASCII mapping
const result = lou_translateString(
  'Hello world',
  table
);

console.log(result); // ⠓⠑⠇⠇⠕ ⠺⠕⠗⠇⠙
```

---

### `lou_translateBackString(input: string, table: string): string`

Translates a Braille ASCII string back to text using the specified LibLouis table.
Returns the translated string in text format.

```ts
const table = 'unicode.dis,en-ueb-g2.ctb';
const braille = '⠓⠑⠇⠇⠕ ⠺⠕⠗⠇⠙';

const result = lou_translateBackString(
  braille,
  table
);

console.log(result); // Hello world
```

---

### `lou_initialize(): Promise<void>` *(Web only)*

Initializes the LibLouis library and loads the bundled tables.
**Must** be called before using any translation functions **on web**.
On iOS and Android, initialization happens automatically.

```ts
if (Platform.OS === 'web') {
  await lou_initialize();
}
```

---

### `lou_isInitialized(): boolean`

Returns whether the LibLouis library has been initialized.

```ts
if (!lou_isInitialized()) {
  console.warn('LibLouis not ready yet');
}
```

See the [example app](https://github.com/hen1227/native-liblouis/blob/main/example/App.tsx) for a full usage example.

---


## Managing Tables

You can ship extra Liblouis tables with your app. This repo includes a few npm-based tools and scripts.

### Add/Remove with the CLI

```sh
# Add tables (will also pull required dependencies via `include` directives)
npm run tables:add en-ueb-math.ctb
npm run tables:add da-dk-g2.ctb vi-vn-g2.ctb

# Remove a table
npm run tables:remove en-ueb-math.ctb

# List bundled tables
npm run tables:list

# Clear them all
npm run tables:clear
```
> The CLI automatically resolves dependencies and downloads tables from the [LibLouis repository](https://github.com/liblouis/liblouis/tree/master/tables).

> You can also drop `.ctb/.utb/.dis/.cti` files manually into `bundled_tables/`, but the CLI is safer and resolves dependencies.

### Sync native modules

* **Only tables changed (native + web by default):**

  ```sh
  npm run tables:sync
  ```

  This updates the list of tables bundled in the native modules. Because the web build embeds tables in the WASM bundle, this step also rebuilds the WebAssembly module with the new tables.


* If you **don’t** need web updated, you can skip WASM work with:

  ```sh
  npm run tables:sync:noweb
  ```

* **Rebuild native modules (iOS/Android C/C++ libs):**

  ```sh
  npm run rebuild-native
  ```

> After syncing or rebuilding, pack and reinstall the package in your app (see next section).

---

---

## Using your locally built package

### Pack and install in your app

When you’ve updated tables or rebuilt natives:

```sh
# In native-liblouis repo root
npm pack
# => produces something like native-liblouis-0.2.0.tgz
```

Then, in your app:

```sh
# From your app’s root
npm i ../path/to/native-liblouis/native-liblouis-0.2.0.tgz
# or with yarn/pnpm if you prefer
```

You can also point `package.json` to the tarball:

```json
{
  "dependencies": {
    "native-liblouis": "file:../native-liblouis/native-liblouis-0.2.0.tgz"
  }
}
```

### Monorepo/dev alt

For quick iteration you can use a `file:` folder dep:

```json
{
  "dependencies": {
    "native-liblouis": "file:../native-liblouis"
  }
}
```

…but for reproducible builds and CI, prefer the tarball produced by `npm pack`.

---

## TODO
- [ ] Allow runtime table loading from custom table path
- [ ] Add more tests
- [ ] Add more documentation

---

## License
This project is licensed under the LGPL-2.1 or later license. See the [LICENSE](LICENSE) file for details.
Liblouis itself is licensed under the LGPL-2.1 or later license.

## Contributing

Any contributions are welcome! If you find a bug, have a feature request, or want to improve the documentation, please open an issue or submit a pull request.
Here are some people who have contributed to native-liblouis so far:

<a href="https://github.com/hen1227/native-liblouis/graphs/contributors">
  <img alt="contributors" src="https://contrib.rocks/image?repo=hen1227/native-liblouis" />
</a>

And a special thanks to [Liblouis](https://liblouis.io/) for providing the braille translation engine that powers this package.
