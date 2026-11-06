const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

// Load the page module with UI imports and DOM-ready initialization disabled.
// Only the jQuery operations used by the comparator need a DOM stand-in.
const source = fs.readFileSync(path.join(__dirname, "../../public/js/duplicates.js"), "utf8")
    .replace(/^import .*;\r?\n/gm, "");
const context = vm.createContext({ $: (row) => row, jQuery: () => {} });
vm.runInContext(`${source}\n globalThis.compareDuplicates = Duplicates.compareDuplicates;`, context);

function compare(values, type, order = "desc") {
    const rows = values.map((value) => ({
        checked: false,
        find(selector) {
            return selector === ".form-check-input"
                ? { prop: (_, checked) => { this.checked = checked; } }
                : { text: () => value };
        }
    }));
    rows.forEach((row, index) => { row[0] = index; });
    const collection = { each: (callback) => rows.forEach((row) => callback.call(row)) };
    context.compareDuplicates(collection, "value", type, order);
    return rows.map((row) => row.checked);
}

test("groups with an unknown date are not automatically selected", () => {
    for (const values of [
        ["", "2026-01-01 12:00:00", "2026-02-01 12:00:00"],
        ["2026-01-01 12:00:00", "", "2026-02-01 12:00:00"],
        ["2026-01-01 12:00:00", "2026-02-01 12:00:00", ""],
        ["", ""]
    ]) {
        for (const order of ["asc", "desc"]) {
            assert.deepEqual(compare(values, "date", order), values.map(() => false));
        }
    }
});

test("invalid numeric metadata leaves the group unselected", () => {
    assert.deepEqual(compare(["10", "unknown", "20"], "integer"), [false, false, false]);
    assert.deepEqual(compare(["10.5", "", "20.5"], "float"), [false, false, false]);
});

test("valid dates still retain the requested oldest or youngest file", () => {
    const dates = ["2026-01-01 12:00:00", "2026-02-01 12:00:00", "2026-03-01 12:00:00"];
    assert.deepEqual(compare(dates, "date"), [true, true, false]);
    assert.deepEqual(compare(dates, "date", "asc"), [false, true, true]);
});

test("valid numeric comparisons and ties preserve existing behavior", () => {
    assert.deepEqual(compare(["10", "30", "20"], "integer"), [true, false, true]);
    assert.deepEqual(compare(["10.5", "20.5"], "float"), [true, false]);
    assert.deepEqual(compare(["10", "10"], "integer"), [false, false]);
});
