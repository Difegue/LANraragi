import { h, render } from "preact";
import htm from "htm";

import { state } from "./reader_common.js";
import { computed } from "@preact/signals";
import { FileInfo, LeftToolbar, RightToolbar } from "./reader_components.js";
import { ReaderPaginator } from "./reader_paginator.js";
import { ApiURL } from "./common.js";

const html = htm.bind(h);

export function ReaderHeader()  {
    const hideHeader = computed(() => {
        return state.hideHeader.value || state.infiniteScroll.value;
    });
    
    const defaultTitle = computed(() => {
        return state.content.value?.title || "...";
    });

    const artistUrl = computed(() => {
        return new ApiURL(`/?sort=0&q=artist%3A${encodeURIComponent(state.artist.value)}%24&`);
    });

    return html`
        <div id="i2" style=${hideHeader.value ? { display: "none" } : {}}>
            <h1 id="archive-title">
                ${!state.artist.value
                        ? html`${defaultTitle.value}`
                        : html`${defaultTitle.value} by <a href=${artistUrl}>${state.artist.value}</a>`
                }
            </h1>

            <${LeftToolbar} />
            <${RightToolbar} />
            <${ReaderPaginator} />
            <${FileInfo} />
        </div>
    `;
}

export function initializeHeader() {
    render(
        html`<${ReaderHeader} />`, document.getElementById("header"));
}
