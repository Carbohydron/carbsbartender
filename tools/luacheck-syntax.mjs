// Syntax-check Lua files with luaparse (Lua 5.1). Usage: deno run -A tools/luacheck-syntax.mjs <files...>
import luaparse from "npm:luaparse@0.3.1";
let bad = 0;
for (const f of Deno.args) {
  try {
    luaparse.parse(Deno.readTextFileSync(f), { luaVersion: "5.1", encodingMode: "x-user-defined" });
  } catch (e) {
    bad++;
    console.log(`${f}: ${e.message}`);
  }
}
console.log(bad ? `${bad} file(s) with errors` : `OK (${Deno.args.length} files)`);
Deno.exit(bad ? 1 : 0);
