/**
 * Functions to navigate in reader with the keyboard.
 * Also handles the thumbnail archive explorer.
 */
import * as Server from "./server.js";
import * as LRR from "./common.js";
import I18N from "i18n";
import fscreen from "fscreen";


let state = {
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
    registerPreload();
    registerAutoNextPage();
    document.documentElement.style.scrollBehavior = "smooth";

    // Bind events to DOM
    $(document).on("keyup", (e) => handleShortcuts(e));
    // Restrict keydown to only function for spacebar
    $(document).on("keydown", (e) => { if (e.which === 32) handleShortcuts(e); });
    $(document).on("wheel", handleWheel);

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
    $(document).on("click.pagination-change-pages", ".page-link", handlePaginator);
    $(document).on("submit.auto-next-page", "#auto-next-page-input", registerAutoNextPage);
    $(document).on("click.auto-next-page", "#auto-next-page-apply", registerAutoNextPage);

    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.toggle-full-screen", "#toggle-full-screen", (e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleFullScreen();
    });
    $(document).on("click.toggle-auto-next-page", ".toggle-auto-next-page", toggleAutoNextPage);
    $(document).on("click.toggle-archive-overlay", "#toggle-archive-overlay", toggleArchiveOverlay);
    $(document).on("click.toggle-settings-overlay", "#toggle-settings-overlay", toggleSettingsOverlay);
    $(document).on("click.toggle-help", "#toggle-help", toggleHelp);
    $(document).on("click.toggle-stamps", "#toggle-stamps", toggleStamps);
    $(document).on("click.toggle-bookmark", ".toggle-bookmark", toggleBookmark);
    $(document).on("click.regenerate-archive-cache", "#regenerate-cache", () => {
        window.location.href = new LRR.ApiURL(`/reader?id=${state.id}&force_reload`);
    });
    $(document).on("click.edit-metadata", "#edit-archive", () => LRR.openInNewTab(new LRR.ApiURL(`/edit?id=${state.id}`)));
    $(document).on("click.delete-archive", "#delete-archive", () => {
        const isTank = state.id.startsWith("TANK_");
        LRR.closeOverlay();
        LRR.showPopUp({
            text: isTank ? I18N.ConfirmTankoubonDeletion : I18N.ConfirmArchiveDeletion,
            icon: "warning",
            showCancelButton: true,
            focusConfirm: false,
            confirmButtonText: I18N.ConfirmYes,
            reverseButtons: true,
            confirmButtonColor: "#d33",
        }).then((result) => {
            if (result.isConfirmed) {
                if (isTank) Server.deleteTankoubon(state.id, () => { document.location.href = "./"; });
                else Server.deleteArchive(state.id, () => { document.location.href = "./"; });
            }
        });
    });
    $(document).on("click.add-category", "#add-category", () => {
        if ($("#category").val() === "" || $(`#archive-categories a[data-id="${$("#category").val()}"]`).length !== 0) { return; }
        Server.addArchiveToCategory(state.id, $("#category").val());
        const categoryId = $("#category").val();
        addCategoryBadge(categoryId);

        // Turn ON bookmark icon.
        if ($("#category").val() == localStorage.bookmarkCategoryId) {
            $(".toggle-bookmark")
                .removeClass("far fa-bookmark")
                .addClass("fas fa-bookmark");
        }
    });
    $(document).on("click.remove-category", ".remove-category", (e) => {
        e.preventDefault();
        const catId = $(e.target).attr("data-id");
        Server.removeArchiveFromCategory(state.id, $(e.target).attr("data-id"));
        $(e.target).closest(".gt").remove();
        // Turn OFF the bookmark icon
        if (catId == localStorage.bookmarkCategoryId) {
            $(".toggle-bookmark")
                .removeClass("fas fa-bookmark")
                .addClass("far fa-bookmark");
        }
    });

    $(document).on("click.add-toc", ".add-toc", (e) => { 
        const page = +$(e.target).closest("div[page]").attr("page") + 1; 
        addTocSection(page);

        // Stop event propagation to avoid going to page
        e.stopPropagation();
    });
    $(document).on("click.edit-toc", ".edit-toc", () => addTocSection(state.currentChapter.startPage, state.currentChapter.name));
    $(document).on("click.remove-toc", ".remove-toc", removeTocSection);

    $(document).on("click.set-thumbnail", ".set-thumbnail", (e) => {
        const pageNumber = +$(e.target).closest("div[page]").attr("page") + 1;

        if (state.id.startsWith("TANK_")) {
            Server.callAPI(`/api/tankoubons/${state.id}/thumbnail?page=${pageNumber}`,
                "PUT", I18N.ReaderUpdateThumbnail(pageNumber), I18N.ReaderUpdateThumbnailError, null);
        } else {
            Server.callAPI(`/api/archives/${state.id}/thumbnail?page=${pageNumber}`,
                "PUT", I18N.ReaderUpdateThumbnail(pageNumber), I18N.ReaderUpdateThumbnailError, null);
        }

        // Stop event propagation to avoid going to page
        e.stopPropagation();
    });

    $(document).on("click.thumbnail", ".quick-thumbnail", (e) => {
        LRR.closeOverlay();
        const pageNumber = +$(e.target).closest("div[page]").attr("page");
        goToPage(pageNumber);
    });

    $(document).on("click.reader-image", ".reader-image", (e) => {
        if (!state.markerMode) return;

        $(".reader-image").css("cursor", "");
        $(".reader-image").css("z-index", 19);

        // Compute marker position
        // This basically estimates the percentage of the width and legth of the image
        // where the user clicked, so later from this percentage can be reversed
        // without being affected by if the image got scaled up or down
        const img = e.currentTarget;

        const rect = img.getBoundingClientRect();

        const clickX = e.clientX - rect.left;
        const clickY = e.clientY - rect.top;

        const xPercent = (clickX / rect.width) * 100;
        const yPercent = (clickY / rect.height) * 100;

        const markerData = {
            x: xPercent,
            y: yPercent,
            name: `Marker`,
            left: true,
        };

        let page = state.currentPage + 1;

        if (state.doublePageMode && state.currentPage > 0
            && state.currentPage < state.maxPage) {
            if (img.id == "img_doublepage") {
                page += 1;
                markerData.left = false;
            }
        }
        LRR.showPopUp({
            title: I18N.StampName,
            input: "text",
            inputPlaceholder: I18N.StampPlaceholder,
            inputAttributes: {
                autocapitalize: "off",
            },
            showCancelButton: true,
            reverseButtons: true,
        }).then((result) => {
            $("#overlay-page").hide();
            state.markerMode = false;
            if (result.isConfirmed && result.value.trim() !== "") {
                const { arcId, localPage } = getArchiveForPage(page);
                Server.callAPI(`/api/archives/${arcId}/stamps/${localPage}?position=${markerData.x},${markerData.y}&content=${result.value}`, 
                    "PUT", "Stamp added!", I18N.StampError,
                    (data) => {
                        markerData.id = data["stamp_id"];
                        markerData.name = result.value;

                        state.markers.push(markerData);
                        renderMarkers();
                        checkStampedPages();
                    }
                );
            } else {
                renderMarkers();
            }
        });
        e.stopPropagation();
    });

    // Press esc to cancel set stamp action
    $(document).on("keydown", (e) => {
        e.stopPropagation();
        if (e.key === "Escape" && state.markerMode) {
            $("#overlay-page").hide();
            state.markerMode = false;
            renderMarkers();
            state.pageNaviState = true;
            $(".reader-image").css("cursor", "");
            $(".reader-image").css("z-index", 19);
        }
    });
    $(document).on("click.filter-stamped", "#filter-stamped", filterStampedOverlay);

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
function getArchiveForPage(globalPage) {
    if (state.id.startsWith("TANK_")) {
        const arc = state.content.chapters.find(a => globalPage >= a.startPage && globalPage <= a.endPage);
        if (arc)
            return { arcId: arc.id, localPage: globalPage - arc.startPage + 1 };
    }
    return { arcId: state.id, localPage: globalPage };
};

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

export function removeCategoryBadge(categoryId) {
    $(`#archive-categories a.remove-category[data-id="${categoryId}"]`).closest(".gt").remove();
}

export function addTocSection(page, currentTitle = null) {

    LRR.closeOverlay(); 
    LRR.showPopUp({
        title: I18N.ReaderTocPrompt,
        input: "text",
        inputPlaceholder: currentTitle || I18N.UntitledChapter, 
        inputAttributes: {
            autocapitalize: "off",
        },
        showCancelButton: true,
        reverseButtons: true,
    }).then((result) => {
        if (result.isConfirmed && result.value.trim() !== "") {
            const { arcId, localPage } = getArchiveForPage(page);
            Server.callAPI(`/api/archives/${arcId}/toc?page=${localPage}&title=${result.value}`, "PUT", "Chapter added!", I18N.ReaderTocError,
                () => loadContentData().then(() => {
                    updateArchiveOverlay(true);
                    toggleArchiveOverlay();
                    goToPage(page);
                })
            );
        } else {
            toggleArchiveOverlay();
        }
    });
}

export function removeTocSection() {

    LRR.closeOverlay(); 
    LRR.showPopUp({
        text: I18N.ReaderDeleteTocPrompt,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            const { arcId, localPage } = getArchiveForPage(state.currentChapter.startPage);
            Server.callAPI(`/api/archives/${arcId}/toc?page=${localPage}`, "DELETE", "Chapter removed!", I18N.ReaderTocError,
                () => loadContentData().then(() => {
                    updateArchiveOverlay(true);
                    toggleArchiveOverlay();
                })
            );
        } else {
            toggleArchiveOverlay();
        }
    });
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

export function initializeSettings() {
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
        case 83: // s
            if (!state.infiniteScroll) {
                addStamp();
            }
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
        let changePage = 1;
        if (e.originalEvent.deltaY > 0) changePage = -1;
        // In Manga mode, reverse the changePage variable
        // so that we always move forward
        if (!state.mangaMode) changePage *= -1;
        changePage(changePage, true);
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

function addStamp() {
    if (state.infiniteScroll) return;
    if (!LRR.isUserLogged()) return;
    state.markerMode = true;
    clearMarkers();
    $(".reader-image").css("cursor", "cell");
    $(".reader-image").css("z-index", 22);
    $("#overlay-page").show();
}

function createMarkerElement(markerData, index) {
    if (state.infiniteScroll) return;
    const img = markerData.left
        ? document.getElementById("img")
        : document.getElementById("img_doublepage");


    const display = document.getElementById("display");
    const container = document.getElementById("i1");

    const marker = document.createElement("div");
    marker.className = "marker marker-context-menu";

    // Compute the px coordinates from the percentage based coordinates
    const rect = img.getBoundingClientRect();
    const xPx = (markerData.x / 100) * rect.width;
    const yPx = (markerData.y / 100) * rect.height;

    const containerRect = container.getBoundingClientRect();

    let leftFix = rect.left - containerRect.left;
    let topFix = rect.top - containerRect.top;

    if (!markerData.left) {
        // Add the width of the left page plus the left and right margin
        const img = document.getElementById("img");
        leftFix += img.width+2;
    }

    marker.style.left = `${leftFix + xPx}px`;
    marker.style.top = `${topFix + yPx}px`;

    marker.title = markerData.name;
    marker.dataset.index = index;

    // Edit
    let isDragging = false;

    marker.addEventListener("mousedown", (e) => {
        if (e.button !== 0) return;
        e.stopPropagation();
        isDragging = true;

        // So no text gets selected during the D&D
        document.body.style.userSelect = "none";
        state.pageNaviState = false;
    });

    document.addEventListener("mousemove", (e) => {
        if (!isDragging) return;

        const imgRect = img.getBoundingClientRect();
        const dispRect = display.getBoundingClientRect();

        // Ensure that the stamp remains inside the image
        let x = e.clientX - imgRect.left + leftFix;
        let y = e.clientY - imgRect.top + topFix;

        x = Math.max(leftFix, Math.min(x, imgRect.width + leftFix));
        y = Math.max(topFix, Math.min(y, imgRect.height + topFix));

        marker.style.left = `${imgRect.left + x - dispRect.left}px`;
        marker.style.top = `${imgRect.top + y - dispRect.top}px`;
    });

    document.addEventListener("mouseup", (e) => {
        e.stopPropagation();
        // Each marker individually run this event when on mouseup
        // this line ensures that only one of them execute the action
        // also a good improvement would be to change this to an attachable event only for the dragged marker
        if (!isDragging) return;

        isDragging = false;
        document.body.style.userSelect = "auto";

        const imgRect = img.getBoundingClientRect();

        let x = e.clientX - imgRect.left;
        let y = e.clientY - imgRect.top;

        x = Math.max(0, Math.min(x, imgRect.width));
        y = Math.max(0, Math.min(y, imgRect.height));

        const xPercent = (x / imgRect.width) * 100;
        const yPercent = (y / imgRect.height) * 100;

        const i = marker.dataset.index;
        let inputValue = markerData.name;

        Server.callAPI(`/api/stamps/${markerData.id}?position=${xPercent},${yPercent}`, "PUT", "Stamp updated!", I18N.StampError,
            () => {
                state.markers[i].x = xPercent;
                state.markers[i].y = yPercent;

                state.pageNaviState = true;
                renderMarkers();
            }
        );
    });

    display.appendChild(marker);
}

function renderMarkers() {
    if (state.infiniteScroll || fscreen.inFullscreen()) return;
    // Clean markers
    const existing = document.querySelectorAll(".marker");
    existing.forEach(el => el.remove());

    if (!state.markersVisible) return;

    // Draw markers
    state.markers.forEach((markerData, index) => {
        createMarkerElement(markerData, index);
    });
}

function clearMarkers() {
    const existing = document.querySelectorAll(".marker");
    existing.forEach(el => el.remove());
}

function toggleStamps() {
    // Show or hide the markers
    state.markersVisible = localStorage.markersVisible = !state.markersVisible;
    renderMarkers();
}

function loadStamps(currentPage) {
    if (state.infiniteScroll) return;
    state.markers = [];
    const { arcId: id1, localPage: p1 } = getArchiveForPage(currentPage);
    // Call for the first page
    Server.callAPI(`/api/archives/${id1}/stamps/${p1}`, "GET", null, I18N.ServerInfoError,
        (data) => {
            for (var i = data.result.length - 1; i >= 0; i--) {
                let markerData = {};
                let x = data.result[i].position.split(",")[0];
                let y = data.result[i].position.split(",")[1];
                markerData.x = x;
                markerData.y = y;
                markerData.name = data.result[i].content;
                markerData.id = data.result[i].id;
                markerData.left = true;
                state.markers.push(markerData);
            }

            if (state.doublePageMode && currentPage > 0
                && currentPage < state.maxPage) {

                const { arcId: id2, localPage: p2 } = getArchiveForPage(currentPage + 1);
                // Call for the second page (may be in a different archive for tanks)
                Server.callAPI(`/api/archives/${id2}/stamps/${p2}`, "GET", null, I18N.ServerInfoError,
                    (data) => {
                        for (var i = data.result.length - 1; i >= 0; i--) {
                            let markerData = {};
                            let x = data.result[i].position.split(",")[0];
                            let y = data.result[i].position.split(",")[1];
                            markerData.x = x;
                            markerData.y = y;
                            markerData.name = data.result[i].content;
                            markerData.id = data.result[i].id;
                            markerData.left = false;
                            state.markers.push(markerData);
                        }

                        // Render markers
                        renderMarkers();
                    }
                );
            } else {
                // Render markers
                renderMarkers();
            }
        }
    );
}

function handleMarkerContextMenu(option, index) {
    if (state.infiniteScroll) return;
    let i = parseInt(index);

    switch (option) {
        case "editmarker": {
            let emarker = state.markers[i];
            let inputValue = emarker.name;

            LRR.showPopUp({
                title: I18N.StampName,
                input: "text",
                inputPlaceholder: I18N.StampPlaceholder,
                inputAttributes: {
                    autocapitalize: "off",
                },
                inputValue,
                showCancelButton: true,
                reverseButtons: true,
            }).then((result) => {
                if (result.isConfirmed && result.value.trim() !== "") {
                    Server.callAPI(`/api/stamps/${emarker.id}?content=${result.value}`, "PUT", "Stamp updated!", I18N.StampError,
                        () => {
                            state.markers[i].name = result.value;

                            state.pageNaviState = true;
                            renderMarkers();
                        }
                    );
                } else {
                    state.pageNaviState = true;
                }
            });
            break;
        }
        case "deletemarker": {
            let dmarker = state.markers[i];
            Server.callAPI(`/api/stamps/${dmarker.id}`, "DELETE", "Stamp deleted!", I18N.StampError,
                () => {
                    state.markers.splice(i, 1);
                    renderMarkers();
                    if (state.markers.length == 0) {
                        checkStampedPages();
                    }
                }
            );
            break;
        }
        default:
            break;
    }
};

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

async function goToPage(page) {
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
    state.markers = [];
    renderMarkers();

    let page = state.currentPage + 1; // progress is 1-indexed

    // Send an API request to update progress on the server
    if (state.authenticateProgress && LRR.isUserLogged()) {
        Server.updateServerSideProgress(state.id, page);
    } else if (state.trackProgressLocally) {
        localStorage.setItem(`${state.id}-reader`, page);
    } else if (!state.authenticateProgress) {
        Server.updateServerSideProgress(state.id, page);
    }

    // Load stamps
    if (!state.infiniteScroll) {
        const stamps = loadStamps(page);
    }
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

function applyContainerWidth() {
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

function registerPreload() {
    const rawInputVal = $("#preload-input").val();
    const inputVal = rawInputVal === "" ? null : rawInputVal;
    const storageVal = (localStorage.preloadCount === "" ? null : localStorage.preloadCount);

    state.preloadCount = inputVal ?? storageVal ?? 2;
    $("#preload-input").val(state.preloadCount);
    localStorage.preloadCount = state.preloadCount;
}

function toggleDoublePageMode() {
    if (state.infiniteScroll) { return; }
    state.doublePageMode = localStorage.doublePageMode = !state.doublePageMode;
    $("#toggle-double-mode input").toggleClass("toggled");
    goToPage(state.currentPage);
}

function toggleMangaMode() {
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

function stopAutoNextPage() {
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

function toggleOverlayByDefault() {
    state.showOverlayByDefault = localStorage.showOverlayByDefault = !state.showOverlayByDefault;
    $("#toggle-overlay input").toggleClass("toggled");
}

function toggleSettingsOverlay() {
    stopAutoNextPage();
    return toggleOverlay("#settingsOverlay");
}

function toggleArchiveOverlay() {
    stopAutoNextPage();
    return toggleOverlay("#archivePagesOverlay");
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

function getCurrentChapter() {
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

function updateArchiveOverlay(forceUpdate = false) {
    $("#extract-spinner").hide();

    // Check if the overlay actually needs to be updated
    // If it's already loaded and we're still in the same chapter (or no chapter), do nothing
    if ($("#archivePagesOverlay").attr("loaded") === "true" && !forceUpdate) {

        if ((state.currentChapter === null) ||
            (state.currentPage + 1 >= state.currentChapter.startPage &&
                state.currentPage + 1 <= state.currentChapter.endPage)) {
            return;
        }
    }

    // Reset stamp filter state when the overlay is rebuilt for a new chapter
    if (state.overlayFiltered) {
        state.overlayFiltered = false;
        $("#filter-stamped").removeClass("toggled");
    }

    // Otherwise, update chapter and overlay -- If there are no chapters defined, just show all pages
    state.currentChapter = getCurrentChapter();
    let firstPage = state.currentChapter ? state.currentChapter.startPage : 1;
    let lastPage = state.currentChapter ? state.currentChapter.endPage : state.pages.length;

    $("#overlay-section").text(state.currentChapter ? state.currentChapter.name : I18N.ReaderPages);

    if (state.currentChapter !== null) {
        // Create <select> options for jumping to other chapters
        let chapterOptions = `<select class="favtag-btn" id="chapter-select">`;
        if (state.content.chapters) {
            state.content.chapters.forEach((chapter) => {
                const selected = (state.currentChapter && chapter.startPage === state.currentChapter.startPage) ? "selected" : "";
                chapterOptions += `<option value="${chapter.startPage}" ${selected}>${LRR.encodeHTML(chapter.name)}</option>`;

                if (chapter.chapters && chapter.chapters.length > 0) {
                    chapter.chapters.forEach((subChapter) => {
                        const subSelected = (state.currentChapter && subChapter.startPage === state.currentChapter.startPage) ? "selected" : "";
                        chapterOptions += `<option value="${subChapter.startPage}" ${subSelected}>&nbsp;&nbsp;&nbsp;${LRR.encodeHTML(subChapter.name)}</option>`;
                    });
                }
            });
        }
        chapterOptions += `</select>`;

        if (LRR.isUserLogged() && state.currentChapter.chapters === null ) // Only show edit/delete options for leaf chapters
            chapterOptions += `<a class="fas fa-pencil-alt edit-toc" href="#" style="padding:8px; font-size:14px" title="${I18N.ReaderEditToc}"/>
                            <a class="fas fa-trash-alt remove-toc" href="#" style="padding:8px; font-size:14px" title="${I18N.ReaderDeleteToc}"/>`;

        $(".chapter-selector").html(chapterOptions);

        $("#chapter-select").off("change").on("change", function () {
            goToPage($(this).val() - 1);
        });
    } else {
        $(".chapter-selector").html("");
    }

    // For each link in the pages array, craft a div and jam it in the overlay.
    let htmlBlob = "";
    for (let page = firstPage; page < lastPage + 1; ++page) {
        const index = page - 1;

        const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        const { arcId, localPage } = getArchiveForPage(page);
        const thumbnailUrl = new LRR.ApiURL(`/api/archives/${arcId}/thumbnail?page=${localPage}`);
        
        let thumbnail = `
            <div class='${thumbCss} quick-thumbnail' page='${index}' style='display: inline-block; cursor: pointer'>
                <span class='page-number'>${I18N.ReaderPage(page)}</span>
                <img src="${thumbnailUrl}" id="${index}_thumb" loading="lazy" />`;
        
        if (LRR.isUserLogged()) 
            thumbnail += `<a href="#" style="padding:12px; top:2%; left:72%;" 
                             title="${I18N.ReaderSetPageAsThumbnail}" 
                             class="fas fa-file-image page-number set-thumbnail"></a>
                          <a href="#" style="padding:12px; top:80%; left:72%;" 
                             title="${I18N.ReaderAddToc}" 
                             class="fas fa-book-medical page-number add-toc"></a>`;

        if (state.pageThumbnails.includes(index)) thumbnail +=
            `</div>`;
        else thumbnail += 
                `<i id="${index}_spinner" class="fa fa-4x fa-circle-notch fa-spin ttspinner" style="display:flex;justify-content: center; align-items: center;"></i>
            </div>`;

        htmlBlob += thumbnail;
    }

    // NOTE: This can be slow on huge archives and on slower devices, due to the huge DOM change.
    $("#pages-section").html(htmlBlob);
    $("#archivePagesOverlay").attr("loaded", "true");
    checkStampedPages();
}

function checkStampedPages() {
    const { arcId, localPage } = getArchiveForPage(state.currentPage + 1);
    Server.callAPI(`/api/archives/${arcId}/stamps/`, "GET", null, I18N.ServerInfoError,
        (data) => {
            $("#extract-spinner").hide();
            cleanStampedPages();
            let pages = data.result.sort();
            let elements = $("div.id3.quick-thumbnail");

            for (let element of elements) {
                let page = parseInt(element.getAttribute("page"));
                const { _, localPage } = getArchiveForPage(page+1);

                if (pages.includes((localPage).toString())) {
                    element.dataset.stamped = true;
                }
            }
        }
    );
}

function cleanStampedPages() {
    let elements = $("div.id3.quick-thumbnail[data-stamped=true]");

    for (let element of elements) {
        delete element.dataset.stamped;
    }
}

function filterStampedOverlay() {
    let elements = $("div.id3.quick-thumbnail");

    if (state.overlayFiltered) {
        state.overlayFiltered = false;
        $("#filter-stamped").removeClass("toggled");
        for (let element of elements) {
            element.style.display = `inline-block`;
        }
    } else {
        state.overlayFiltered = true;
        $("#filter-stamped").addClass("toggled");
        for (let element of elements) {
            if (!element.dataset.stamped) {
                element.style.display = `none`;
            }
        }
    }
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
function toggleOverlay(selector) {
    updateArchiveOverlay();
    const overlay = $(selector);
    overlay.is(":visible")
        ? LRR.closeOverlay()
        : $("#overlay-shade").fadeTo(150, 0.6, () => overlay.show());

    return false; // needs to return false to prevent scrolling to top
}
window.addEventListener("resize", () => {
    // Reload the markers everytime the image size changes
    renderMarkers();
});

jQuery(() => {
    $.contextMenu({
        selector: `.marker-context-menu`,
        build: ($trigger, e) => {
            e.preventDefault();
            e.stopPropagation();
            return {
                callback: function (key, options) {
                    handleMarkerContextMenu(key, $(this).attr("data-index"));
                },
                items: {
                    "editmarker": {"name": "Edit Marker", "icon":"fas fa-pen-to-square"},
                    "deletemarker": {"name": "Delete Marker", "icon":"fas fa-minus"},
                }
            };
        }
    });
});

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

