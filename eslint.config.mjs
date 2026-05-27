import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import stylistic from "@stylistic/eslint-plugin";
import globals from "globals";

// Magical typing definition so rule intellisense works https://github.com/microsoft/vscode-eslint/issues/1122
/**
 * @type {import('eslint').Linter.Config<import('eslint/rules').ESLintRules>}
 */
const config = {
    files: ["**/*.js"],
    plugins: {
        js,
        "@stylistic": stylistic,
    },
    extends: ["js/recommended"],

    languageOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        globals: {
            ...globals.browser,
            ...globals.jquery,
            // LANraragi specific
            // TODO rework all main scripts to no longer store data in the global scope, probably transition to ES modules
            Backup: "readonly",
            Batch: "readonly",
            Category: "readonly",
            Common: "readonly",
            Config: "readonly",
            Duplicates: "readonly",
            Edit: "readonly",
            I18N: "readonly",
            Index: "readonly",
            IndexTable: "readonly",
            Logs: "readonly",
            LRR: "readonly",
            Plugins: "readonly",
            Reader: "readonly",
            Server: "readonly",
            Stats: "readonly",
            // external packages
            Awesomplete: "readonly",
            marked: "readonly",
            Sortable: "readonly",
            Swiper: "readonly",
            tagger: "readonly",
            tippy: "readonly",
        },
    },

    rules: {
        "func-names": ["error", "never"],
        "no-alert": "off",
        "no-console": "warn",
        "no-else-return": "off",
        "no-implicit-globals": "error",
        "no-multi-assign": ["error", {
            "ignoreNonDeclaration": true,
        }],
        "no-param-reassign": ["error", {
            props: false,
        }],
        "no-plusplus": ["error", {
            "allowForLoopAfterthoughts": true,
        }],
        "no-unused-expressions": ["error", {
            "allowShortCircuit": true,
            "allowTernary": true,
        }],
        "no-unused-vars": ["warn", {
            "argsIgnorePattern": "^_",
            "varsIgnorePattern": "^_",
        }],
        "one-var": "off",
        "prefer-destructuring": ["warn", {
            object: true,
            array: false,
        }],

        "@stylistic/indent": ["error", 4, { "SwitchCase": 1 }],
        "@stylistic/one-var-declaration-per-line": ["error", "initializations"],
        "@stylistic/quotes": ["error", "double", { "allowTemplateLiterals": true }],
    },
};

export default defineConfig([
    globalIgnores(["public/js/vendor/*.js", "tests/samples/*"]),
    config,
]);
