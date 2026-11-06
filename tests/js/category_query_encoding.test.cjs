const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../../public/js/category.js"), "utf8")
    .replace(/^import .*;\r?\n/gm, "").replace(/^export /gm, "");

function setup(name, search = "", pinned = false) {
    const calls = [];
    const elements = {
        category: { value: "SET_1234567890" }, catname: { value: name },
        catsearch: { value: search }, pinned: { checked: pinned }, status: {}
    };
    const context = vm.createContext({
        URLSearchParams,
        I18N: {},
        LRR: { showPopUp: async () => ({ isConfirmed: true, value: name }) },
        Server: { callAPI: (endpoint, method) => calls.push({ endpoint, method }) },
        document: { getElementById: (id) => elements[id] }
    });
    vm.runInContext(`${source}\nglobalThis.category = Category;`, context);
    return { category: context.category, calls };
}

for (const dynamic of [false, true]) {
    test(`creating a ${dynamic ? "dynamic" : "static"} category preserves reserved characters`, async () => {
        const name = "日本語 & C++ #1 50% = done";
        const { category, calls } = setup(name);
        category.addNewCategory(dynamic);
        await new Promise(setImmediate);
        assert.equal(calls.length, 1);
        const url = new URL(calls[0].endpoint, "https://example.test");
        assert.equal(url.pathname, "/api/categories");
        assert.equal(url.searchParams.get("name"), name);
        assert.equal(url.searchParams.get("search"), dynamic ? "language:english" : "");
        assert.equal(url.hash, "");
        assert.equal(calls[0].method, "PUT");
    });
}

for (const pinned of [false, true]) {
    test(`updating a category preserves name and predicate (pinned=${pinned})`, () => {
        const name = "A&B + #favorites";
        const search = 'artist:a&b, title:c++ #1, 日本語, 50%, =value';
        const { category, calls } = setup(name, search, pinned);
        category.saveCurrentCategoryDetails();
        const url = new URL(calls[0].endpoint, "https://example.test");
        assert.equal(url.pathname, "/api/categories/SET_1234567890");
        assert.equal(url.searchParams.get("name"), name);
        assert.equal(url.searchParams.get("search"), search);
        assert.equal(url.searchParams.get("pinned"), pinned ? "1" : "0");
        assert.equal([...url.searchParams.keys()].length, 3);
        assert.equal(url.hash, "");
    });
}
