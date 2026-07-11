import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import stylistic from "@stylistic/eslint-plugin";
import globals from "globals";
import importX from 'eslint-plugin-import-x';

// Magical typing definition so rule intellisense works https://github.com/microsoft/vscode-eslint/issues/1122
/**
 * @type {import('eslint').Linter.Config<import('eslint/rules').ESLintRules>}
 */
const config = {
    files: ["**/*.js"],
    plugins: {
        js,
        "@stylistic": stylistic,
        'import-x': importX,
    },
    extends: ["js/recommended"],

    languageOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        globals: {
            ...globals.browser,
            ...globals.jquery,
            // external packages
            Awesomplete: "readonly",
            Raty: "readonly",
            Sortable: "readonly",
            Swiper: "readonly",
            tagger: "readonly",
            tippy: "readonly",
        },
    },

    rules: {
        "func-names": ["error", "never"],
        "no-alert": "off",
        "no-console": "off",
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

        "import-x/no-unresolved": [
            "error",
            {
                ignore: [
                    "i18n",
                ]
            }
        ],

        "@stylistic/semi": ["error", "always"],
        "@stylistic/indent": ["error", 4, { "SwitchCase": 1 }],
        "@stylistic/one-var-declaration-per-line": ["error", "initializations"],
        "@stylistic/quotes": ["error", "double", { "allowTemplateLiterals": true }],
    },
};

export default defineConfig([
    importX.flatConfigs.recommended,
    globalIgnores(["public/js/vendor/**", "tests/samples/*"]),
    config,
]);
