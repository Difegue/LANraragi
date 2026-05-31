/**
 * Reader main entrypoint and shared functionality.
 */
import * as Server from "./server.js";
import * as LRR from "./common.js";
import I18N from "i18n";
import fscreen from "fscreen";
import { initializeStamps, updateStamps, renderMarkers, clearMarkers } from "./reader_stamps.js";
import { initializeArchiveOverlay, toggleArchiveOverlay, updateArchiveOverlay, removeCategoryBadge } from "./reader_archive_overlay.js";
import { initializeSettings, toggleSettingsOverlay, toggleMangaMode, toggleDoublePageMode } from "./reader_options.js";

export let state = {
    id: "",
    force: false,
    previousPage: -1,
    currentPage: -1,
    currentChapter: null,
    showingSinglePage: true,
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
    autoNextPage: false,
    autoNextPageCountdownTaskId: undefined,
    autoNextPageCountdown: 0,
    trackProgressLocally: null,
    authenticateProgress: null,
    containerWidth: null,
    content: undefined,
    pages: [],
    maxPage: -1,
    mangaMode: false,
    doublePageMode: false,
    ignoreProgress: false,
    infiniteScroll: false,
    fitMode: undefined,
    currentPageLoaded: false,
    progress: undefined,
    showOverlayByDefault: false,
    preloadCount: 1,
    AutoNextPageInterval: 0,
    markerMode: false,
    markersVisible: false,
    markers: [],
    overlayFiltered: false,
    pageNaviState: true,
    wakeLock: null,
};

export async function initializeAll(trackProgressLocally, authenticateProgress) {
    state.trackProgressLocally = trackProgressLocally;
    state.authenticateProgress = authenticateProgress;

    initializeSettings();
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

    $(document).on("click.pagination-change-pages", ".page-link", handlePaginator);

    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.toggle-full-screen", "#toggle-full-screen", (e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleFullScreen();
    });
    $(document).on("click.toggle-auto-next-page", ".toggle-auto-next-page", toggleAutoNextPage);
    $(document).on("click.toggle-help", "#toggle-help", toggleHelp);
    $(document).on("click.toggle-bookmark", ".toggle-bookmark", toggleBookmark);
    $(document).on("click.regenerate-archive-cache", "#regenerate-cache", () => {
        window.location.href = new LRR.ApiURL(`/reader?id=${state.id}&force_reload`);
    });

    // Return to index, re-applying the search/page state the user came from
    $(document).on("click.return-to-index", "#return-to-index", () => {
        returnToIndex();
    });

    // Apply full-screen utility
    // F11 Fullscreen is totally another "Fullscreen", so its support is beyong consideration.
    // Small override function, always returns boolean
    fscreen.inFullscreen = () => !!fscreen.fullscreenElement;
    if (!fscreen.fullscreenEnabled) {
        // Fullscreen mode is unsupported; use attribute selector to hide all instances
        $("[id='toggle-full-screen']").hide();
    }

    // Infer initial information from the URL
    const params = new URLSearchParams(window.location.search);
    state.id = params.get("id");
    state.force = params.get("force_reload") !== null;
    state.currentPage = (+params.get("p") || 1) - 1;

    // Set up archive navigation state from the entry source (datatables vs carousel vs direct nav)
    await setupArchiveNavigation();

    // Remove the "new" tag with an api call (archives only; tanks don't have an isnew flag)
    if (!state.id.startsWith("TANK_"))
        Server.callAPI(`/api/archives/${state.id}/isnew`, "DELETE", null, I18N.ReaderErrorClearingNew, null);

    // Load metadata for the requested ID and populate the page
    loadContentData().then(() => {
      
        document.title = state.content.title;
        $(".max-page").text(state.content.pages);

        // Regex look in tags for artist
        const artist = state.content.tags.match(/artist:([^,]+)(?:,|$)/i);
        if (artist) {
            const artistName = artist[1];
            const artistSearchUrl = `/?sort=0&q=artist%3A${encodeURIComponent(artistName)}%24&`;
            const link = $("<a></a>")
                .attr("href", artistSearchUrl)
                .text(artistName);
            const titleContainer = $("<span></span>")
                .text(`${state.content.title} by `)
                .append(link);
            $("#archive-title").empty().append(titleContainer);
            $("#archive-title-overlay").empty().append(titleContainer.clone());
        } else {
            $("#archive-title").text(state.content.title);
            $("#archive-title-overlay").text(state.content.title);
        }

        $("#tagContainer").append(LRR.buildTagsDiv(state.content.tags));

        const ratyEl = document.querySelector(`[data-raty]`);
        if (ratyEl) {
            const rating = LRR.splitTagsByNamespace(state.content.tags).rating?.at(0).length;
            new Raty(ratyEl, {
                starType: `i`,
                cancelButton: true,
                cancelClass: `fas fa-trash raty-cancel`,
                cancelHint: I18N.ReaderClearRating,
                cancelPlace: `right`,
                score: rating,
                click: function(score, element, evt) {

                    let tags = LRR.splitTagsByNamespace(state.content.tags);
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
        $(".archive-summary").text(state.content.summary);

        // Get the chapter for the current page (if any)
        state.currentChapter = getCurrentChapter();

        // Load the actual reader pages now that we have basic info
        loadImages();
    });

    // Fetch "bookmark" category ID and setup icon
    loadBookmarkStatus();
}

export function loadContentData() {

    // Initialize content object to hold metadata -- This is a recursive object that will be used to build the page overlay.
    // (For tanks, content.chapters will hold archive chapters that can themselves contain nested chapters from ToCs)
    state.content = {
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
                state.content.title   = tank.name;
                state.content.tags    = tank.tags    || "";
                state.content.summary = tank.summary || "";

                state.content.chapters = [];

                // full_data contains pre-fetched metadata for every archive in order
                const fullData = tank.full_data || [];
                // Cumulative offset as we iterate through the arclist
                let pageOffset = 0;

                fullData.forEach(meta => {
                    if (!meta) return;

                    // Create archive chapter (with nested ToC chapters if present)
                    const archiveChapters = LRR.buildTankChapters(meta, pageOffset);
                    state.content.chapters.push(...archiveChapters);

                    pageOffset += meta.pagecount || 0;
                });

                state.content.pages = pageOffset;
                updateProgress(tank, state.id);
            })
            .catch(err => LRR.showErrorToast(I18N.ServerInfoError, err));
    }

    return Server.callAPI(`/api/archives/${state.id}/metadata`, "GET", null, I18N.ServerInfoError,
        (data) => {
            state.content.title = data.title;
            state.content.pages = data.pagecount;
            state.content.tags = data.tags;
            state.content.summary = data.summary;

            updateProgress(data, state.id);

            if (data.toc) 
                state.content.chapters = LRR.buildArchiveChapters(data.toc, state.id, data.pagecount);

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
        const arc = state.content.chapters.find(a => globalPage >= a.startPage && globalPage <= a.endPage);
        if (arc)
            return { arcId: arc.id, localPage: globalPage - arc.startPage + 1 };
    }
    return { arcId: state.id, localPage: globalPage };
}

/**
 * Adds a removable category flag to the categories section within archive overview.
 */
export function addCategoryBadge(categoryId) {
    const categoryName = $(`#category option[value="${categoryId}"]`).text();
    const url = new LRR.ApiURL(`/?c=${categoryId}`);
    const html = `<div class="gt" style="font-size:14px; padding:4px">
        <a href="${url}">
        <span class="label">${LRR.encodeHTML(categoryName)}</span>
        <a href="#" class="remove-category" data-id="${categoryId}"
            style="margin-left:4px; margin-right:2px">×</a>
    </a>`;
    $("#archive-categories").append(html);
}

export function loadImages() {

    const onLoad = (data) => {
        state.pages = data;
        state.maxPage = state.pages.length - 1;
        $(".max-page").html(state.pages.length);

        // Choices in order for page picking:
        // * p is in parameters and is not the first page
        // * progress is tracked and is not the last page
        // * first page
        // This allows for bookmarks to trump progress
        // when there's no parameter, null is coerced to 0 so it becomes -1
        state.currentPage = state.currentPage || (
            !state.ignoreProgress && state.progress < state.maxPage
                ? state.progress
                : 0
        );

        if (state.infiniteScroll) {
            initInfiniteScrollView();
            if (state.content.tags?.includes("webtoon")) {
                $("head").append(`
                    <style id="webtoon-css">
                        .reader-image {
                            margin-bottom: 0 !important;
                            margin-top: 0 !important;
                        }
                    </style>
                `);
            }
        } else {
            $("#img").on("load", updateMetadata);

            // when click left or right img area change page
            $(document).on("click", (event) => {
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

            $(".current-page").each((_i, el) => $(el).html(state.currentPage + 1));
            goToPage(state.currentPage);
        }

        if (state.showOverlayByDefault) { toggleArchiveOverlay(); }

        // Resume slideshow if it was active before cross-archive navigation
        if (sessionStorage.getItem("autoNextPage") === "true") {
            sessionStorage.removeItem("autoNextPage");
            startAutoNextPage();
        }
    };

    const onFinally = () => {
        if (state.pages === undefined) {
            $("#img").attr("src", new LRR.ApiURL("/img/flubbed.gif").toString());
            $("#display").append(`<h2>${I18N.ReaderArchiveError}</h2>`);
        }
        generateThumbnails();
    };

    if (state.id.startsWith("TANK_")) {
        // For tanks: fetch pages for each archive and concatenate them
        Promise.all(
            state.content.chapters.map(arc =>
                fetch(new LRR.ApiURL(`/api/archives/${arc.id}/files?force=${state.force}`))
                    .then(r => r.ok ? r.json() : Promise.reject())
            )
        ).then(results => {
            onLoad(results.flatMap(r => r.pages));
        }).catch(() => LRR.showErrorToast(I18N.ReaderArchiveError))
            .finally(onFinally);
    }
    else {
        Server.callAPI(`/api/archives/${state.id}/files?force=${state.force}`, "GET", null, I18N.ReaderArchiveError,
            (data) => onLoad(data.pages),
        ).finally(onFinally);
    }
}

function initFullscreen() {
    // Apply full-screen utility
    // F11 Fullscreen is totally another "Fullscreen", so its support is beyond consideration.
    // Small override function, always returns boolean
    fscreen.inFullscreen = () => !!fscreen.fullscreenElement;
    if (!fscreen.fullscreenEnabled) {
        // Fullscreen mode is unsupported; use attribute selector to hide all instances
        $("[id='toggle-full-screen']").hide();
    }

    fscreen.onfullscreenchange = () => handleFullScreen(fscreen.fullscreenElement !== null);
}

function initInfiniteScrollView() {
    $("body").addClass("infinite-scroll");
    $("#Map").remove();
    $("#img_doublepage").remove();
    $(".reader-image").first().attr("src", state.pages[0]);

    // Disable other options that don't work with infinite scroll
    state.mangaMode = false;
    state.doublePageMode = false;

    // Create an observer to update progress when a new page is scrolled in
    let allImagesLoaded = false;
    const observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && allImagesLoaded) {
            // Find the entry in the list of images
            const index = entries[0].target.id.replace("page-", "");
            // Convert to int
            const page = parseInt(index, 10);
            // Avoid double progress updates
            if (state.currentPage !== page) {
                state.currentPage = page;
                updateProgress();
            }
        }
    }, { threshold: 0.5 });

    state.pages.slice(1).forEach((source) => {
        const img = new Image();
        img.id = `page-${state.pages.indexOf(source)}`;
        img.height = 800;
        img.width = 600;
        img.src = source;
        $(img).addClass("reader-image");
        $("#display").append(img);
        observer.observe(img);
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

    // Wait for the pages to load before scrolling to the current page
    const images = $("#display .reader-image");
    let loaded = 0;
    images.on("load", () => {
        loaded += 1;
        if (loaded === images.length) {
            allImagesLoaded = true;
            if (window.scrollY === 0) {
                goToPage(state.currentPage);
            }
        }
    });
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
            toggleBookmark(e);
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
    if ($(".page-overlay").is(":visible") || e.repeat || (state.infiniteScroll && state.content.tags?.includes("webtoon"))) return;

    e.preventDefault();
    // Capture direction now so we dont lose it if shift state changes while held
    let direction = e.shiftKey ? -1 : 1;
    if (state.mangaMode) direction *= -1;
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
    if (fscreen.inFullscreen() && !state.infiniteScroll) {
        let changePageNum = 1;
        if (e.originalEvent.deltaY > 0) changePageNum = -1;
        // In Manga mode, reverse the changePage variable
        // so that we always move forward
        if (!state.mangaMode) changePageNum *= -1;
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

function toggleHelp() {
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

function toggleBookmark(e) {
    e.preventDefault();
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

    if ($(".toggle-bookmark").hasClass("fas fa-bookmark")) {
        // Remove from category
        Server.removeArchiveFromCategory(state.id, localStorage.getItem("bookmarkCategoryId"));
        removeCategoryBadge(localStorage.getItem("bookmarkCategoryId"));
        $(".toggle-bookmark")
            .removeClass("fas fa-bookmark")
            .addClass("far fa-bookmark");
    } else {
        // Add to category
        Server.addArchiveToCategory(state.id, localStorage.getItem("bookmarkCategoryId"));
        addCategoryBadge(localStorage.getItem("bookmarkCategoryId"));
        $(".toggle-bookmark")
            .removeClass("far fa-bookmark")
            .addClass("fas fa-bookmark");
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
                    const isBookmarked = categoryData.archives.includes(state.id);
                    const bookmarkState = isBookmarked ? "fas" : "far";
                    const disabledClass = LRR.isUserLogged() ? "" : " disabled";
                    const leftOptionsList = document.querySelectorAll(".absolute-options.absolute-left");
                    leftOptionsList.forEach(leftOption => {
                        let bookmark = document.createElement("a");
                        bookmark.className = `${bookmarkState} fa-bookmark fa-2x toggle-bookmark${disabledClass}`;
                        bookmark.href = "#";
                        bookmark.title = I18N.ToggleBookmark;
                        if (!LRR.isUserLogged()) {
                            bookmark.setAttribute("style", "opacity: 0.5; cursor: not-allowed;");
                        }
                        leftOption.appendChild(bookmark);
                    });
                });
        }
    );
}

function updateMetadata() {
    const img = $("#img")[0];
    const {filename} = img.dataset;

    const imgDoublePage = $("#img_doublepage")[0];
    const filenameDoublePage = imgDoublePage.dataset.filename;

    if (!filename && state.showingSinglePage) {
        state.currentPageLoaded = true;
        $("#i3").removeClass("loading");
        return;
    }

    const width = img.naturalWidth;
    const height = img.naturalHeight;
    const widthDoublePage = imgDoublePage.naturalWidth;
    const heightDoublePage = imgDoublePage.naturalHeight;
    const widthView = width + widthDoublePage;

    if (state.showingSinglePage) {
        let size = state.preloadedSizes[state.currentPage];
        if (!size) {
            size = LRR.getImgSize(state.pages[state.currentPage]);
            state.preloadedSizes[state.currentPage] = size;
            $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`);
            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB`);
        } else {
            $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`);
            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB`);
        }
    } else {
        let size = state.preloadedSizes[state.currentPage];
        let sizePre = state.preloadedSizes[state.currentPage + 1];

        if (!size || !sizePre) {
            size = LRR.getImgSize(state.pages[state.currentPage]);
            sizePre = LRR.getImgSize(state.pages[state.currentPage + 1]);
            state.preloadedSizes[state.currentPage] = size;
            state.preloadedSizes[state.currentPage + 1] = sizePre;
        }

        const sizeView = size + sizePre;
        $(".file-info").text(`${filename} - ${filenameDoublePage} :: ${widthView} x ${height} :: ${sizeView} KB`);
        $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB - ${filenameDoublePage} :: ${widthDoublePage} x ${heightDoublePage} :: ${sizePre} KB`);
    }

    // Update page numbers in the paginator
    const newVal = state.showingSinglePage
        ? state.currentPage + 1
        : `${state.currentPage + 1} + ${state.currentPage + 2}`;
    $(".current-page").each((_i, el) => $(el).html(newVal));

    state.currentPageLoaded = true;
    $("#i3").removeClass("loading");
}

export async function goToPage(page) {
    state.previousPage = state.currentPage;
    state.currentPage = Math.min(state.maxPage, Math.max(0, +page));

    if (state.infiniteScroll) {
        $("#display img").get(state.currentPage).scrollIntoView({ block: "nearest" });
    } else {
        if (state.doublePageMode && state.currentPage > 0
            && state.currentPage < state.maxPage) {

            // Special case when going backwards and already showing a widespread, 
            // we need to go back by two pages to show the previous double-page spread
            if (state.showingSinglePage && state.previousPage > state.currentPage) 
                state.currentPage = Math.max(0, state.currentPage - 1);
            // Composite an image and use that as the source
            const img1 = await loadImage(state.currentPage);
            const img1Filename = getFilename(state.currentPage);
            const img1Size = await getImageSize(img1);
            const img2 = await loadImage(state.currentPage + 1);
            const img2Filename = getFilename(state.currentPage + 1);
            const img2Size = await getImageSize(img2);
            // If w > h on one of the images(widespread), set canvasdata to the first(or second) image only
            if (img1Size.width > img1Size.height || img2Size.width > img2Size.height) {
                // Depending on whether we were going forward or backward, display img1 or img2
                const wideSrc = state.previousPage > state.currentPage ? img2 : img1;
                const wideFilename = state.previousPage > state.currentPage ? img2Filename : img1Filename;
                $("#img").attr("src", wideSrc);
                $("#img").attr("data-filename", wideFilename);
                $("#display").removeClass("double-mode");
                $("#img_doublepage").attr("src", "");
                $("#img_doublepage").attr("data-filename", "");
                state.showingSinglePage = true;
                // Adjust currentPage to the page of the image being displayed (don't jump by 2 anymore)
                state.currentPage = state.previousPage > state.currentPage ? state.currentPage + 1 : state.currentPage;
            } else {
                $("#display").addClass("double-mode");
                if (state.mangaMode) {
                    $("#img").attr("src", img2);
                    $("#img").attr("data-filename", img2Filename);
                    $("#img_doublepage").attr("src", img1);
                    $("#img_doublepage").attr("data-filename", img1Filename);
                } else {
                    $("#img").attr("src", img1);
                    $("#img").attr("data-filename", img1Filename);
                    $("#img_doublepage").attr("src", img2);
                    $("#img_doublepage").attr("data-filename", img2Filename);
                }
                state.showingSinglePage = false;
            }
        } else {
            const img = await loadImage(state.currentPage);
            const imgFilename = getFilename(state.currentPage);
            $("#img").attr("src", img);
            $("#img").attr("data-filename", imgFilename);
            $("#display").removeClass("double-mode");
            $("#img_doublepage").attr("src", "");
            $("#img_doublepage").attr("data-filename", "");
            state.showingSinglePage = true;
        }

        preloadImages();
        applyContainerWidth();

        state.currentPageLoaded = false;
        // display overlay if it takes too long to load a page
        setTimeout(() => {
            if (!state.currentPageLoaded) { $("#i3").addClass("loading"); }
        }, 500);

        // update full image link
        $("#imgLink").attr("href", state.pages[state.currentPage]);

        // scroll to top
        window.scrollTo(0, 0);
    }

    updateArchiveOverlay();
    updateProgress();
}

function updateProgress() {
    // Clear markers
    let page = state.currentPage + 1; // progress is 1-indexed

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
    let preloadNext = state.preloadCount;
    let preloadPrev = state.preloadCount == 0 ? 0 : 1;

    if (state.doublePageMode) { preloadNext *= 2; preloadPrev *= 2; }

    for (let i = 1; i <= preloadNext; i++) {
        if (state.currentPage + i > state.maxPage) { break; }
        loadImage(state.currentPage + i);
    }
    for (let i = 1; i <= preloadPrev; i++) {
        if (state.currentPage - i < 0) { break; }
        loadImage(state.currentPage - i);
    }
}

async function loadImage(index) {
    const src = state.pages[index];

    if (!state.preloadedImg[src]) {
        const res = await fetch(src);
        state.preloadedSizes[index] = parseInt(res.headers.get("Content-Length") / 1024, 10);
        const blob = await res.blob();
        state.preloadedImg[src] = URL.createObjectURL(blob);
    }

    return state.preloadedImg[src];
}

export function applyContainerWidth() {
    $(".reader-image, .sni").attr("style", "");

    // If we are in fullscreen don't apply anything
    if (fscreen.inFullscreen())
        return;

    if (state.fitMode === "fit-height") {
        // Fit to height forces the image to 90% of visible screen height.
        // If the header is hidden, or if we're in infinite scrolling, then the image
        // can take up to 98% of visible screen height because there's more free space
        const height = localStorage.hideHeader === "true" || state.infiniteScroll ? 98 : 90;
        $(".reader-image").attr("style", `max-height: ${height}vh;`);
        $(".sni").attr("style", "width: fit-content; width: -moz-fit-content");
    } else if (state.fitMode === "fit-width") {
        $(".reader-image").attr("style", "width: 100%;");
        $(".sni").attr("style", "max-width: 98%");
    } else if (state.containerWidth) {
        // If the user defined a custom width, then we can fall back to that one
        $(".sni").attr("style", `max-width: ${state.containerWidth}`);
        $(".reader-image").attr("style", "width: 100%");
    } else if (!state.showingSinglePage) {
        // Otherwise, if we are showing two pages we can override the default width
        $(".sni").attr("style", "max-width: 90%");
    } else {
        // Finally, fall back to 1200px width if none of the above matches
        $(".sni").attr("style", "max-width: 1200px");
    }

    renderMarkers();
}

function startAutoNextPage() {
    state.autoNextPageCountdown = Math.trunc(state.AutoNextPageInterval);
    if (state.autoNextPageCountdown <= 0) {
        LRR.toast({
            heading: I18N.AutoNextPageFailHeader,
            text: I18N.AutoNextPageFailBody,
            icon: "error",
            hideAfter: 5000,
        });
        return;
    }

    state.autoNextPage = true;

    const aEls = $(".toggle-auto-next-page");
    aEls.removeClass("fa-stopwatch");
    aEls.text(state.autoNextPageCountdown);

    state.autoNextPageCountdownTaskId = setInterval(() => {
        if (state.autoNextPageCountdown <= 0) {
            clearInterval(state.autoNextPageCountdownTaskId);

            const atLastPage = state.mangaMode ? state.currentPage === 0 : state.currentPage === state.maxPage;

            if (atLastPage) {
                // At archive boundary: attempt cross-archive navigation.
                // readNextArchive/readPreviousArchive persists slideshow state
                // to sessionStorage; loadImages on the new page resumes it.
                if (state.archiveIds.length > 0) {
                    if (state.mangaMode)
                        readPreviousArchive();
                    else
                        readNextArchive();
                }
                stopAutoNextPage();
            } else {
                if (state.mangaMode)
                    changePage(-1);
                else
                    changePage(1);
                startAutoNextPage();
            }
            return;
        }
        state.autoNextPageCountdown -= 1;
        aEls.text(state.autoNextPageCountdown);
    }, 1000);

    requestWakeLock();
}

export function stopAutoNextPage() {
    state.autoNextPage = false;
    clearInterval(state.autoNextPageCountdownTaskId);
    $(".toggle-auto-next-page").addClass("fa-stopwatch");
    $(".toggle-auto-next-page").text("");

    releaseWakeLock();
}

function toggleAutoNextPage() {
    state.autoNextPage ? stopAutoNextPage() : startAutoNextPage();
    return false; // prevent scrolling to top
}

function toggleFullScreen() {
    if (fscreen.inFullscreen()) {
        // if already full screen; exit
        fscreen.exitFullscreen();
    } else {
        // else go fullscreen
        // ensure in every case, the correct fullscreen element is binded.
        fscreen.requestFullscreen($("div#i3").get(0));
    }
}

function handleFullScreen(enableFullscreen = false) {
    if (fscreen.inFullscreen() || enableFullscreen === true) {
        if (state.markersVisible) {
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
    return findChapterForPage(state.currentPage + 1, state.content.chapters);
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
                    state.content.chapters.find(ch => ch.id === notes.id).startPage :
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
        state.content.chapters.forEach(arc => fetchThumbsForArc(arc)); // Generate thumbnails per archive
    else
        fetchThumbsForArc({
            id: state.id,
            startPage: 1,
            endPage: state.content.pages,
        }); // Queue a single minion job for thumbnails
}

/**
 * Change current page in reader.
 * 
 * @param {(-1|1|"first"|"last")} targetPage    One of -1 (previous), 1 (next), "first", or "last" page.
 * @param {boolean} resetAuto                   Whether to reset current slideshow counter.
 */
function changePage(targetPage, resetAuto = false) {

    // Reset timer if user manually changes pages during slideshow
    if (resetAuto && state.autoNextPage) {
        state.autoNextPageCountdown = Math.trunc(state.AutoNextPageInterval);
        $(".toggle-auto-next-page").text(state.autoNextPageCountdown);
    }

    // Sync position if in infinite scroll mode
    if (state.infiniteScroll) {
        const images = [...document.querySelectorAll(".reader-image")];
        const midViewport = window.innerHeight / 2;
        for (let i = 0; i < images.length; i++) {
            const rect = images[i].getBoundingClientRect();
            if (rect.top <= midViewport && rect.bottom >= midViewport) {
                state.currentPage = i;
                break;
            }
        }
    }
    let destination;
    if (targetPage === "first") {
        destination = state.mangaMode ? state.maxPage : 0;
    } else if (targetPage === "last") {
        destination = state.mangaMode ? 0 : state.maxPage;
    } else {
        let offset = targetPage;
        // Double the offset to move by 2 pages at once, unless we're currently showing a widespread
        if (state.doublePageMode && !state.showingSinglePage && state.currentPage > 0) {
            offset *= 2;
        }
        destination = state.currentPage + (state.mangaMode ? -offset : offset);
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

function handlePaginator() {
    switch (this.getAttribute("value")) {
        case "outermost-left":
            readPreviousArchive();
            break;
        case "outer-left":
            changePage("first", true);
            break;
        case "left":
            changePage(-1, true);
            break;
        case "right":
            changePage(1, true);
            break;
        case "outer-right":
            changePage("last", true);
            break;
        case "outermost-right":
            readNextArchive();
            break;
        default:
            break;
    }
}

function getFilename(index) {
    return new URLSearchParams(state.pages[index].split("?")[1]).get("path");
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
                $(".archive-nav-link").show();
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
    if (fscreen.inFullscreen()) {
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
        if (state.autoNextPage) {
            sessionStorage.setItem("autoNextPage", "true");
        }
        const newUrl = new LRR.ApiURL(`/reader?id=${previousArchiveId}`).toString();
        window.location.replace(newUrl);
    } else {
        LRR.toast({ text: I18N.ReaderFirstArchive });
    }
}

function readNextArchive() {
    if (fscreen.inFullscreen()) {
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
        if (state.autoNextPage) {
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

