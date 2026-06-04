import { h } from "preact";
import htm from "htm";
import fscreen from "fscreen";
import { computed } from "@preact/signals";

import { state, toggleBookmark, toggleHelp, toggleMangaMode, toggleAutoNextPage, toggleFullScreen } from "./reader_common.js";
import { toggleSettingsOverlay } from "./reader_options.js";
import { toggleArchiveOverlay } from "./reader_archive_overlay.js";

import I18N from "i18n";

const html = htm.bind(h);

export function ToggleButton({ id, active, onClick, label }) {
    return html`<input id=${id} class="favtag-btn config-btn ${active ? "toggled" : ""}"
        type="button" onClick=${onClick} value=${label} />`;
}

export function BookmarkButton() {
    return html`
        <a class="${state.isBookmarked.value ? "fa" : "far"} fa-bookmark fa-2x" href="#" title=${I18N.ToggleBookmark} onclick=${(e) => {e.preventDefault();toggleBookmark();}}></a>
    `;
}

export function FileInfo()
{
    const title = computed(() => {
        if (state.showingSinglePage.value) {
            return `${state.filename.value} :: ${state.width.value} x ${state.height.value} :: ${state.size.value} KB`;
        } else {
            return `${state.filename.value} - ${state.filenameDoublePage.value} :: ${state.width.value + state.width2.value} x ${state.height.value} :: ${state.size.value + state.size2.value} KB`;
        }
    });

    return html`
        <div class="file-info" title=${title.value}>${title}</div>
    `;
}

export function LeftToolbar() {
    return html`
        <div class="absolute-options absolute-left">
            <a class="fa fa-cog fa-2x" id="toggle-settings-overlay" href="#" title=${I18N.ReaderSettings} onClick=${(e) => { e.preventDefault(); toggleSettingsOverlay(); }}></a>
            <a class="fa fa-question-circle fa-2x" id="toggle-help" href="#" title=${I18N.Help} onClick=${(e) => { e.preventDefault(); toggleHelp(); }}></a>
            <${BookmarkButton} />
        </div>
    `;
}
export function RightToolbar() {
    return html`
        <div class="absolute-options absolute-right">
            <a class="fa fa-${state.mangaMode.value ? "arrow-left" : "arrow-right"} fa-2x reading-direction" href="#" title=${I18N.ReadingDirection} onClick=${(e) => { e.preventDefault(); toggleMangaMode(); }}></a>
            <a class="fa ${!state.autoNextPage.value?"fa-stopwatch":""} fa-2x toggle-auto-next-page" href="#" title=${I18N.AutoNextPage} onClick=${(e) => { e.preventDefault(); toggleAutoNextPage(); }}>
                ${state.autoNextPage.value ? state.autoNextPageCountdown.value : ""}
            </a>
            <a class="fa fa-th fa-2x" id="toggle-archive-overlay" href="#" title=${I18N.ArchiveOverview} onClick=${(e) => { e.preventDefault(); toggleArchiveOverlay(); }}></a>
            <a class="fa fa-compress fa-2x" id="toggle-full-screen" href="#" title=${I18N.FullScreen} onClick=${(e) => { e.preventDefault(); toggleFullScreen(); }} style=${!fscreen.fullscreenEnabled ? { display: "none" } : {}}></a>
        </div>
    `
}