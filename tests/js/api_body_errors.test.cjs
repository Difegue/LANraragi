const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../../public/js/mod/server.js"), "utf8")
    .replace(/^import .*;\r?\n/gm, "").replace(/^export /gm, "");

function setup(data) {
    const errors = [];
    const toasts = [];
    const requests = [];
    const context = vm.createContext({
        LRR: {
            ApiURL: class { constructor(url) { this.url = url; } },
            toast: (options) => toasts.push(options),
            showErrorToast: (heading, error) => errors.push({ heading, message: error.message })
        },
        fetch: async (url, options) => {
            requests.push({ url: url.url, ...options });
            return { json: async () => data };
        }
    });
    vm.runInContext(source, context);
    return { context, errors, toasts, requests };
}

test("OpenAPI validation errors do not report success or invoke the success callback", async () => {
    const { context, errors, toasts } = setup({ errors: [{ message: "Invalid metadata" }] });
    let called = false;
    await context.callAPIBody("/api/example", "PUT", "{}", "Saved", "Save failed", () => { called = true; });
    assert.equal(called, false);
    assert.equal(toasts.length, 0);
    assert.deepEqual(errors, [{ heading: "Save failed", message: "Invalid metadata" }]);
});

test("legacy API failures keep their error message", async () => {
    const { context, errors, toasts } = setup({ success: 0, error: "Write failed" });
    await context.callAPIBody("/api/example", "PUT", "{}", "Saved", "Save failed", null);
    assert.equal(toasts.length, 0);
    assert.deepEqual(errors, [{ heading: "Save failed", message: "Write failed" }]);
});

test("successful writes preserve body, content type, toast and callback result", async () => {
    const data = { success: 1, successMessage: "Metadata updated" };
    const { context, errors, toasts, requests } = setup(data);
    const result = await context.callAPIBody("/api/example", "PUT", "{}", "Saved", "Save failed",
        (response) => { assert.equal(response, data); return "done"; }, "application/json");
    assert.equal(result, "done");
    assert.equal(toasts[0].heading, "Metadata updated");
    assert.equal(errors.length, 0);
    assert.equal(requests[0].body, "{}");
    assert.equal(requests[0].headers["Content-Type"], "application/json");
});
