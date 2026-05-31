/**
 * Functions related to the settings dialog
 */

import { state, goToPage, stopAutoNextPage, toggleOverlay, applyContainerWidth } from "./reader_common.js";
import { clearMarkers } from "./reader_stamps.js";

export function initializeSettings() {
    registerPreload();
    registerAutoNextPage();

    $(document).on("click.toggle-fit-mode", "#fit-mode input", toggleFitMode);
    $(document).on("click.toggle-double-mode", "#toggle-double-mode input", toggleDoublePageMode);
    $(document).on("click.toggle-manga-mode", "#toggle-manga-mode input, .reading-direction", toggleMangaMode);
    $(document).on("click.toggle-header", "#toggle-header input", toggleHeader);
    $(document).on("click.toggle-progress", "#toggle-progress input", toggleProgressTracking);
    $(document).on("click.toggle-infinite-scroll", "#toggle-infinite-scroll input", toggleInfiniteScroll);
    $(document).on("click.toggle-overlay", "#toggle-overlay input", toggleOverlayByDefault);
    $(document).on("submit.container-width", "#container-width-input", registerContainerWidth);
    $(document).on("click.container-width", "#container-width-apply", registerContainerWidth);
    $(document).on("submit.preload", "#preload-input", registerPreload);
    $(document).on("click.preload", "#preload-apply", registerPreload);
    $(document).on("submit.auto-next-page", "#auto-next-page-input", registerAutoNextPage);
    $(document).on("click.auto-next-page", "#auto-next-page-apply", registerAutoNextPage);

    $(document).on("click.toggle-settings-overlay", "#toggle-settings-overlay", toggleSettingsOverlay);

    // Initialize settings and button toggles
    if (localStorage.hideHeader === "true" || false) {
        $("#hide-header").addClass("toggled");
        $("#i2").hide();
    } else {
        $("#show-header").addClass("toggled");
    }

    state.mangaMode = localStorage.mangaMode === "true" || false;
    if (state.mangaMode) {
        $("#manga-mode").addClass("toggled");
        $(".reading-direction").toggleClass("fa-arrow-left fa-arrow-right");
    } else {
        $("#normal-mode").addClass("toggled");
    }

    state.doublePageMode = localStorage.doublePageMode === "true" || false;
    state.doublePageMode ? $("#double-page").addClass("toggled") : $("#single-page").addClass("toggled");

    state.ignoreProgress = localStorage.ignoreProgress === "true" || false;
    state.ignoreProgress ? $("#untrack-progress").addClass("toggled") : $("#track-progress").addClass("toggled");

    state.infiniteScroll = localStorage.infiniteScroll === "true" || false;
    $(state.infiniteScroll ? "#infinite-scroll-on" : "#infinite-scroll-off").addClass("toggled");

    state.showOverlayByDefault = localStorage.showOverlayByDefault === "true" || false;
    $(state.showOverlayByDefault ? "#show-overlay" : "#hide-overlay").addClass("toggled");

    if (localStorage.fitMode === "fit-width") {
        state.fitMode = "fit-width";
        $("#fit-width").addClass("toggled");
        $("#container-width").hide();
    } else if (localStorage.fitMode === "fit-height") {
        state.fitMode = "fit-height";
        $("#fit-height").addClass("toggled");
        $("#container-width").hide();
    } else {
        state.fitMode = "fit-container";
        $("#fit-container").addClass("toggled");
    }

    state.containerWidth = localStorage.containerWidth;
    if (state.containerWidth) { $("#container-width-input").val(state.containerWidth); }

    state.markersVisible = localStorage.markersVisible === "true" || false;
    $("#toggle-stamps").prop("checked", state.markersVisible);
}

function toggleFitMode(e) {
    // possible options: fit-container, fit-width, fit-height
    state.fitMode = localStorage.fitMode = e.target.id;
    $("#fit-mode input").removeClass("toggled");
    $(e.target).addClass("toggled");

    if (state.fitMode === "fit-container") {
        $("#container-width").show();
    } else {
        $("#container-width").hide();
    }
    applyContainerWidth();
}

function registerContainerWidth() {
    // Examples of allowed values: 1200, 1200px, 90%
    // Default value: 1200px
    const raw = $("#container-width-input").val().trim();
    if (!raw) { // fall back to default
        delete state.containerWidth;
        localStorage.removeItem("containerWidth");
    } else {
        let value, type;

        [, value, type] = /^(\d+)(px|%)?$/.exec(raw);
        value = value || 1200;
        type = type || "px";

        state.containerWidth = localStorage.containerWidth = `${value}${type}`;
    }
    applyContainerWidth();
}

function registerPreload() {
    const rawInputVal = $("#preload-input").val();
    const inputVal = rawInputVal === "" ? null : rawInputVal;
    const storageVal = (localStorage.preloadCount === "" ? null : localStorage.preloadCount);

    state.preloadCount = inputVal ?? storageVal ?? 2;
    $("#preload-input").val(state.preloadCount);
    localStorage.preloadCount = state.preloadCount;
}

export function toggleDoublePageMode() {
    if (state.infiniteScroll) { return; }
    state.doublePageMode = localStorage.doublePageMode = !state.doublePageMode;
    $("#toggle-double-mode input").toggleClass("toggled");
    goToPage(state.currentPage);
}

export function toggleMangaMode() {
    if (state.infiniteScroll) { return false; }
    state.mangaMode = localStorage.mangaMode = !state.mangaMode;
    $("#toggle-manga-mode input").toggleClass("toggled");
    $(".reading-direction").toggleClass("fa-arrow-left fa-arrow-right");
    if (!state.showingSinglePage) { goToPage(state.currentPage); }

    return false;
}

function toggleHeader() {
    if (state.infiniteScroll) { return false; }
    localStorage.hideHeader = $("#i2").is(":visible");
    $("#toggle-header input").toggleClass("toggled");
    $("#i2").toggle();
    applyContainerWidth();
    return false;
}

function toggleProgressTracking() {
    state.ignoreProgress = localStorage.ignoreProgress = !state.ignoreProgress;
    $("#toggle-progress input").toggleClass("toggled");
}

function toggleInfiniteScroll() {
    clearMarkers();
    state.infiniteScroll = localStorage.infiniteScroll = !state.infiniteScroll;
    $("#toggle-infinite-scroll input").toggleClass("toggled");
    window.location.reload();
}

function registerAutoNextPage() {
    state.AutoNextPageInterval = +$("#auto-next-page-input").val().trim() || +localStorage.AutoNextPageInterval || 10;
    $("#auto-next-page-input").val(state.AutoNextPageInterval);
    localStorage.AutoNextPageInterval = state.AutoNextPageInterval;

    stopAutoNextPage();
}

function toggleOverlayByDefault() {
    state.showOverlayByDefault = localStorage.showOverlayByDefault = !state.showOverlayByDefault;
    $("#toggle-overlay input").toggleClass("toggled");
}

export function toggleSettingsOverlay() {
    stopAutoNextPage();
    return toggleOverlay("#settingsOverlay");
}
