#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import https from "node:https";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUNDLED = path.resolve(__dirname, "../bundled_tables");
const BASE = "https://raw.githubusercontent.com/liblouis/liblouis/master/tables/";
const VALID_EXT = new Set([".ctb", ".utb", ".uti", ".dis"]); // common table/display/chardef files

const arg = process.argv[2];
const rest = process.argv.slice(3);

if (!fs.existsSync(BUNDLED)) fs.mkdirSync(BUNDLED, { recursive: true });

const fetchText = (url) =>
    new Promise((res, rej) => {
        https
            .get(url, (r) => {
                if (r.statusCode !== 200) return rej(new Error(`HTTP ${r.statusCode} for ${url}`));
                let d = "";
                r.setEncoding("utf8");
                r.on("data", (c) => (d += c));
                r.on("end", () => res(d));
            })
            .on("error", rej);
    });

const save = (name, text) => fs.writeFileSync(path.join(BUNDLED, name), text, "utf8");
const existsLocal = (name) => fs.existsSync(path.join(BUNDLED, name));

const parseIncludes = (text) => {
    const inc = [];
    for (const line of text.split(/\r?\n/)) {
        // capture ONLY the filename token after "include", ignore anything after that
        const m = line.match(/^\s*include\s+([^\s#;]+)\b/i);
        if (m) inc.push(m[1].trim());
    }
    return inc;
};


async function downloadOne(name, visited) {
    if (visited.has(name)) return;
    visited.add(name);

    const ext = path.extname(name);
    if (!VALID_EXT.has(ext)) {
        // ignore strange includes (hyphenation dicts etc.) unless they’re real files in /tables
        // you can extend VALID_EXT if needed
    }
    if (!existsLocal(name)) {
        const url = BASE + name;
        const txt = await fetchText(url);
        save(name, txt);
        console.log(`✓ downloaded ${name}`);
        // recurse includes
        const includes = parseIncludes(txt);
        for (const dep of includes) await downloadOne(dep, visited);
    } else {
        const txt = fs.readFileSync(path.join(BUNDLED, name), "utf8");
        const includes = parseIncludes(txt);
        for (const dep of includes) await downloadOne(dep, visited);
    }
}

function listLocal() {
    return fs
        .readdirSync(BUNDLED)
        .filter((f) => VALID_EXT.has(path.extname(f)))
        .sort();
}

async function addCmd() {
    if (rest.length === 0) {
        console.error("Usage: npm run tables:add <table1.ctb> [table2.utb ...]");
        process.exit(1);
    }
    const visited = new Set();
    for (const name of rest) await downloadOne(name, visited);

    console.log("\nDone. Now run: npm run build-liblouis");
}

function removeCmd() {
    if (rest.length === 0) {
        console.error("Usage: npm run tables:remove <table.ctb|*.utb|.dis>");
        process.exit(1);
    }
    for (const name of rest) {
        const fp = path.join(BUNDLED, name);
        if (fs.existsSync(fp)) {
            fs.unlinkSync(fp);
            console.log(`✗ removed ${name}`);
        } else {
            console.warn(`(not found) ${name}`);
        }
    }
    console.log("\nDone. Now run: npm run build-liblouis");
}

function listCmd() {
    const files = listLocal();
    if (!files.length) return console.log("(no bundled tables)");
    for (const f of files) console.log(f);
}

function clearCmd() {
    for (const f of listLocal()) fs.unlinkSync(path.join(BUNDLED, f));
    console.log("Cleared bundled tables.\nNow run: npm run build-liblouis");
}

(async () => {
    switch (arg) {
        case "add": await addCmd(); break;
        case "remove": removeCmd(); break;
        case "list": listCmd(); break;
        case "clear": clearCmd(); break;
        default:
            console.log(`Usage:
  npm run tables:add <table.ctb ...>
  npm run tables:remove <file ...>
  npm run tables:list
  npm run tables:clear`);
    }
})();
