/**
 * Reader main entrypoint and shared functionality.
 */
import * as Server from "./server.js";
import * as LRR from "./common.js";
import I18N from "i18n";
import fscreen from "fscreen";
import { signal, effect, computed, batch } from "@preact/signals";
import { initializeStamps, updateStamps, renderMarkers, clearMarkers } from "./reader_stamps.js";
import { initializeArchiveOverlay, toggleArchiveOverlay, updateArchiveOverlay, addCategoryBadge, removeCategoryBadge } from "./reader_archive_overlay.js";
import { initializeSettings, toggleSettingsOverlay } from "./reader_options.js";
import { initializeHeader } from "./reader_header.js";
import { initializeFooter } from "./reader_footer.js";

/**
 * @typedef Content
 * @property {string} id
 * @property {string} title
 * @property {number} pages
 * @property {Array} chapters
 * @property {string} tags
 * @property {string} summary
 */

export let state = {
    id: "",
    force: false,
    previousPage: -1,
    currentPage: signal(0),
    currentChapter: null,
    showingSinglePage: signal(true), // TODO: compute
    pageThumbnails: [],
    preloadedImg: {},
    preloadedSizes: {},
    archiveIndex: -1,
    archiveIds: [],
    spaceScroll: { timeout: null, animationId: null },
    //Spacebar Scroll Config
    scrollConfig: {
        scrollDist: 75,      // Viewport % distance to scroll
        underSnap: 13,       // Distance % for snapping to edge of current image
        overSnap: 40,        // Distance % for snapping back to current image after continuous scroll
        holdDelay: 350,      // Delay time in ms before continuous scroll starts on keydown
        scrollSpeed: 22      // Speed % to scroll when spacebar is held
    },
    autoNextPage: signal(false),
    autoNextPageCountdownTaskId: undefined,
    autoNextPageCountdown: signal(0),
    trackProgressLocally: null,
    authenticateProgress: null,
    containerWidth: signal(localStorage.containerWidth || null),
    content: signal(/** @type {Content} */{
        id: "",
        title: "",
        pages: 0,
        chapters: [],
        tags: "",
        summary: "",
    }),
    pages: signal(/** @type {Array<string>} */ []),
    maxPage: computed(() => {
        return state.pages.value.length - 1;
    }),
    mangaMode: signal(localStorage.mangaMode === "true" || false),
    doublePageMode: signal(localStorage.doublePageMode === "true" || false),
    ignoreProgress: signal(localStorage.ignoreProgress === "true" || false),
    infiniteScroll: signal(localStorage.infiniteScroll === "true" || false),
    fitMode: signal(localStorage.fitMode || "fit-container"),
    hideHeader: signal(localStorage.hideHeader === "true" || false),
    currentPageLoaded: false,
    progress: undefined,
    showOverlayByDefault: signal(localStorage.showOverlayByDefault === "true" || false),
    preloadCount: signal((localStorage.preloadCount === "" ? null : localStorage.preloadCount) ?? 2),
    AutoNextPageInterval: signal(/** @type {number} */+localStorage.AutoNextPageInterval || 10),
    markerMode: false,
    markersVisible: signal(localStorage.markersVisible === "true" || false),
    markers: [],
    overlayFiltered: false,
    pageNaviState: true,
    wakeLock: null,
    isBookmarked: signal(/** @type boolean|null */null),
    filename: signal(""), // TODO: compute from bigger object
    filenameDoublePage: signal(""), // TODO: compute from bigger object
    width: signal(0),
    height: signal(0),
    size: signal(0),
    // Ugly but eh
    width2: signal(0),
    height2: signal(0),
    size2: signal(0),
    artist: computed(() => {
        const res = state.content.value.tags.match(/artist:([^,]+)(?:,|$)/i);
        if (res) {
            return res[1];
        }
        return "";
    }),
    /**
     * @param {number} newCount
     */
    setCurrentPage: function (newCount) {
        state.currentPage.value = Math.max(+newCount, 0);
    },
    multiArchiveNavigation: signal(false),
};

let infiniteScrollObserver = null;

export async function initializeAll(trackProgressLocally, authenticateProgress) {
    state.trackProgressLocally = trackProgressLocally;
    state.authenticateProgress = authenticateProgress;

    initializeSettings();
    initializeHeader();
    initializeFooter();
    initFullscreen();
    applyContainerWidth();
    initializeStamps();
    initializeArchiveOverlay();
    document.documentElement.style.scrollBehavior = "smooth";

    // Bind events to DOM
    $(document).on("keyup", (e) => handleShortcuts(e));
    // Restrict keydown to only function for spacebar
    $(document).on("keydown", (e) => { if (e.which === 32) handleShortcuts(e); });
    $(document).on("wheel", handleWheel);

    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.regenerate-archive-cache", "#regenerate-cache", () => {
        window.location.href = new LRR.ApiURL(`/reader?id=${state.id}&force_reload`);
    });

    // Return to index, re-applying the search/page state the user came from
    $(document).on("click.return-to-index", "#return-to-index", () => {
        returnToIndex();
    });

    // Infer initial information from the URL
    const params = new URLSearchParams(window.location.search);
    state.id = params.get("id");
    state.force = params.get("force_reload") !== null;
    state.setCurrentPage((+params.get("p") || 1) - 1);

    // Set up archive navigation state from the entry source (datatables vs carousel vs direct nav)
    await setupArchiveNavigation();

    // Remove the "new" tag with an api call (archives only; tanks don't have an isnew flag)
    if (!state.id.startsWith("TANK_"))
        Server.callAPI(`/api/archives/${state.id}/isnew`, "DELETE", null, I18N.ReaderErrorClearingNew, null);

    // Load metadata for the requested ID and populate the page
    loadContentData().then(() => {

        // Regex look in tags for artist
        const artist = state.content.value.tags.match(/artist:([^,]+)(?:,|$)/i);
        if (artist) {
            const artistName = artist[1];
            const artistSearchUrl = `/?sort=0&q=artist%3A${encodeURIComponent(artistName)}%24&`;
            const link = $("<a></a>")
                .attr("href", artistSearchUrl)
                .text(artistName);
            const titleContainer = $("<span></span>")
                .text(`${state.content.value.title} by `)
                .append(link);
            $("#archive-title-overlay").empty().append(titleContainer.clone());
        } else {
            $("#archive-title-overlay").text(state.content.value.title);
        }

        $("#tagContainer").append(LRR.buildTagsDiv(state.content.value.tags));

        const ratyEl = document.querySelector(`[data-raty]`);
        if (ratyEl) {
            const rating = LRR.splitTagsByNamespace(state.content.value.tags).rating?.at(0).length;
            new Raty(ratyEl, {
                starType: `i`,
                cancelButton: true,
                cancelClass: `fas fa-trash raty-cancel`,
                cancelHint: I18N.ReaderClearRating,
                cancelPlace: `right`,
                score: rating,
                click: function(score, element, evt) {

                    let tags = LRR.splitTagsByNamespace(state.content.value.tags);
                    let selectedRating = score;

                    if (selectedRating === null)
                        delete tags.rating;
                    else {
                        // Create a tag with star emoji corresponding to the rating (e.g. rating:⭐⭐⭐ for a 3-star rating)
                        selectedRating = "⭐".repeat(score);
                        tags.rating = [selectedRating];
                    }

                    let tagList = LRR.buildTagList(tags);
                    if (state.id.startsWith("TANK_")) 
                        Server.updateTagsFromTankoubon(state.id, tagList);
                    else 
                        Server.updateTagsFromArchive(state.id, tagList);
                    $("#tagContainer > table").replaceWith(LRR.buildTagsDiv(tagList.join(",")));
                }
            }).init();
        }

        $("#tagContainer").append(`<div class="archive-summary"/>`);
        $(".archive-summary").text(state.content.value.summary);

        // Get the chapter for the current page (if any)
        state.currentChapter = getCurrentChapter();

        // Load the actual reader pages now that we have basic info
        loadImages()
            .then(() => {
                effect(() => {
                    if (state.infiniteScroll.value) {
                        enterInfiniteScrollView();
                    } else {
                        enterStandardView();
                    }
                });
                effect(() => {
                    if (state.infiniteScroll.value) { return; }
                    refreshCurrentPage();
                });
            });
    });

    // Fetch "bookmark" category ID and setup icon
    loadBookmarkStatus();


    // Hook up all the signal fun!
    effect(() => {
        if (state.infiniteScroll.value) { return; }
        localStorage.mangaMode = state.mangaMode.value;
        // This can cause a spurious refresh, but is required to update the fileinfo bar
        refreshCurrentPage();
    });

    effect(() => {
        if (state.infiniteScroll.value) { return; }
        localStorage.doublePageMode = state.doublePageMode.value;
    });

    effect(() => {
        localStorage.fitMode = state.fitMode.value;
        applyContainerWidth();
    });

    effect(() => localStorage.showOverlayByDefault = state.showOverlayByDefault.value);
    effect(() => localStorage.ignoreProgress = state.ignoreProgress.value);
    effect(() => {
        if (state.containerWidth.value === null) {
            localStorage.removeItem("containerWidth");
        } else {
            localStorage.containerWidth = state.containerWidth.value;
        }
    });

    effect(() => {
        if (state.infiniteScroll.value) { return; }
        localStorage.hideHeader = state.hideHeader.value;
        applyContainerWidth();
    });

    effect(() => {
        clearMarkers();
        localStorage.infiniteScroll = state.infiniteScroll.value;
    });

    effect(() => {
        localStorage.AutoNextPageInterval = +state.AutoNextPageInterval.value || 10;
    });

    effect(() => {
        localStorage.preloadCount = state.preloadCount.value;
    });

    effect(() => {
        document.tile = state.content.value.title;
    });
}

export function loadContentData() {

    // Initialize content object to hold metadata -- This is a recursive object that will be used to build the page overlay.
    // (For tanks, content.chapters will hold archive chapters that can themselves contain nested chapters from ToCs)
    let content = {
        id: state.id,
        title: "",
        pages: 0,
        chapters: [],
        tags: "",
        summary: ""
    };

    const updateProgress = function(data, id) {
        // Use localStorage progress value instead of the server one if needed
        if (state.trackProgressLocally && !(state.authenticateProgress && LRR.isUserLogged())) {
            state.progress = localStorage.getItem(`${id}-reader`) - 1 || 0;
        } else {
            state.progress = data.progress - 1;
        }
    };

    // If the ID is a Tank ID (TANK_xxxx), use the Tankoubon API for metadata
    if (state.id.startsWith("TANK_")) {

        return fetch(new LRR.ApiURL(`/api/tankoubons/${state.id}/full`))
            .then(r => r.ok ? r.json() : Promise.reject(new Error(I18N.ServerInfoError)))
            .then(data => {
                const tank = data.result;
                content = {
                    ...content,
                    title: tank.name,
                    tags: tank.tags || "",
                    summary: tank.summary || "",
                    chapters: [],
                };

                // full_data contains pre-fetched metadata for every archive in order
                const fullData = tank.full_data || [];
                // Cumulative offset as we iterate through the arclist
                let pageOffset = 0;

                fullData.forEach(meta => {
                    if (!meta) return;

                    // Create archive chapter (with nested ToC chapters if present)
                    const archiveChapters = LRR.buildTankChapters(meta, pageOffset);
                    content = {
                        ...content,
                        chapters: content.chapters.push(...archiveChapters)
                    };

                    pageOffset += meta.pagecount || 0;
                });

                state.content.value = {
                    ...content,
                    pages: pageOffset,
                };
                updateProgress(tank, state.id);
            })
            .catch(err => LRR.showErrorToast(I18N.ServerInfoError, err));
    }

    return Server.callAPI(`/api/archives/${state.id}/metadata`, "GET", null, I18N.ServerInfoError,
        (data) => {
            batch(() =>
            {
                state.content.value = {
                    ...state.content.value,
                    title: data.title,
                    pages: data.pagecount,
                    tags: data.tags,
                    summary: data.summary,
                };

                updateProgress(data, state.id);

                if (data.toc) {
                    state.content.value = {
                        ...state.content.value,
                        chapters: LRR.buildArchiveChapters(data.toc, state.id, data.pagecount),
                    };
                }
            });
            // Check and display warnings for unsupported filetypes
            checkFiletypeSupport(data.extension);
        }
    );
}

/**
 * For Tank mode: map a page number to the archive it belongs to and said archive's local page number.
 * @param {number} globalPage global page number
 * @returns {{ arcId: string, localPage: number }}
 */
export function getArchiveForPage(globalPage) {
    if (state.id.startsWith("TANK_")) {
        const arc = state.content.value.chapters.find(a => globalPage >= a.startPage && globalPage <= a.endPage);
        if (arc)
            return { arcId: arc.id, localPage: globalPage - arc.startPage + 1 };
    }
    return { arcId: state.id, localPage: globalPage };
}

function loadImages() {

    const onLoad = (data) => {
        batch(() => {
            state.pages.value = data;
            // Choices in order for page picking:
            // * p is in parameters and is not the first page
            // * progress is tracked and is not the last page
            // * first page
            // This allows for bookmarks to trump progress
            // when there's no parameter, null is coerced to 0 so it becomes -1
            state.setCurrentPage(state.currentPage.peek() || (
                !state.ignoreProgress.value && state.progress < state.maxPage.peek()
                    ? state.progress
                    : 0
            ));
        });

        if (state.showOverlayByDefault.value) { toggleArchiveOverlay(); }

        // Resume slideshow if it was active before cross-archive navigation
        if (sessionStorage.getItem("autoNextPage") === "true") {
            sessionStorage.removeItem("autoNextPage");
            startAutoNextPage();
        }
    };

    const onFinally = () => {
        if (state.pages.value === undefined) {
            $("#img").attr("src", new LRR.ApiURL("/img/flubbed.gif").toString());
            $("#display").append(`<h2>${I18N.ReaderArchiveError}</h2>`);
        }
        generateThumbnails();
    };

    if (state.id.startsWith("TANK_")) {
        // For tanks: fetch pages for each archive and concatenate them
        return Promise.all(
            state.content.value.chapters.map(arc =>
                fetch(new LRR.ApiURL(`/api/archives/${arc.id}/files?force=${state.force}`))
                    .then(r => r.ok ? r.json() : Promise.reject())
            )
        ).then(results => {
            onLoad(results.flatMap(r => r.pages));
        }).catch(() => LRR.showErrorToast(I18N.ReaderArchiveError))
            .finally(onFinally);
    }
    else {
        return Server.callAPI(`/api/archives/${state.id}/files?force=${state.force}`, "GET", null, I18N.ReaderArchiveError,
            (data) => onLoad(data.pages),
        ).finally(onFinally);
    }
}

function initFullscreen() {
    // Apply full-screen utility
    // F11 Fullscreen is totally another "Fullscreen", so its support is beyond consideration.
    fscreen.onfullscreenchange = () => handleFullScreen(fscreen.fullscreenElement !== null);
}

/**
 * Small override function, always returns boolean
 */
export function inFullscreen() {
    return !!fscreen.fullscreenElement;
}

function enterInfiniteScrollView() {
    if (infiniteScrollObserver !== null) {
        // We're already in infiniteScrollView
        console.log("Infinite scroll view already active");
        return;
    }

    let loaded = 0;
    function imgOnLoad() {
        // Wait for the pages to load before scrolling to the current page

        loaded += 1;
        if (loaded === state.pages.value.length) {
            allImagesLoaded = true;
            if (window.scrollY === 0) {
                goToPage(state.currentPage.value);
            }
        }
    }

    // Remove standard mode event handlers
    $(document).off("click.changepage");
    const $img = $("#img");
    $img.off("load.updatemeta");
    $img.on("load.infinite-scroll", imgOnLoad);

    $("body").addClass("infinite-scroll");
    $img.attr("src", state.pages.value[0]).addClass("infinite-scroll-image");

    // Disable other options that don't work with infinite scroll
    state.mangaMode.value = false;
    state.doublePageMode.value = false;

    // Create an observer to update progress when a new page is scrolled in
    let allImagesLoaded = false;
    infiniteScrollObserver = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && allImagesLoaded) {
            // Find the entry in the list of images
            const index = entries[0].target.id.replace("page-", "");
            // Convert to int
            const page = parseInt(index, 10);
            // Avoid double progress updates
            if (state.currentPage.value !== page) {
                state.setCurrentPage(page);
                updateProgress();
            }
        }
    }, { threshold: 0.5 });

    state.pages.value.slice(1).forEach((source) => {
        const img = new Image();
        img.id = `page-${state.pages.value.indexOf(source)}`;
        img.height = 800;
        img.width = 600;
        const $img = $(img);
        $img.on("load.infinite-scroll", imgOnLoad);
        img.src = source;

        // infinite-scroll-image-extra is for cleaning up when switching to standard mode
        $img.addClass("reader-image infinite-scroll-image infinite-scroll-image-extra");
        $("#display").append(img);
        infiniteScrollObserver.observe(img);
    });

    $("#i3").removeClass("loading");
    $(document).on("click.infinite-scroll-map", "#display .reader-image", (event) => {
        // is click X position is left on screen or right
        if (event.pageX < $(window).width() / 2) {
            changePage(-1, true);
        } else {
            changePage(1, true);
        }
    });

    applyContainerWidth();

    if (state.content.value.tags?.includes("webtoon")) {
        $("body").addClass("webtoon-mode");
    }
}

function enterStandardView() {
    $("body").removeClass("infinite-scroll");

    if (infiniteScrollObserver !== null) {
        infiniteScrollObserver.disconnect();
        infiniteScrollObserver = null;
    }

    // Remove infinite scroll mode event handlers
    $(document).off("click.infinite-scroll-map", "#display .reader-image");
    $(".infinite-scroll-image-extra").remove();
    const images = $("#display .reader-image");
    images.off("load.infinite-scroll");

    $("#i3").removeClass("loading");
    applyContainerWidth();

    // when click left or right img area change page
    $(document).off("click.changepage").on("click.changepage", (event) => {
        // check click Y position is in img Y area
        if ($(event.target).closest("#i3").length && !$("#overlay-shade").is(":visible") && state.pageNaviState) {
            // is click X position is left on screen or right
            if (event.pageX < $(window).width() / 2) {
                changePage(-1, true);
            } else {
                changePage(1, true);
            }
        }
    });

    $("#img").off("load.updatemeta").on("load.updatemeta", updateMetadata);
}

/** Process inputs
 * @param {JQuery.KeyDownEvent<Document, undefined, Document, Document> | JQuery.KeyUpEvent<Document, undefined, Document, Document>} e
*/
function handleShortcuts(e) {
    if (e.target.tagName === "INPUT") {
        return;
    }

    switch (e.key) {
        case ",":
            readPreviousArchive();
            return;
        case ".":
            readNextArchive();
            return;
    }
    switch (e.which) {
        case 8: // backspace
            returnToIndex();
            break;
        case 27: // escape
            LRR.closeOverlay();
            break;
        case 32: // spacebar
            spaceScrollProcessInput(e);
            break;
        case 37: // left arrow
            if (e.shiftKey) {
                changePage("first", true);
            } else {
                changePage(-1, true);
            }
            break;
        case 39: // right arrow
            if (e.shiftKey) {
                changePage("last", true);
            } else {
                changePage(1, true);
            }
            break;
        case 65: // a
            if (e.shiftKey) {
                changePage("first", true);
            } else {
                changePage(-1, true);
            }
            break;
        case 66: // b
            toggleBookmark();
            break;
        case 68: // d
            if (e.shiftKey) {
                changePage("last", true);
            } else {
                changePage(1, true);
            }
            break;
        case 70: // f
            toggleFullScreen();
            break;

        case 71: // g
            {
                let page = parseInt(prompt(I18N.GoToPage), 10);
                // parseInt returns NaN for non-numbers; normal equality checks don't work to detect NaN
                if (!Number.isNaN(page)) {
                    goToPage(page - 1);
                }
            }
            break;
        case 72: // h
            toggleHelp();
            break;
        case 77: // m
            toggleMangaMode();
            break;
        case 78: // n
            toggleAutoNextPage();
            break;
        case 79: // o
            toggleSettingsOverlay();
            break;
        case 80: // p
            toggleDoublePageMode();
            break;
        case 81: // q
            toggleArchiveOverlay();
            break;
        case 82: // r
            if (e.ctrlKey || e.shiftKey || e.metaKey) { break; }
            sessionStorage.removeItem("navigationState");
            document.location.href = new LRR.ApiURL("/random");
            break;
        default:
            break;
    }
}

/**
 * @param {JQuery.KeyDownEvent | JQuery.KeyUpEvent} e
 */
function spaceScrollProcessInput(e) {
    //Break early and go back to browser default behaviour if overlay is open or gallery has webtoon tag and in infiniteScroll
    if ($(".page-overlay").is(":visible") || e.repeat || (state.infiniteScroll.value && state.content.value.tags?.includes("webtoon"))) return;

    e.preventDefault();
    // Capture direction now so we dont lose it if shift state changes while held
    let direction = e.shiftKey ? -1 : 1;
    if (state.mangaMode.value) direction *= -1;
    const cfg = state.scrollConfig;

    if (e.type === "keydown") {
        if (!state.spaceScroll.timeout) {
            state.spaceScroll.timeout = setTimeout(() => {
                const scrollFn = () => {
                    window.scrollBy({
                        top: direction * (cfg.scrollSpeed / 100 * window.innerHeight)
                    });
                    state.spaceScroll.animationId = requestAnimationFrame(scrollFn);
                };
                state.spaceScroll.animationId = requestAnimationFrame(scrollFn);
            }, cfg.holdDelay);
        }
        return;
    }
    else if (e.type === "keyup") {
        clearTimeout(state.spaceScroll.timeout);
        const wasContinuousScroll = state.spaceScroll.animationId;
        cancelAnimationFrame(state.spaceScroll.animationId);
        state.spaceScroll = { timeout: null, animationId: null };
        const st = window.scrollY;
        const h = window.innerHeight;

        const currentImg = [...document.querySelectorAll(".reader-image")].find(img => {
            const rect = img.getBoundingClientRect();
            return rect.top <= h / 2 && rect.bottom >= h / 2;
        }) || document.querySelector(direction > 0 ? ".reader-image:first-child" : ".reader-image:last-child");

        if (!currentImg) return;

        const imgTop = currentImg.getBoundingClientRect().top + st;
        const imgBottom = currentImg.getBoundingClientRect().bottom + st;
        const directionEdge = direction > 0 ? imgBottom : imgTop;

        // Convert to percentage of pixels compared to window height
        const scrollDistPx = (cfg.scrollDist / 100) * h;
        const overSnapPx = (cfg.overSnap / 100) * h;
        const underSnapPx = (cfg.underSnap / 100) * h;
        // Calculate active thresholds based on direction
        const directionDist = (directionEdge - (direction > 0 ? st + h : st)) * direction;

        // Go to next direction page if already at edge
        if ((direction > 0 ? st + h >= directionEdge - 3 : st <= directionEdge + 3) && !wasContinuousScroll) {
            console.log(`PAGE TURN: ${cfg.scrollDist}% threshold reached`);
            changePage(direction, true);
            return;
        }

        // 2. Continuous scroll overshoot check
        if (wasContinuousScroll) {
            // Calculate actual overshoot distance (positive value)
            const overshootDistance = Math.abs(directionDist) - scrollDistPx;

            if (overshootDistance > overSnapPx) {
                console.log(`CONTINUOUS SNAP: ${overshootDistance.toFixed(1)}px > ${overSnapPx.toFixed(1)}px threshold`);
                const adjImg = direction > 0 ? currentImg.nextElementSibling : currentImg.previousElementSibling;
                if (adjImg) {
                    const adjRect = adjImg.getBoundingClientRect();
                    // Snap to 5px before the edge for better visibility
                    const snapPosition = direction > 0
                        ? adjRect.top + st + 5
                        : adjRect.bottom + st - h - 5;
                    window.scrollTo({ top: snapPosition });
                }
                return;
            }
        }

        // 3. Undershoot prevention
        if (directionDist <= scrollDistPx + underSnapPx) {
            console.log(`UNDERSHOOT SNAP: ${cfg.underSnap}% (${Math.round(directionDist)}px <= ${Math.round(scrollDistPx + underSnapPx)}px)`);
            window.scrollTo({ top: directionEdge - (direction > 0 ? h : 0) });
            return;
        }

        // 4. Default scroll
        console.log(`DEFAULT SCROLL (${Math.abs(directionDist).toFixed(1)}px)`);
        const scrollAmount = direction * scrollDistPx;
        window.scrollBy({ top: scrollAmount });
    }
}

function handleWheel(e) {
    if (inFullscreen() && !state.infiniteScroll.value) {
        let changePageNum = 1;
        if (e.originalEvent.deltaY > 0) changePageNum = -1;
        // In Manga mode, reverse the changePage variable
        // so that we always move forward
        if (!state.mangaMode.value) changePageNum *= -1;
        changePage(changePageNum, true);
    }
}

function checkFiletypeSupport(extension) {
    if ((extension === "rar" || extension === "cbr") && !localStorage.rarWarningShown) {
        localStorage.rarWarningShown = true;
        LRR.toast({
            heading: I18N.ReaderRarWarning,
            text: I18N.ReaderRarWarningDesc,
            icon: "warning",
            hideAfter: 23000,
        });
    } else if (extension === "epub" && !localStorage.epubWarningShown) {
        localStorage.epubWarningShown = true;
        LRR.toast({
            heading: I18N.ReaderEpubWarning,
            text: I18N.ReaderEpubWarningDesc,
            icon: "warning",
            hideAfter: 20000,
            closeOnClick: false,
            draggable: false,
        });
    } else if (extension === "cbw" && !localStorage.cbwWarningShown) {
        localStorage.cbwWarningShown = true;
        LRR.toast({
            heading: I18N.ReaderCbwWarning,
            text: I18N.ReaderCbwWarningDesc,
            icon: "info",
            hideAfter: 20000,
        });
    }
}

export function toggleHelp() {
    LRR.toast({
        toastId: "readerHelp",
        heading: I18N.ReaderNavHelp,
        text: $("#reader-help").children().first().html(),
        icon: "info",
        hideAfter: 60000,
    });

    return false;
    // all toggable panes need to return false to avoid scrolling to top
}

export function toggleBookmark() {
    if (!localStorage.getItem("bookmarkCategoryId")) {
        console.error("No bookmark category ID found!");
        return;
    }

    if (!LRR.isUserLogged()) {
        LRR.toast({
            heading: I18N.LoginRequired(new LRR.ApiURL("/login")),
            icon: "warning",
            hideAfter: 5000,
        });
        return;
    }

    if (state.isBookmarked.value) {
        // Remove from category
        Server.removeArchiveFromCategory(state.id, localStorage.getItem("bookmarkCategoryId"))
            .then(() => {
                state.isBookmarked.value = false;
            });
        removeCategoryBadge(localStorage.getItem("bookmarkCategoryId"));
    } else {
        // Add to category
        Server.addArchiveToCategory(state.id, localStorage.getItem("bookmarkCategoryId"))
            .then(() => {
                state.isBookmarked.value = true;
            });
        addCategoryBadge(localStorage.getItem("bookmarkCategoryId"));
    }
}

// dynamically add bookmark icon if bookmark link is configured.
function loadBookmarkStatus() {
    Server.loadBookmarkCategoryId().then(
        category_id => {
            if (!LRR.bookmarkLinkConfigured()) {
                return;
            }
            fetch(new LRR.ApiURL(`/api/categories/${category_id}`))
                .then(response => response.json()).then(categoryData => {
                    state.isBookmarked.value = categoryData.archives.includes(state.id);
                });
        }
    );
}

function updateMetadata() {
    const img = $("#img")[0];
    const imgDoublePage = $("#img_doublepage")[0];

    if (!state.filename.peek() && state.showingSinglePage.value) {
        state.currentPageLoaded = true;
        $("#i3").removeClass("loading");
        return;
    }

    const width = img.naturalWidth;
    const height = img.naturalHeight;
    const widthDoublePage = imgDoublePage.naturalWidth;
    const heightDoublePage = imgDoublePage.naturalHeight;

    let size = state.preloadedSizes[state.currentPage.value];
    if (!size) {
        size = LRR.getImgSize(state.pages.value[state.currentPage.value]);
        state.preloadedSizes[state.currentPage.value] = size;
    }
    batch(() => {
        state.width.value = width;
        state.height.value = height;
        state.size.value = size;
    });

    if (!state.showingSinglePage.value) {
        let sizePre = state.preloadedSizes[state.currentPage.value + 1];

        if (!sizePre) {
            sizePre = LRR.getImgSize(state.pages.value[state.currentPage.value + 1]);
            state.preloadedSizes[state.currentPage.value + 1] = sizePre;
        }

        batch(() => {
            state.width2.value = widthDoublePage;
            state.height2.value = heightDoublePage;
            state.size2.value = sizePre;
        });
    }

    state.currentPageLoaded = true;
    $("#i3").removeClass("loading");
}

export async function refreshCurrentPage() {
    if (state.infiniteScroll.value) {
        return;
    }
    if (state.maxPage.value < 0) {
        // Not yet loaded, NOOP
        return;
    }

    if (state.doublePageMode.value && state.currentPage.value > 0
        && state.currentPage.value < state.maxPage.value) {

        // Special case when going backwards and already showing a widespread, 
        // we need to go back by two pages to show the previous double-page spread
        if (state.showingSinglePage.value && state.previousPage > state.currentPage.value)
            state.currentPage.value = Math.max(0, state.currentPage.value - 1);
        // Composite an image and use that as the source
        const img1 = await loadImage(state.currentPage.value);
        const img1Filename = getFilename(state.currentPage.value);
        const img2 = await loadImage(state.currentPage.value + 1);
        const img2Filename = getFilename(state.currentPage.value + 1);
        const img1Size = await getImageSize(img1);
        const img2Size = await getImageSize(img2);
        // If w > h on one of the images(widespread), set canvasdata to the first(or second) image only
        if (img1Size.width > img1Size.height || img2Size.width > img2Size.height) {
            // Depending on whether we were going forward or backward, display img1 or img2
            const wideSrc = state.previousPage > state.currentPage.value ? img2 : img1;
            const wideFilename = state.previousPage > state.currentPage.value ? img2Filename : img1Filename;
            $("#img")
                .attr("src", wideSrc);
            $("#img_doublepage")
                .attr("src", "");
            batch(() => {
                state.filename.value = wideFilename;
                state.filenameDoublePage.value = "";
                state.showingSinglePage.value = true;
            });
            // Adjust currentPage to the page of the image being displayed (don't jump by 2 anymore)
            state.currentPage.value = state.previousPage > state.currentPage.value ? state.currentPage.value + 1 : state.currentPage.value;
        } else {
            if (state.mangaMode.value) {
                $("#img")
                    .attr("src", img2);
                $("#img_doublepage")
                    .attr("src", img1);
                batch(() => {
                    state.filename.value = img2Filename;
                    state.filenameDoublePage.value = img1Filename;
                    state.showingSinglePage.value = false;
                });
            } else {
                $("#img")
                    .attr("src", img1);
                $("#img_doublepage")
                    .attr("src", img2);
                batch(() => {
                    state.filename.value = img1Filename;
                    state.filenameDoublePage.value = img2Filename;
                    state.showingSinglePage.value = false;
                });
            }
        }
    } else {
        const img = await loadImage(state.currentPage.value);
        const imgFilename = getFilename(state.currentPage.value);
        $("#img")
            .attr("src", img);
        $("#img_doublepage")
            .attr("src", "");
        batch(() => {
            state.filename.value = imgFilename;
            state.filenameDoublePage.value = "";
            state.showingSinglePage.value = true;
        });
    }
}

export async function goToPage(page) {
    if (state.maxPage.value < 0) {
        // Not yet loaded, NOOP
        return;
    }

    const requestedPage = Math.min(state.maxPage.value, Math.max(0, +page));
    if (requestedPage === state.currentPage.peek()) {
        // No change, do nothing
        return;
    }

    state.previousPage = state.currentPage.value;
    state.setCurrentPage(requestedPage);

    if (state.infiniteScroll.value) {
        $("#display img").get(state.currentPage.value).scrollIntoView({ block: "nearest" });
        state.showingSinglePage.value = false;
    } else {
        preloadImages();
        applyContainerWidth();

        state.currentPageLoaded = false;
        // display overlay if it takes too long to load a page
        setTimeout(() => {
            if (!state.currentPageLoaded) { $("#i3").addClass("loading"); }
        }, 500);

        // update full image link
        $("#imgLink").attr("href", state.pages.value[state.currentPage.value]);

        // scroll to top
        window.scrollTo(0, 0);
    }

    updateArchiveOverlay();
    updateProgress();
}

function updateProgress() {
    // Clear markers
    let page = state.currentPage.value + 1; // progress is 1-indexed

    // Send an API request to update progress on the server
    if (state.authenticateProgress && LRR.isUserLogged()) {
        Server.updateServerSideProgress(state.id, page);
    } else if (state.trackProgressLocally) {
        localStorage.setItem(`${state.id}-reader`, page);
    } else if (!state.authenticateProgress) {
        Server.updateServerSideProgress(state.id, page);
    }
    
    updateStamps(page);
}

function preloadImages() {
    let preloadNext = state.preloadCount.value;
    let preloadPrev = state.preloadCount.value == 0 ? 0 : 1;

    if (state.doublePageMode.value) { preloadNext *= 2; preloadPrev *= 2; }

    for (let i = 1; i <= preloadNext; i++) {
        if (state.currentPage.value + i > state.maxPage.value) { break; }
        loadImage(state.currentPage.value + i);
    }
    for (let i = 1; i <= preloadPrev; i++) {
        if (state.currentPage.value - i < 0) { break; }
        loadImage(state.currentPage.value - i);
    }
}

const fetchPromiseMap = new Map();

/**
 * Utility function for preventing multiple simultaneous fetches to a single resource
 * @param key
 * @param fetcher
 * @returns {any}
 */
function fetchOnce(key, fetcher) {
    if (!fetchPromiseMap.has(key)) {
        const promise = fetcher().finally(() => fetchPromiseMap.delete(key));
        fetchPromiseMap.set(key, promise);
    }
    return fetchPromiseMap.get(key);
}

async function loadImage(index) {
    const src = state.pages.value[index];

    if (!state.preloadedImg[src]) {
        const {  size, blob } = await fetchOnce(src, async () => {
            const res = await fetch(src);
            const size = parseInt(res.headers.get("Content-Length") / 1024, 10);
            const blob = await res.blob();
            return { size, blob };
        });
        state.preloadedSizes[index] = size;
        state.preloadedImg[src] = URL.createObjectURL(blob);
    }

    return state.preloadedImg[src];
}

export function applyContainerWidth() {
    $(".reader-image, .sni").attr("style", "");

    // If we are in fullscreen don't apply anything
    if (inFullscreen())
        return;

    if (state.fitMode.value === "fit-height") {
        // Fit to height forces the image to 90% of visible screen height.
        // If the header is hidden, or if we're in infinite scrolling, then the image
        // can take up to 98% of visible screen height because there's more free space
        const height = localStorage.hideHeader === "true" || state.infiniteScroll.value ? 98 : 90;
        $(".reader-image").attr("style", `max-height: ${height}vh;`);
        $(".sni").attr("style", "width: fit-content; width: -moz-fit-content");
    } else if (state.fitMode.value === "fit-width") {
        $(".reader-image").attr("style", "width: 100%;");
        $(".sni").attr("style", "max-width: 98%");
    } else if (state.containerWidth.value) {
        // If the user defined a custom width, then we can fall back to that one
        $(".sni").attr("style", `max-width: ${state.containerWidth.value}`);
        $(".reader-image").attr("style", "width: 100%");
    } else if (!state.showingSinglePage.value) {
        // Otherwise, if we are showing two pages we can override the default width
        $(".sni").attr("style", "max-width: 90%");
    } else {
        // Finally, fall back to 1200px width if none of the above matches
        $(".sni").attr("style", "max-width: 1200px");
    }

    renderMarkers();
}

export function toggleMangaMode() {
    if (state.infiniteScroll.value) { return false; }
    state.mangaMode.value = !state.mangaMode.value;
    return false;
}

function startAutoNextPage() {
    state.autoNextPageCountdown.value = Math.trunc(state.AutoNextPageInterval.value);
    if (state.autoNextPageCountdown.value <= 0) {
        LRR.toast({
            heading: I18N.AutoNextPageFailHeader,
            text: I18N.AutoNextPageFailBody,
            icon: "error",
            hideAfter: 5000,
        });
        return;
    }

    state.autoNextPage.value = true;

    state.autoNextPageCountdownTaskId = setInterval(() => {
        if (state.autoNextPageCountdown.value <= 0) {
            clearInterval(state.autoNextPageCountdownTaskId);

            const atLastPage = state.mangaMode.value ? state.currentPage.value === 0 : state.currentPage.value === state.maxPage.value;

            if (atLastPage) {
                // At archive boundary: attempt cross-archive navigation.
                // readNextArchive/readPreviousArchive persists slideshow state
                // to sessionStorage; loadImages on the new page resumes it.
                if (state.archiveIds.length > 0) {
                    if (state.mangaMode.value)
                        readPreviousArchive();
                    else
                        readNextArchive();
                }
                stopAutoNextPage();
            } else {
                if (state.mangaMode.value)
                    changePage(-1);
                else
                    changePage(1);
                startAutoNextPage();
            }
            return;
        }
        state.autoNextPageCountdown.value -= 1;
    }, 1000);

    requestWakeLock();
}

export function stopAutoNextPage() {
    state.autoNextPage.value = false;
    clearInterval(state.autoNextPageCountdownTaskId);
    state.autoNextPageCountdown.value = 0;

    releaseWakeLock();
}

export function toggleAutoNextPage() {
    state.autoNextPage.value ? stopAutoNextPage() : startAutoNextPage();
    return false; // prevent scrolling to top
}

export function toggleFullScreen() {
    if (inFullscreen()) {
        // if already full screen; exit
        fscreen.exitFullscreen();
    } else {
        // else go fullscreen
        // ensure in every case, the correct fullscreen element is binded.
        fscreen.requestFullscreen($("div#i3").get(0));
    }
}

function handleFullScreen(enableFullscreen = false) {
    if (inFullscreen() || enableFullscreen === true) {
        if (state.markersVisible.value) {
            clearMarkers();
        }
        if ($("body").hasClass("infinite-scroll")) {
            $("div#i3").addClass("fullscreen-infinite");
        } else {
            $("div#i3").addClass("fullscreen");
        }
    } else {
        renderMarkers();
        if ($("body").hasClass("infinite-scroll")) {
            $("div#i3").removeClass("fullscreen-infinite");
        } else {
            $("div#i3").removeClass("fullscreen");
        }
    }
    applyContainerWidth();
}

export function getCurrentChapter() {
    return findChapterForPage(state.currentPage.value + 1, state.content.value.chapters);
}

// Find the current chapter (or nested sub-chapter) for the given page.
function findChapterForPage(page, chapters) {
    if (!chapters) return null;

    for (const chapter of chapters) {
        if (page >= chapter.startPage && page <= chapter.endPage) {
            // Check if there's a more specific nested chapter
            if (chapter.chapters && chapter.chapters.length > 0) {
                const nested = findChapterForPage(page, chapter.chapters);
                if (nested) return nested;
            }
            return chapter;
        }
    }
    return null;
}

function generateThumbnails() {

    // Function to evaluate Minion job progress and update thumbnails as they are generated
    const thumbProgress = function (notes) {
        if (notes.total_pages === undefined || notes.id === undefined) { return; }

        // Look at all the numbered keys in notes, aka notes.1, notes.2..
        for (let i = 1; i <= notes.total_pages; i++) {
            if (Object.hasOwn(notes, i) && notes[i] === "processed") {

                const startPage = state.id.startsWith("TANK_") ?
                    state.content.value.chapters.find(ch => ch.id === notes.id).startPage :
                    1;

                const index = startPage + i - 2; // 0-based global
                state.pageThumbnails.push(index);

                // Live-update the page thumbnail in the overlay if it's visible
                if ($(`#${index}_spinner`).attr("loaded") !== "true") {
                    // Set image source to the thumbnail
                    const thumbnailUrl = new LRR.ApiURL(`/api/archives/${notes.id}/thumbnail?page=${i}&cachebust=${Date.now()}`);
                    $(`#${index}_thumb`).attr("src", thumbnailUrl);
                    $(`#${index}_spinner`).attr("loaded", true);
                    $(`#${index}_spinner`).hide();
                }
            }
        }
    };

    const fetchThumbsForArc = function(arc) {
        fetch(new LRR.ApiURL(`/api/archives/${arc.id}/files/thumbnails`), {
            method: "POST",
        })
            .then(response => {
                if (response.status === 200) {
                    // Thumbnails are already generated, there's nothing to do. Very nice!
                    for (let idx = arc.startPage - 1; idx < arc.endPage; idx++) {
                        state.pageThumbnails.push(idx);
                    }
                    $(".ttspinner").hide();
                    return;
                }
                if (response.status === 202) {
                    // Check status and update progress
                    response.json().then((data) => Server.checkJobStatus(
                        data.job,
                        false,
                        (data) => thumbProgress(data.notes), // call progress callback one last time to ensure all thumbs are loaded
                        () => LRR.showErrorToast(I18N.ThumbJobError),
                        thumbProgress,
                    ));
                }
            });
    };

    if (state.id.startsWith("TANK_"))
        state.content.value.chapters.forEach(arc => fetchThumbsForArc(arc)); // Generate thumbnails per archive
    else
        fetchThumbsForArc({
            id: state.id,
            startPage: 1,
            endPage: state.content.value.pages,
        }); // Queue a single minion job for thumbnails
}

/**
 * Change current page in reader.
 * 
 * @param {(-1|1|"first"|"last"|"outermost-left"|"outermost-right")} targetPage    One of -1 (previous), 1 (next), "first", or "last" page.
 * @param {boolean} resetAuto                   Whether to reset current slideshow counter.
 */
export function changePage(targetPage, resetAuto = false) {

    // Reset timer if user manually changes pages during slideshow
    if (resetAuto && state.autoNextPage.value) {
        state.autoNextPageCountdown.value = Math.trunc(state.AutoNextPageInterval.value);
    }

    // Sync position if in infinite scroll mode
    if (state.infiniteScroll.value) {
        const images = [...document.querySelectorAll(".reader-image:not(#img_doublepage)")];
        const midViewport = window.innerHeight / 2;
        for (let i = 0; i < images.length; i++) {
            const rect = images[i].getBoundingClientRect();
            if (rect.top <= midViewport && rect.bottom >= midViewport) {
                state.setCurrentPage(i);
                break;
            }
        }
    }

    if (targetPage === "outermost-left") {
        return state.mangaMode.value ? readNextArchive() : readPreviousArchive();
    } else if (targetPage === "outermost-right") {
        return state.mangaMode.value ? readPreviousArchive() : readNextArchive();
    }

    let destination;
    if (targetPage === "first") {
        destination = state.mangaMode.value ? state.maxPage.value : 0;
    } else if (targetPage === "last") {
        destination = state.mangaMode.value ? 0 : state.maxPage.value;
    } else {
        let offset = targetPage;
        // Double the offset to move by 2 pages at once, unless we're currently showing a widespread
        if (state.doublePageMode.value && !state.showingSinglePage.value && state.currentPage.value > 0) {
            offset *= 2;
        }
        destination = state.currentPage.peek() + (state.mangaMode.value ? -offset : offset);
    }
    if (destination < 0) {
        // Clamp if we're not at the first page, to avoid doublepage mode accidentally yeeting us to previous archive
        if (state.currentPage > 0) {
            destination = 0;
        } else {
            return readPreviousArchive();
        }
    } else if (destination > state.maxPage) {
        // Ditto for last page
        if (state.currentPage < state.maxPage) {
            destination = state.maxPage;
        } else {
            return readNextArchive();
        }
    }
    return goToPage(destination);
}

function getFilename(index) {
    return new URLSearchParams(state.pages.value[index].split("?")[1]).get("path");
}

function getImageSize(url) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => {
            resolve({
                width: img.naturalWidth,
                height: img.naturalHeight,
            });
        };
        img.onerror = (err) => {
            reject(err);
        };
        img.src = url;
    });
}

/**
 * Determine if current page qualifies for, and sets up, archive navigation state.
 * While in reader mode, navigation state is only supported if user enters reader from index datatables,
 * or if user is already in reader mode with navigation support and switches to a different archive via
 * readNextArchive() or readPreviousArchive().
 *
 * If users enters from carousel or by pasting URL, navigation is not supported.
 *
 * @returns {Promise<boolean>} - whether archive navigation state was set up
 */
async function setupArchiveNavigation() {
    const navigationState = sessionStorage.getItem("navigationState");
    const currArchiveIdsJson = localStorage.getItem("currArchiveIds");
    const {referrer} = document;
    const isDirectNavigation = !referrer || !referrer.includes(window.location.host);
    if (isDirectNavigation) {
        state.archiveIds = [];
        sessionStorage.removeItem("navigationState");
        return false;
    } else if (navigationState === "datatables" && currArchiveIdsJson) {
        try {
            const ids = JSON.parse(currArchiveIdsJson);
            state.archiveIds = ids;
            state.archiveIndex = ids.indexOf(state.id);
            if (state.archiveIndex !== -1) {
                state.multiArchiveNavigation.value = true;
                if (state.archiveIndex === 0) {
                    const previousArchives = await loadPreviousDatatablesArchives();
                    if (previousArchives) {
                        localStorage.setItem("previousArchiveIds", JSON.stringify(previousArchives));
                    }
                }
                if (state.archiveIndex === ids.length - 1) {
                    const nextArchives = await loadNextDatatablesArchives();
                    if (nextArchives) {
                        localStorage.setItem("nextArchiveIds", JSON.stringify(nextArchives));
                    }
                }
            }
        } catch (error) {
            console.error("Error setting up archive navigation state:", error);
            return false;
        }
    }
    return true;
}

async function loadPreviousDatatablesArchives() {
    if (localStorage.getItem("previousArchiveIds")) {
        return JSON.parse(localStorage.getItem("previousArchiveIds"));
    }
    const currentDTPage = parseInt(localStorage.getItem("currDatatablesPage") || "1", 10);
    if (currentDTPage <= 1) return null;
    return loadDatatablesArchives(currentDTPage - 1);
}

async function loadNextDatatablesArchives() {
    if (localStorage.getItem("nextArchiveIds")) {
        return JSON.parse(localStorage.getItem("nextArchiveIds"));
    }
    const currentDTPage = parseInt(localStorage.getItem("currDatatablesPage") || "1", 10);
    return loadDatatablesArchives(currentDTPage + 1);
}

function readPreviousArchive() {
    if (inFullscreen()) {
        console.warn("[previous] Archive navigation not supported in fullscreen mode.");
        return;
    }
    if (state.archiveIds.length > 0) {
        let previousArchiveId;
        if (state.archiveIndex === 0) {
            const previousArchiveIdsJson = localStorage.getItem("previousArchiveIds");
            const currArchiveIdsJson = localStorage.getItem("currArchiveIds");
            if (previousArchiveIdsJson && currArchiveIdsJson) {
                const previousArchiveIds = JSON.parse(previousArchiveIdsJson);
                localStorage.removeItem("previousArchiveIds");
                localStorage.setItem("currArchiveIds", previousArchiveIdsJson);
                localStorage.setItem("nextArchiveIds", currArchiveIdsJson);
                previousArchiveId = previousArchiveIds[previousArchiveIds.length - 1];
                const currentDTPage = parseInt(localStorage.getItem("currDatatablesPage") || "1", 10);
                localStorage.setItem("currDatatablesPage", currentDTPage - 1);
            } else {
                LRR.toast({ text: I18N.ReaderFirstArchive });
                return;
            }
        } else {
            previousArchiveId = state.archiveIds[state.archiveIndex - 1];
        }
        if (state.autoNextPage.value) {
            sessionStorage.setItem("autoNextPage", "true");
        }
        const newUrl = new LRR.ApiURL(`/reader?id=${previousArchiveId}`).toString();
        window.location.replace(newUrl);
    } else {
        LRR.toast({ text: I18N.ReaderFirstArchive });
    }
}

function readNextArchive() {
    if (inFullscreen()) {
        console.warn("[next] Archive navigation not supported in fullscreen mode.");
        return;
    }
    if (state.archiveIds.length > 0) {
        let nextArchiveId;
        if (state.archiveIndex === state.archiveIds.length - 1) {
            const nextArchiveIdsJson = localStorage.getItem("nextArchiveIds");
            const currArchiveIdsJson = localStorage.getItem("currArchiveIds");
            if (nextArchiveIdsJson && currArchiveIdsJson) {
                const nextArchiveIds = JSON.parse(nextArchiveIdsJson);
                localStorage.removeItem("nextArchiveIds");
                localStorage.setItem("currArchiveIds", nextArchiveIdsJson);
                localStorage.setItem("previousArchiveIds", currArchiveIdsJson);
                nextArchiveId = nextArchiveIds[0];
                const currentDTPage = parseInt(localStorage.getItem("currDatatablesPage") || "1", 10);
                localStorage.setItem("currDatatablesPage", currentDTPage + 1);
            } else {
                LRR.toast({ text: I18N.ReaderLastArchive });
                return;
            }
        } else {
            nextArchiveId = state.archiveIds[state.archiveIndex + 1];
        }
        if (state.autoNextPage.value) {
            sessionStorage.setItem("autoNextPage", "true");
        }
        const newUrl = new LRR.ApiURL(`/reader?id=${nextArchiveId}`).toString();
        window.location.replace(newUrl);
    } else {
        LRR.toast({ text: I18N.ReaderLastArchive });
    }
}

/**
 * Loads the archives for the given datatables page so the Reader can navigate
 * between archives across DT page boundaries without re-rendering the index.
 * TODO: given this can drift from how index builds DT search requests we might
 * want to consolidate.
 *
 * @param {number} datatablesPage - The page number to load.
 * @returns {Promise<Array<string>|null>} - The list of archive IDs, or null on error
 */
async function loadDatatablesArchives(datatablesPage) {
    const indexSearchQuery = localStorage.getItem("currentSearch") || "";
    const indexSelectedCategory = localStorage.getItem("selectedCategory") || "";
    const datatablesPageSize = parseInt(localStorage.getItem("datatablesPageSize") || "100", 10);
    const indexSort = localStorage.getItem("indexSort") || "title";
    const indexOrder = localStorage.getItem("indexOrder") || "asc";
    let searchUrlStr = `/api/search/ids?start=${(datatablesPage - 1) * datatablesPageSize}`;
    if (indexSearchQuery) searchUrlStr += `&filter=${encodeURIComponent(indexSearchQuery)}`;
    
    // See Index.updateCarousel
    if (indexSelectedCategory === "NEW_ONLY") {
        searchUrlStr += `&newonly=true`;
    } else if (indexSelectedCategory === "UNTAGGED_ONLY") {
        searchUrlStr += `&untaggedonly=true`;
    } else if (indexSelectedCategory) {
        searchUrlStr += `&category=${encodeURIComponent(indexSelectedCategory)}`;
    }
    if (indexSort && indexSort !== "title") {
        searchUrlStr += `&sortby=${encodeURIComponent(indexSort)}`;
        searchUrlStr += `&order=${indexOrder}`;
    }

    // Carry over the index tank-grouping and hide-completed settings so the prefetched
    // neighbor page matches the lineup the user is viewing.
    if (localStorage.getItem("grouptanks") === "false") searchUrlStr += `&groupby_tanks=false`;
    if (localStorage.getItem("hidecompleted") === "true") searchUrlStr += `&hidecompleted=true`;

    const searchUrl = new LRR.ApiURL(searchUrlStr);

    try {
        const response = await fetch(searchUrl.toString(), {
            method: "GET",
            headers: { Accept: "application/json" },
        });
        if (!response.ok) {
            console.error("Failed to fetch archive list:", response.status, response.statusText);
            return null;
        }
        const data = await response.json();
        if (data && data.data && data.data.length > 0) {
            return data.data;
        }
        return null;
    } catch (error) {
        console.error("Failed to fetch archive list:", error);
        return null;
    }
}

/**
 * Return to the index page with state preservation. Navigates to the DT page,
 * search filter, category, and sort order that were active when the user
 * entered reader mode, updated by any cross-DT archive navigation.
 */
function returnToIndex() {
    const indexSearchQuery = localStorage.getItem("currentSearch") || "";
    const indexSelectedCategory = localStorage.getItem("selectedCategory") || "";
    const indexSort = localStorage.getItem("indexSort") || "title";
    const indexOrder = localStorage.getItem("indexOrder") || "asc";
    const currentDTPage = localStorage.getItem("currDatatablesPage") || "1";
    let returnUrl = "/";
    const params = new URLSearchParams();
    if (indexSearchQuery) params.append("q", indexSearchQuery);
    if (indexSelectedCategory) params.append("c", indexSelectedCategory);
    // indexSort is the column's tag-namespace name (sName); the index reads ?sort= by name,
    // so pass it straight through. Title is the default and is omitted, matching buildURLParameters.
    if (indexSort && indexSort !== "title") {
        params.append("sort", indexSort);
    }
    if (indexOrder !== "asc") params.append("sortdir", indexOrder);
    if (currentDTPage !== "1") params.append("p", currentDTPage);
    const queryString = params.toString();
    if (queryString) {
        returnUrl += "?" + queryString;
    }
    window.location.href = new LRR.ApiURL(returnUrl).toString();
}

/**
 * Toggles the visibility of the base-overlay div that's in the given selector.
 * @param {string} selector
 * @returns {boolean}
 */
export function toggleOverlay(selector) {
    updateArchiveOverlay();
    const overlay = $(selector);
    overlay.is(":visible")
        ? LRR.closeOverlay()
        : $("#overlay-shade").fadeTo(150, 0.6, () => overlay.show());

    return false; // needs to return false to prevent scrolling to top
}

async function requestWakeLock() {
    if (state.wakeLock !== null) {
        return;
    }
    if (!("wakeLock" in navigator)) {
        console.warn("Wake Lock API is not available. You're likely running in an outdated browser or without HTTPS.");
        return;
    }

    try {
        state.wakeLock = await navigator.wakeLock.request();

        state.wakeLock.addEventListener("release", () => {
            state.wakeLock = null;
        });
    } catch (err) {
        console.warn("Error acquiring wake lock:", err);
    }
}

function releaseWakeLock() {
    if (state.wakeLock !== null) {
        state.wakeLock.release();
    }
}

function toggleDoublePageMode() {
    state.doublePageMode.value = !state.doublePageMode.value;
}
