const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../../public/js/mod/server.js"), "utf8")
    .replace(/^import .*;\r?\n/gm, "").replace(/^export /gm, "");

function setup() {
    const calls = [];
    let resolveSave;
    const saved = new Promise((resolve) => { resolveSave = resolve; });
    const context = vm.createContext({
        I18N: {},
        LRR: { showErrorToast: () => {} },
        $: () => ({ val: () => "argument", show: () => {}, hide: () => {} }),
        save: (selector) => { calls.push(["save", selector]); return saved; },
        queue: (...args) => { calls.push(["queue", args[0], args[1]]); return Promise.resolve(); }
    });
    vm.runInContext(`${source}\nsaveFormData = save; callAPI = queue;`, context);
    return { context, calls, resolveSave };
}

test("script is queued only after settings have finished saving", async () => {
    const { context, calls, resolveSave } = setup();
    context.triggerScript("example");
    assert.deepEqual(calls, [["save", "#editPluginForm"]]);

    resolveSave();
    await new Promise(setImmediate);
    assert.deepEqual(calls, [
        ["save", "#editPluginForm"],
        ["queue", "/api/plugins/queue?plugin=example&arg=argument", "POST"]
    ]);
});

test("repeated clicks while saving do not queue another script", async () => {
    const { context, calls, resolveSave } = setup();
    context.triggerScript("example");
    context.triggerScript("example");
    assert.equal(calls.filter(([type]) => type === "queue").length, 0);
    assert.equal(calls.filter(([type]) => type === "save").length, 1);
    resolveSave();
    await new Promise(setImmediate);
    assert.equal(calls.filter(([type]) => type === "queue").length, 1);
});
