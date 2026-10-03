import { h, render } from "preact";
import htm from "htm";

import { FileInfo, LeftToolbar, RightToolbar } from "./reader_components.js";
import { ReaderPaginator } from "./reader_paginator.js";

const html = htm.bind(h);

export function ReaderFooter()  {
    return html`
        <div id="i4">
            <${FileInfo} />

            <${LeftToolbar} />
            <${RightToolbar} />
            <${ReaderPaginator} />
        </div>
    `;
}

export function initializeFooter() {
    render(
        html`<${ReaderFooter} />`, document.getElementById("reader-footer"));
}
