/**
 * Functions related to the settings dialog
 */

import { h, render } from "preact";
import { useState } from "preact/hooks";
import { computed } from "@preact/signals";
import { Show } from "@preact/signals/utils";
import htm from "htm";

import { state, stopAutoNextPage, toggleOverlay } from "./reader_common.js";
import I18N from "i18n";

const html = htm.bind(h);

function ToggleButton({ id, active, onClick, label }) {
    return html`<input id=${id} class="favtag-btn config-btn ${active ? "toggled" : ""}"
        type="button" onClick=${onClick} value=${label} />`;
}

function SettingsPanel() {
    const [autoNextPageInterval, setAutoNextPageInterval] = useState(state.AutoNextPageInterval.value);
    const [containerWidth, setContainerWidth] = useState(state.containerWidth.value);
    const [preloadCount, setPreloadCount] = useState(state.preloadCount.value);

    function updateAutoNextPageInterval() {
        const val = parseInt(autoNextPageInterval, 10);
        if (!isNaN(val)) {
            state.AutoNextPageInterval.value = val;
        }
        stopAutoNextPage();
    }

    function updateContainerWidth() {
        const raw = containerWidth !== null?containerWidth.trim():"";

        if (!raw)
        {
            state.containerWidth.value = null;
        }
        else {
            let value,
                type;

            [, value, type] = /^(\d+)(px|%)?$/.exec(raw);
            value = value || 1200;
            type = type || "px";
            state.containerWidth.value = `${value}${type}`;
        }
    }

    function updatePreloadCount() {
        state.preloadCount.value = preloadCount;
    }

    const notInfiniteScroll = computed(() => !state.infiniteScroll.value);
    const isFitContainerMode = computed(() => state.fitMode.value === "fit-container");

    return html`
        <h2 class="ih" style="text-align:center">${I18N.ReaderOptions}</h2>
        <h1 class="ih config-panel">${I18N.OptionsAutoSave}</h1>

        <div id="fit-mode">
            <h2 class="config-panel">${I18N.FitDisplayTo}</h2>
            <${ToggleButton} id="fit-container" active=${state.fitMode.value === "fit-container"} onClick=${() => state.fitMode.value = "fit-container"} label=${I18N.FitContainer} />
            <${ToggleButton} id="fit-width" active=${state.fitMode.value === "fit-width"} onClick=${() => state.fitMode.value = "fit-width"} label=${I18N.FitWidth} />
            <${ToggleButton} id="fit-height" active=${state.fitMode.value === "fit-height"} onClick=${() => state.fitMode.value = "fit-height"} label=${I18N.FitHeight} />
        </div>

        <${Show} when=${isFitContainerMode}>
            <div id="container-width">
                <h2 class="config-panel">${I18N.ContainerWidth}</h2>
                <input id="container-width-input" class="stdinput" style="display:inline; width: 70%;" placeholder=${I18N.ContainerWidthDefaultValue} value=${containerWidth} onInput=${(e) => setContainerWidth(e.target.value)} />
                <input id="container-width-apply" class="favtag-btn config-btn" type="button" style="display:inline;" onClick=${updateContainerWidth} value=${I18N.Apply} />
            </div>
        <//>

        <${Show} when=${notInfiniteScroll}>
            <div id="toggle-double-mode">
                <h2 class="config-panel">${I18N.PageRendering}</h2>
                <${ToggleButton} id="single-page" active=${!state.doublePageMode.value} onClick=${() => state.doublePageMode.value = false} label=${I18N.Single} />
                <${ToggleButton} id="fit-width" active=${state.doublePageMode.value} onClick=${() => state.doublePageMode.value = true} label=${I18N.Double} />
            </div>
        <//>

        <${Show} when=${notInfiniteScroll}>
            <div id="toggle-manga-mode">
                <h2 class="config-panel">${I18N.ReadingDirection}</h2>
                <span class="config-panel"></span>
                <${ToggleButton} id="normal-mode" active=${!state.mangaMode.value} onClick=${() => state.mangaMode.value = false} label=${I18N.LeftToRight} />
                <${ToggleButton} id="manga-mode" active=${state.mangaMode.value} onClick=${() => state.mangaMode.value = true} label=${I18N.RightToLeft} />
            </div>
        <//>

        <${Show} when=${notInfiniteScroll}>
            <div id="preload-images">
                <h2 class="config-panel">${I18N.HowManyToPreload}</h2>
                <input id="preload-input" class="stdinput" style="display:inline" placeholder=${I18N.DefaultTwoImages} type="number" value=${preloadCount} onInput=${(e) => setPreloadCount(e.target.value)}  />
                <input id="preload-apply" class="favtag-btn config-btn" type="button" style="display:inline;" onClick=${updatePreloadCount} value=${I18N.Apply} />
            </div>
        <//>

        <${Show} when=${notInfiniteScroll}>
            <div id="toggle-header">
                <h2 class="config-panel">${I18N.Header}</h2>
                <${ToggleButton} id="show-header" active=${!state.hideHeader.value} onClick=${() => state.hideHeader.value = false} label=${I18N.Visible} />
                <${ToggleButton} id="hide-header" active=${state.hideHeader.value} onClick=${() => state.hideHeader.value = true} label=${I18N.Hidden} />
            </div>
        <//>

        <div id="toggle-overlay">
            <h2 class="config-panel">${I18N.ShowArchiveOverlayByDefault}</h2>
            <span class="config-panel">${I18N.ShowArchiveOverlayByDefaultDescription}</span>
            <${ToggleButton} id="show-overlay" active=${state.showOverlayByDefault.value} onClick=${() => state.showOverlayByDefault.value = true} label=${I18N.Enabled} />
            <${ToggleButton} id="hide-overlay" active=${!state.showOverlayByDefault.value} onClick=${() => state.showOverlayByDefault.value = false} label=${I18N.Disabled} />
        </div>

        <div id="toggle-progress">
            <h2 class="config-panel">${I18N.ProgressionTracking}</h2>
            <span class="config-panel">${I18N.DisableTrackingWillRestartReading}</span>
            <${ToggleButton} id="track-progress" active=${!state.ignoreProgress.value} onClick=${() => state.ignoreProgress.value = false} label=${I18N.Enabled} />
            <${ToggleButton} id="untrack-progress" active=${state.ignoreProgress.value} onClick=${() => state.ignoreProgress.value = true} label=${I18N.Disabled} />
        </div>

        <div id="toggle-infinite-scroll">
            <h2 class="config-panel">${I18N.InfiniteScrolling}</h2>
            <span class="config-panel">${I18N.DisplayAllImagesInAVerticalView}</span>
            <${ToggleButton} id="infinite-scroll-on" active=${state.infiniteScroll.value} onClick=${() => state.infiniteScroll.value = true} label=${I18N.Enabled} />
            <${ToggleButton} id="infinite-scroll-off" active=${!state.infiniteScroll.value} onClick=${() => state.infiniteScroll.value = false} label=${I18N.Disabled} />
        </div>

        <div id="auto-next-page">
            <h2 class="config-panel">${I18N.AutoNextPageIntervalInSeconds}</h2>
            <input id="auto-next-page-input" class="stdinput" style="display:inline" placeholder=${I18N.TheDefaultIs10Seconds} value=${autoNextPageInterval} onInput=${(e) => setAutoNextPageInterval(e.target.value)} />
            <input id="auto-next-page-apply" class="favtag-btn config-btn" type="button" style="display:inline;" onClick=${updateAutoNextPageInterval} value=${I18N.Apply} />
        </div>

        <${Show} when=${notInfiniteScroll}>
            <div id="toggle-stamps-visibility">
                <h2 class="config-panel">${I18N.ToggleStamps}</h2>
                <input id="toggle-stamps" class="fa" type="checkbox" checked=${state.markersVisible.value} onClick=${() => state.markersVisible.value = !state.markersVisible.value} />
            </div>
        <//>
    `;
}

export function initializeSettings() {
    render(
        html`<${SettingsPanel} />`, document.getElementById("settingsOverlay"));

    $(document).on("click.toggle-settings-overlay", "#toggle-settings-overlay", toggleSettingsOverlay);
}

export function toggleSettingsOverlay() {
    stopAutoNextPage();
    return toggleOverlay("#settingsOverlay");
}
