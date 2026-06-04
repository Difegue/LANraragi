import { h } from "preact";
import htm from "htm";

import { state, changePage } from "./reader_common.js";
import { computed } from "@preact/signals";

const html = htm.bind(h);

export function ReaderPaginator()  {
    const currentPage = computed(() => {
        if (state.currentPage.value === -1) {
            return "...";
        }
        return state.showingSinglePage.value ? state.currentPage.value + 1 : `${state.currentPage.value + 1} + ${state.currentPage.value + 2}`;
    });

    const maxPage = computed(() => {
        if (state.maxPage.value === -1) {
            return "...";
        }
        return state.maxPage.value + 1;
    });

    function multiNavStyle() {
        if (!state.multiArchiveNavigation.value) {
            return "display:none;";
        }
        return "";
    }

    return html`
        <div class="sn paginator">
            <a class="fa fa-backward-step page-link archive-nav-link" style=${`font-size: 1.5em; ${multiNavStyle}`} onclick=${(e) => {e.preventDefault(); changePage("outermost-left", true); }}></a>
            <a class="fa fa-angle-double-left page-link" style="font-size: 1.5em;" onclick=${(e) => {e.preventDefault(); changePage("first", true);}}></a>
            <a class="fa fa-angle-left page-link" style="font-size: 1.5em;" onclick=${(e) => {e.preventDefault(); changePage(-1, true);}}></a>

            <div class="pagecount">
                <span class="current-page">${currentPage}</span> /
                <span class="max-page">${maxPage}</span>
            </div>

            <a class="fa fa-angle-right page-link" style="font-size: 1.5em;" onclick=${(e) => {e.preventDefault(); changePage(1, true);}}></a>
            <a class="fa fa-angle-double-right page-link" style="font-size: 1.5em;" onclick=${(e) => {e.preventDefault(); changePage("last", true);}}></a>
            <a class="fa fa-forward-step page-link archive-nav-link" style=${`font-size: 1.5em; ${multiNavStyle}`} onclick=${(e) => {e.preventDefault(); changePage("outermost-right", true); }}></a>
        </div>
    `;
}
