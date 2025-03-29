/**
 * Functions to navigate in reader with the keyboard.
 * Also handles the thumbnail archive explorer.
 */
const Reader = {};

Reader.id = "";
Reader.force = false;
Reader.previousPage = -1;
Reader.currentPage = -1;
Reader.showingSinglePage = true;
Reader.preloadedImg = {};
Reader.preloadedSizes = {};

Reader.archiveIndex = -1;
Reader.archiveIds = [];

Reader.initializeAll = function () {
    Reader.initializeSettings();
    Reader.applyContainerWidth();
    Reader.registerPreload();

    // Bind events to DOM
    $(document).on("keyup", Reader.handleShortcuts);
    $(document).on("wheel", Reader.handleWheel);

    $(document).on("click.toggle-fit-mode", "#fit-mode input", Reader.toggleFitMode);
    $(document).on("click.toggle-double-mode", "#toggle-double-mode input", Reader.toggleDoublePageMode);
    $(document).on("click.toggle-manga-mode", "#toggle-manga-mode input, .reading-direction", Reader.toggleMangaMode);
    $(document).on("click.toggle-header", "#toggle-header input", Reader.toggleHeader);
    $(document).on("click.toggle-progress", "#toggle-progress input", Reader.toggleProgressTracking);
    $(document).on("click.toggle-infinite-scroll", "#toggle-infinite-scroll input", Reader.toggleInfiniteScroll);
    $(document).on("click.toggle-overlay", "#toggle-overlay input", Reader.toggleOverlayByDefault);
    $(document).on("submit.container-width", "#container-width-input", Reader.registerContainerWidth);
    $(document).on("click.container-width", "#container-width-apply", Reader.registerContainerWidth);
    $(document).on("submit.preload", "#preload-input", Reader.registerPreload);
    $(document).on("click.preload", "#preload-apply", Reader.registerPreload);
    $(document).on("click.pagination-change-pages", ".page-link", Reader.handlePaginator);

    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.toggle-full-screen", "#toggle-full-screen", (e) => {
        e.preventDefault();
        e.stopPropagation();
        Reader.handleFullScreen(true);
    });
    $(document).on("click.toggle-archive-overlay", "#toggle-archive-overlay", Reader.toggleArchiveOverlay);
    $(document).on("click.toggle-settings-overlay", "#toggle-settings-overlay", Reader.toggleSettingsOverlay);
    $(document).on("click.toggle-help", "#toggle-help", Reader.toggleHelp);
    $(document).on("click.regenerate-archive-cache", "#regenerate-cache", () => {
        window.location.href = new LRR.apiURL(`/reader?id=${Reader.id}&force_reload`);
    });
    $(document).on("click.edit-metadata", "#edit-archive", () => LRR.openInNewTab(new LRR.apiURL(`/edit?id=${Reader.id}`)));
    $(document).on("click.delete-archive", "#delete-archive", () => {
        LRR.closeOverlay();
        LRR.showPopUp({
            text: "Are you sure you want to delete this archive?",
            icon: "warning",
            showCancelButton: true,
            focusConfirm: false,
            confirmButtonText: "Yes, delete it!",
            reverseButtons: true,
            confirmButtonColor: "#d33",
        }).then((result) => {
            if (result.isConfirmed) {
                Server.deleteArchive(Reader.id, () => { document.location.href = "./"; });
            }
        });
    });
    $(document).on("click.add-category", "#add-category", () => {
        if ($("#category").val() === "" || $(`#archive-categories a[data-id="${$("#category").val()}"]`).length !== 0) { return; }
        Server.addArchiveToCategory(Reader.id, $("#category").val());
        let url = new LRR.apiURL(`/?c=${$("#category").val()}`);
        
        const html = `<div class="gt" style="font-size:14px; padding:4px">
            <a href="${url}">
            <span class="label">${$("#category option:selected").text()}</span>
            <a href="#" class="remove-category" data-id="${$("#category").val()}"
                style="margin-left:4px; margin-right:2px">×</a>
        </a>`;

        $("#archive-categories").append(html);
    });
    $(document).on("click.remove-category", ".remove-category", (e) => {
        Server.removeArchiveFromCategory(Reader.id, $(e.target).attr("data-id"));
        $(e.target).parent().remove();
    });
    $(document).on("click.set-thumbnail", "#set-thumbnail", () => Server.callAPI(`/api/archives/${Reader.id}/thumbnail?page=${Reader.currentPage + 1}`,
        "PUT", `Successfully set page ${Reader.currentPage + 1} as the thumbnail!`, "Error updating thumbnail!", null));

    $(document).on("click.thumbnail", ".quick-thumbnail", (e) => {
        LRR.closeOverlay();
        const pageNumber = +$(e.target).closest("div[page]").attr("page");
        Reader.goToPage(pageNumber);
    });

    // Set previous page to index when reading multiple archives
    window.addEventListener("popstate", () => {
        // Don't clear archive navigation state when using the back button
        // as it breaks navigation between archives
        window.location.href = "./";
    });

    // Apply full-screen utility
    // F11 Fullscreen is totally another "Fullscreen", so its support is beyong consideration.
    if (!window.fscreen.fullscreenEnabled) {
        // Fullscreen mode is unsupported
        $("#toggle-full-screen").hide();
    } else {
        // Small override function, always returns boolean
        window.fscreen.inFullscreen = () => !!window.fscreen.fullscreenElement;
    }

    // Infer initial information from the URL
    const params = new URLSearchParams(window.location.search);
    Reader.id = params.get("id");
    Reader.force = params.get("force_reload") !== null;
    Reader.currentPage = (+params.get("p") || 1) - 1;

    // Set up archive navigation state
    Reader.setupArchiveNavigation();

    // Remove the "new" tag with an api call
    Server.callAPI(`/api/archives/${Reader.id}/isnew`, "DELETE", null, "Error clearing new flag! Check Logs.", null);

    // Get basic metadata
    Server.callAPI(`/api/archives/${Reader.id}/metadata`, "GET", null, "Error getting basic archive info!",
        (data) => {
            let { title } = data;

            // Regex look in tags for artist
            const artist = data.tags.match(/.*artist:([^,]*),.*/i);
            if (artist) {
                title = `${title} by ${artist[1]}`;
            }

            $("#archive-title").text(title);
            $("#archive-title-overlay").text(title);
            if (data.pagecount) { $(".max-page").text(data.pagecount); }
            document.title = title;

            Reader.tags = data.tags;
            $("#tagContainer").append(LRR.buildTagsDiv(Reader.tags));

            if (data.summary) {
                $("#tagContainer").append("<div class=\"archive-summary\"/>");
                $(".archive-summary").text(data.summary);
            }

            // Use localStorage progress value instead of the server one if needed
            if (Reader.trackProgressLocally) {
                Reader.progress = localStorage.getItem(`${Reader.id}-reader`) - 1 || 0;
            } else {
                Reader.progress = data.progress - 1;
            }

            // check and display warnings for unsupported filetypes
            Reader.checkFiletypeSupport(data.extension);

            // Load the actual reader pages now that we have basic info
            Reader.loadImages();
        },
    );

    // Changing archives in reader mode cause datatables search info to be lost, so we need to
    // get it out from localStorage when calling return to index.
    $(document).on("click.return-to-index", "#return-to-index", (e) => {
        e.preventDefault();
        Reader.returnToIndex();
    });
};

/**
 * Determine if current page qualifies for, and sets up, archive navigation state.
 * While in reader mode, navigation state is only supported if user enters reader from index datatables,
 * or if user is already in reader mode with navigation support and switches to a different archive via
 * readNextArchive() or readPreviousArchive().
 * 
 * If users enters from carousel or by pasting URL, navigation is not supported
 * 
 * @returns {boolean} - whether archive navigation state was set up
 */
Reader.setupArchiveNavigation = function () {
    const navigationState = sessionStorage.getItem('navigationState');
    const currArchiveIdsJson = localStorage.getItem('currArchiveIds');
    const referrer = document.referrer;
    const isDirectNavigation = !referrer || !referrer.includes(window.location.host)
    if (isDirectNavigation) {
        Reader.archiveIds = [];
        sessionStorage.removeItem('navigationState');
        return false;
    } else if (navigationState === 'datatables' && currArchiveIdsJson) {
        try {
            const archiveIds = JSON.parse(currArchiveIdsJson);
            Reader.archiveIds = archiveIds;
            Reader.archiveIndex = archiveIds.indexOf(Reader.id);
            if (Reader.archiveIndex !== -1) {
                if (Reader.archiveIndex === 0) {
                    const previousArchives = Reader.loadPreviousDatatablesArchives();
                    if (previousArchives) {
                        localStorage.setItem('previousArchiveIds', JSON.stringify(previousArchives));
                    }
                }
                if (Reader.archiveIndex === archiveIds.length - 1) {
                    const nextArchives = Reader.loadNextDatatablesArchives();
                    if (nextArchives) {
                        localStorage.setItem('nextArchiveIds', JSON.stringify(nextArchives));
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

Reader.loadImages = function () {
    Server.callAPI(`/api/archives/${Reader.id}/files?force=${Reader.force}`, "GET", null, "Error getting the archive's imagelist!",
        (data) => {
            Reader.pages = data.pages;
            Reader.maxPage = Reader.pages.length - 1;
            $(".max-page").html(Reader.pages.length);

            // Choices in order for page picking:
            // * p is in parameters and is not the first page
            // * progress is tracked and is not the last page
            // * first page
            // This allows for bookmarks to trump progress
            // when there's no parameter, null is coerced to 0 so it becomes -1
            Reader.currentPage = Reader.currentPage || (
                !Reader.ignoreProgress && Reader.progress < Reader.maxPage
                    ? Reader.progress
                    : 0
            );

            if (Reader.infiniteScroll) {
                Reader.initInfiniteScrollView();
            } else {
                $("#img").on("load", Reader.updateMetadata);

                // when click left or right img area change page
                $(document).on("click", (event) => {
                    // check click Y position is in img Y area
                    if ($(event.target).closest("#i3").length && !$("#overlay-shade").is(":visible")) {
                        // is click X position is left on screen or right
                        if (event.pageX < $(window).width() / 2) {
                            Reader.changePage(-1);
                        } else {
                            Reader.changePage(1);
                        }
                    }
                });

                $(".current-page").each((_i, el) => $(el).html(Reader.currentPage + 1));
                Reader.goToPage(Reader.currentPage);
            }

            if (Reader.showOverlayByDefault) { Reader.toggleArchiveOverlay(); }
            Reader.initializeArchiveOverlay();
        },
    ).finally(() => {
        if (Reader.pages === undefined) {
            $("#img").attr("src", new LRR.apiURL("/img/flubbed.gif").toString());
            $("#display").append("<h2>I flubbed it while trying to open the archive.</h2>");
        }
    });
};

Reader.initializeSettings = function () {
    // Initialize settings and button toggles
    if (localStorage.hideHeader === "true" || false) {
        $("#hide-header").addClass("toggled");
        $("#i2").hide();
    } else {
        $("#show-header").addClass("toggled");
    }

    Reader.mangaMode = localStorage.mangaMode === "true" || false;
    if (Reader.mangaMode) {
        $("#manga-mode").addClass("toggled");
        $(".reading-direction").toggleClass("fa-arrow-left fa-arrow-right");
    } else {
        $("#normal-mode").addClass("toggled");
    }

    Reader.doublePageMode = localStorage.doublePageMode === "true" || false;
    Reader.doublePageMode ? $("#double-page").addClass("toggled") : $("#single-page").addClass("toggled");

    Reader.ignoreProgress = localStorage.ignoreProgress === "true" || false;
    Reader.ignoreProgress ? $("#untrack-progress").addClass("toggled") : $("#track-progress").addClass("toggled");

    Reader.infiniteScroll = localStorage.infiniteScroll === "true" || false;
    $(Reader.infiniteScroll ? "#infinite-scroll-on" : "#infinite-scroll-off").addClass("toggled");

    Reader.showOverlayByDefault = localStorage.showOverlayByDefault === "true" || false;
    $(Reader.showOverlayByDefault ? "#show-overlay" : "#hide-overlay").addClass("toggled");

    if (localStorage.fitMode === "fit-width") {
        Reader.fitMode = "fit-width";
        $("#fit-width").addClass("toggled");
        $("#container-width").hide();
    } else if (localStorage.fitMode === "fit-height") {
        Reader.fitMode = "fit-height";
        $("#fit-height").addClass("toggled");
        $("#container-width").hide();
    } else {
        Reader.fitMode = "fit-container";
        $("#fit-container").addClass("toggled");
    }

    Reader.containerWidth = localStorage.containerWidth;
    if (Reader.containerWidth) { $("#container-width-input").val(Reader.containerWidth); }
};

Reader.initInfiniteScrollView = function () {
    $("body").addClass("infinite-scroll");
    $("#Map").remove();
    $("#img_doublepage").remove();
    $(".reader-image").first().attr("src", Reader.pages[0]);

    // Disable other options that don't work with infinite scroll
    Reader.mangaMode = false;
    Reader.doublePageMode = false;

    // Create an observer to update progress when a new page is scrolled in
    let allImagesLoaded = false;
    const observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting && allImagesLoaded) {
            // Find the entry in the list of images
            const index = entries[0].target.id.replace("page-", "");
            // Convert to int
            const page = parseInt(index, 10);
            // Avoid double progress updates
            if (Reader.currentPage !== page) {
                Reader.currentPage = page;
                Reader.updateProgress();
            }
        }
    }, { threshold: 0.5 });

    Reader.pages.slice(1).forEach((source) => {
        const img = new Image();
        img.id = `page-${Reader.pages.indexOf(source)}`;
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
            Reader.changePage(-1);
        } else {
            Reader.changePage(1);
        }
    });

    Reader.applyContainerWidth();

    // Wait for the pages to load before scrolling to the current page
    const images = $("#display .reader-image");
    let loaded = 0;
    images.on("load", () => {
        loaded += 1;
        if (loaded === images.length) {
            allImagesLoaded = true;
            Reader.goToPage(Reader.currentPage);
        }
    });
};

Reader.handleShortcuts = function (e) {
    if (e.target.tagName === "INPUT") {
        return;
    }
    switch (e.keyCode) {
    case 8: // backspace
        document.location.href = $("#return-to-index").attr("href");
        break;
    case 27: // escape
        LRR.closeOverlay();
        break;
    case 32: // spacebar
        if ($(".page-overlay").is(":visible")) { break; }
        if (e.originalEvent.getModifierState("Shift") && (window.scrollY) === 0) {
            (Reader.mangaMode) ? Reader.changePage(1) : Reader.changePage(-1);
        } else if (($(window).height() + $(window).scrollTop()) >= LRR.getDocHeight()) {
            (Reader.mangaMode) ? Reader.changePage(-1) : Reader.changePage(1);
        }
        // spacebar is always forward regardless of reading direction, so it needs to be flipped
        // to always result in a positive offset when it reaches the changePage() logic
        break;
    case 37: // left arrow
        if (e.shiftKey) {
            Reader.changePage("first");
        } else {
            Reader.changePage(-1);
        }
        break;
    case 39: // right arrow
        if (e.shiftKey) {
            Reader.changePage("last");
        } else {
            Reader.changePage(1);
        }
        break;
    case 65: // a
        Reader.changePage(-1);
        break;
    case 68: // d
        Reader.changePage(1);
        break;
    case 70: // f
        Reader.toggleFullScreen();
        break;
    case 72: // h
        Reader.toggleHelp();
        break;
    case 77: // m
        Reader.toggleMangaMode();
        break;
    case 79: // o
        Reader.toggleSettingsOverlay();
        break;
    case 80: // p
        Reader.toggleDoublePageMode();
        break;
    case 81: // q
        Reader.toggleArchiveOverlay();
        break;
    case 82: // r
        if (e.ctrlKey || e.shiftKey || e.metaKey) { break; }
        document.location.href = new LRR.apiURL("/random");
        break;
    case 219: // [
        Reader.readPreviousArchive();
        break;
    case 221: // ]
        Reader.readNextArchive();
        break;
    default:
        break;
    }
};

Reader.handleWheel = function (e) {
    if (window.fscreen.inFullscreen() && !Reader.infiniteScroll) {
        let changePage = 1;
        if (e.originalEvent.deltaY > 0) changePage = -1;
        // In Manga mode, reverse the changePage variable
        // so that we always move forward
        if (!Reader.mangaMode) changePage *= -1;
        Reader.changePage(changePage);
    }
};

Reader.checkFiletypeSupport = function (extension) {
    if ((extension === "rar" || extension === "cbr") && !localStorage.rarWarningShown) {
        localStorage.rarWarningShown = true;
        LRR.toast({
            heading: "This archive seems to be in RAR format!",
            text: "RAR archives might not work properly in LANraragi depending on how they were made. If you encounter errors while reading, consider converting your archive to zip.",
            icon: "warning",
            hideAfter: 23000,
        });
    } else if (extension === "epub" && !localStorage.epubWarningShown) {
        localStorage.epubWarningShown = true;
        LRR.toast({
            heading: "EPUB support in LANraragi is minimal",
            text: "EPUB books will only show images in the Web Reader, and potentially out of order. If you want text support, consider pairing LANraragi with an <a href='https://sugoi.gitbook.io/lanraragi/advanced-usage/external-readers#generic-opds-readers'>OPDS reader.</a>",
            icon: "warning",
            hideAfter: 20000,
            closeOnClick: false,
            draggable: false,
        });
    }
};

Reader.toggleHelp = function () {
    LRR.toast({
        toastId: "readerHelp",
        heading: "Navigation Help",
        text: $("#reader-help").children().first().html(),
        icon: "info",
        hideAfter: 60000,
    });

    return false;
    // all toggable panes need to return false to avoid scrolling to top
};

Reader.updateMetadata = function () {
    const img = $("#img")[0];
    const imageUrl = new URL(img.src);
    const filename = imageUrl.searchParams.get("path");

    const imgDoublePage = $("#img_doublepage")[0];
    const imageUrlDoublePage = new URL(imgDoublePage.src);
    const filenameDoublePage = imageUrlDoublePage.searchParams.get("path");

    if (!filename && Reader.showingSinglePage) {
        Reader.currentPageLoaded = true;
        $("#i3").removeClass("loading");
        return;
    }

    const width = img.naturalWidth;
    const height = img.naturalHeight;
    const widthDoublePage = imgDoublePage.naturalWidth;
    const heightDoublePage = imgDoublePage.naturalHeight;
    const widthView = width + widthDoublePage;

    if (Reader.showingSinglePage) {
        let size = Reader.preloadedSizes[Reader.currentPage];
        if (!size) {
            size = LRR.getImgSize(Reader.pages[Reader.currentPage]);
            Reader.preloadedSizes[Reader.currentPage] = size;
            $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`);
            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB`);
        } else {
            $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`);
            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB`);
        }
    } else {
        let size = Reader.preloadedSizes[Reader.currentPage];
        let sizePre = Reader.preloadedSizes[Reader.currentPage + 1];

        if (!size || !sizePre) {
            size = LRR.getImgSize(Reader.pages[Reader.currentPage]);
            sizePre = LRR.getImgSize(Reader.pages[Reader.currentPage + 1]);
            Reader.preloadedSizes[Reader.currentPage] = size;
            Reader.preloadedSizes[Reader.currentPage + 1] = sizePre;
        }

        const sizeView = size + sizePre;
        $(".file-info").text(`${filename} - ${filenameDoublePage} :: ${widthView} x ${height} :: ${sizeView} KB`);
        $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB - ${filenameDoublePage} :: ${widthDoublePage} x ${heightDoublePage} :: ${sizePre} KB`);
    }

    // Update page numbers in the paginator
    const newVal = Reader.showingSinglePage
        ? Reader.currentPage + 1
        : `${Reader.currentPage + 1} + ${Reader.currentPage + 2}`;
    $(".current-page").each((_i, el) => $(el).html(newVal));

    Reader.currentPageLoaded = true;
    $("#i3").removeClass("loading");
};

Reader.goToPage = function (page) {
    Reader.previousPage = Reader.currentPage;
    Reader.currentPage = Math.min(Reader.maxPage, Math.max(0, +page));
    Reader.showingSinglePage = false;

    if (Reader.infiniteScroll) {
        $("#display img").get(Reader.currentPage).scrollIntoView({ behavior: "smooth" });
    } else {
        $("#img_doublepage").attr("src", "");
        $("#display").removeClass("double-mode");
        if (Reader.doublePageMode && Reader.currentPage > 0
            && Reader.currentPage < Reader.maxPage) {
            // Composite an image and use that as the source
            const img1 = Reader.loadImage(Reader.currentPage);
            const img2 = Reader.loadImage(Reader.currentPage + 1);
            // If w > h on one of the images(widespread), set canvasdata to the first image only
            if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {
                // Depending on whether we were going forward or backward, display img1 or img2
                const wideSrc = Reader.previousPage > Reader.currentPage ? img2.src : img1.src;
                $("#img").attr("src", wideSrc);
                Reader.showingSinglePage = true;
            } else {
                if (Reader.mangaMode) {
                    $("#img").attr("src", img2.src);
                    $("#img_doublepage").attr("src", img1.src);
                } else {
                    $("#img").attr("src", img1.src);
                    $("#img_doublepage").attr("src", img2.src);
                }
                $("#display").addClass("double-mode");
            }
        } else {
            const img = Reader.loadImage(Reader.currentPage);
            $("#img").attr("src", img.src);
            Reader.showingSinglePage = true;
        }

        Reader.preloadImages();
        Reader.applyContainerWidth();

        Reader.currentPageLoaded = false;
        // display overlay if it takes too long to load a page
        setTimeout(() => {
            if (!Reader.currentPageLoaded) { $("#i3").addClass("loading"); }
        }, 500);

        // update full image link
        $("#imgLink").attr("href", Reader.pages[Reader.currentPage]);

        // scroll to top
        window.scrollTo(0, 0);
    }

    Reader.updateProgress();
};

Reader.updateProgress = function () {
    // Send an API request to update progress on the server
    if (Reader.trackProgressLocally) {
        localStorage.setItem(`${Reader.id}-reader`, Reader.currentPage + 1);
    } else {
        Server.callAPI(`/api/archives/${Reader.id}/progress/${Reader.currentPage + 1}`, "PUT", null, "Error updating reading progress!", null);
    }
};

Reader.preloadImages = function () {
    let preloadNext = Reader.preloadCount;
    let preloadPrev = 1;

    if (Reader.doublePageMode) { preloadNext *= 2; preloadPrev *= 2; }

    for (let i = 1; i <= preloadNext; i++) {
        if (Reader.currentPage + i > Reader.maxPage) { break; }
        Reader.loadImage(Reader.currentPage + i);
    }
    for (let i = 1; i <= preloadPrev; i++) {
        if (Reader.currentPage - i < 0) { break; }
        Reader.loadImage(Reader.currentPage - i);
    }
};

Reader.loadImage = function (index) {
    const src = Reader.pages[index];

    if (!Reader.preloadedImg[src]) {
        const img = new Image();
        img.src = src;
        Reader.preloadedImg[src] = img;
        if (!Reader.preloadedSizes[index]) {
            LRR.getImgSizeAsync(src).done((data, textStatus, request) => {
                const size = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
                Reader.preloadedSizes[index] = size;
            });
        }
    }

    return Reader.preloadedImg[src];
};

Reader.toggleFitMode = function (e) {
    // possible options: fit-container, fit-width, fit-height
    Reader.fitMode = localStorage.fitMode = e.target.id;
    $("#fit-mode input").removeClass("toggled");
    $(e.target).addClass("toggled");

    if (Reader.fitMode === "fit-container") {
        $("#container-width").show();
    } else {
        $("#container-width").hide();
    }
    Reader.applyContainerWidth();
};

Reader.registerContainerWidth = function () {
    // Examples of allowed values: 1200, 1200px, 90%
    // Default value: 1200px
    const raw = $("#container-width-input").val().trim();
    if (!raw) { // fall back to default
        delete Reader.containerWidth;
        localStorage.removeItem("containerWidth");
    } else {
        let value, type;

        [, value, type] = /^(\d+)(px|%)?$/.exec(raw);
        value = value || 1200;
        type = type || "px";

        Reader.containerWidth = localStorage.containerWidth = `${value}${type}`;
    }
    Reader.applyContainerWidth();
};

Reader.applyContainerWidth = function () {
    $(".reader-image, .sni").attr("style", "");

    if (Reader.fitMode === "fit-height") {
        // Fit to height forces the image to 90% of visible screen height.
        // If the header is hidden, or if we're in infinite scrolling, then the image
        // can take up to 98% of visible screen height because there's more free space
        const height = localStorage.hideHeader === "true" || Reader.infiniteScroll ? 98 : 90;
        $(".reader-image").attr("style", `max-height: ${height}vh;`);
        $(".sni").attr("style", "width: fit-content; width: -moz-fit-content");
    } else if (Reader.fitMode === "fit-width") {
        $(".reader-image").attr("style", "width: 100%;");
        $(".sni").attr("style", "max-width: 98%");
    } else if (Reader.containerWidth) {
        // If the user defined a custom width, then we can fall back to that one
        $(".sni").attr("style", `max-width: ${Reader.containerWidth}`);
        $(".reader-image").attr("style", "width: 100%");
    } else if (!Reader.showingSinglePage) {
        // Otherwise, if we are showing two pages we can override the default width
        $(".sni").attr("style", "max-width: 90%");
    } else {
        // Finally, fall back to 1200px width if none of the above matches
        $(".sni").attr("style", "max-width: 1200px");
    }
};

Reader.registerPreload = function () {
    Reader.preloadCount = +$("#preload-input").val().trim() || +localStorage.preloadCount || 2;
    $("#preload-input").val(Reader.preloadCount);
    localStorage.preloadCount = Reader.preloadCount;
};

Reader.toggleDoublePageMode = function () {
    if (Reader.infiniteScroll) { return; }
    Reader.doublePageMode = localStorage.doublePageMode = !Reader.doublePageMode;
    $("#toggle-double-mode input").toggleClass("toggled");
    Reader.goToPage(Reader.currentPage);
};

Reader.toggleMangaMode = function () {
    if (Reader.infiniteScroll) { return false; }
    Reader.mangaMode = localStorage.mangaMode = !Reader.mangaMode;
    $("#toggle-manga-mode input").toggleClass("toggled");
    $(".reading-direction").toggleClass("fa-arrow-left fa-arrow-right");
    if (!Reader.showingSinglePage) { Reader.goToPage(Reader.currentPage); }

    return false;
};

Reader.toggleHeader = function () {
    if (Reader.infiniteScroll) { return false; }
    localStorage.hideHeader = $("#i2").is(":visible");
    $("#toggle-header input").toggleClass("toggled");
    $("#i2").toggle();
    Reader.applyContainerWidth();
    return false;
};

Reader.toggleProgressTracking = function () {
    Reader.ignoreProgress = localStorage.ignoreProgress = !Reader.ignoreProgress;
    $("#toggle-progress input").toggleClass("toggled");
};

Reader.toggleInfiniteScroll = function () {
    Reader.infiniteScroll = localStorage.infiniteScroll = !Reader.infiniteScroll;
    $("#toggle-infinite-scroll input").toggleClass("toggled");
    window.location.reload();
};

Reader.toggleOverlayByDefault = function () {
    Reader.overlayByDefault = localStorage.showOverlayByDefault = !Reader.showOverlayByDefault;
    $("#toggle-overlay input").toggleClass("toggled");
};

Reader.toggleSettingsOverlay = function () {
    return LRR.toggleOverlay("#settingsOverlay");
};

Reader.toggleArchiveOverlay = function () {
    return LRR.toggleOverlay("#archivePagesOverlay");
};

Reader.toggleFullScreen = function () {
    if (window.fscreen.inFullscreen()) {
        // if already full screen; exit
        window.fscreen.exitFullscreen();
        Reader.handleFullScreen();
    } else {
        // else go fullscreen
        Reader.handleFullScreen(true);
    }
};

Reader.handleFullScreen = function (enableFullscreen = false) {
    if (window.fscreen.inFullscreen() || enableFullscreen === true) {
        if ($("body").hasClass("infinite-scroll")) {
            $("div#i3").addClass("fullscreen-infinite");
        } else {
            $("div#i3").addClass("fullscreen");
        }
        // ensure in every case, the correct fullscreen element is binded.
        window.fscreen.requestFullscreen($("div#i3").get(0));
    } else if ($("body").hasClass("infinite-scroll")) {
        $("div#i3").removeClass("fullscreen-infinite");
    } else {
        $("div#i3").removeClass("fullscreen");
    }
};

Reader.initializeArchiveOverlay = function () {
    if ($("#archivePagesOverlay").attr("loaded") === "true") {
        return;
    }

    $("#extract-spinner").hide();

    // For each link in the pages array, craft a div and jam it in the overlay.
    for (let index = 0; index < Reader.pages.length; ++index) {
        const page = index + 1;

        const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        const thumbnailUrl = new LRR.apiURL(`/api/archives/${Reader.id}/thumbnail?page=${page}`);
        const thumbnail = `
            <div class='${thumbCss} quick-thumbnail' page='${index}' style='display: inline-block; cursor: pointer'>
                <span class='page-number'>Page ${page}</span>
                <img src="${thumbnailUrl}" id="${index}_thumb" />
                <i id="${index}_spinner" class="fa fa-4x fa-circle-notch fa-spin ttspinner" style="display:flex;justify-content: center; align-items: center;"></i>
            </div>`;

        $("#archivePagesOverlay").append(thumbnail);
    }
    $("#archivePagesOverlay").attr("loaded", "true");

    // Queue a single minion job for thumbnails and check on its progress regularly
    const thumbProgress = function (notes) {
        if (notes.total_pages === undefined) { return; }

        // Look at all the numbered keys in notes, aka notes.1, notes.2..
        for (let i = 1; i <= notes.total_pages; i++) {

            if (notes.hasOwnProperty(i) && notes[i] === "processed") {
                const index = i - 1;
                // If the spinner is still visible, update the thumbnail
                if ($(`#${index}_spinner`).attr("loaded") !== "true") {
                    // Set image source to the thumbnail
                    const thumbnailUrl = new LRR.apiURL(`/api/archives/${Reader.id}/thumbnail?page=${i}&cachebust=${Date.now()}`);
                    $(`#${index}_thumb`).attr("src", thumbnailUrl);
                    $(`#${index}_spinner`).attr("loaded", true);
                    $(`#${index}_spinner`).hide();
                }
            }
        }
    };

    fetch(new LRR.apiURL(`/api/archives/${Reader.id}/files/thumbnails`), { 
        method: "POST",
        mode: 'same-origin',
        credentials: 'same-origin'
    })
        .then((response) => {
            if (response.status === 200) {
                // Thumbnails are already generated, there's nothing to do. Very nice!
                $(".ttspinner").hide();
                return;
            }
            if (response.status === 202) {
                // Check status and update progress
                response.json().then((data) => Server.checkJobStatus(
                    data.job,
                    false,
                    (data) => thumbProgress(data.notes), // call progress callback one last time to ensure all thumbs are loaded
                    () => LRR.showErrorToast("The page thumbnailing job didn't conclude properly. Your archive might be corrupted."),
                    thumbProgress,
                ));
            }
        });
};

Reader.changePage = function (targetPage) {
    let destination;
    if (targetPage === "first") {
        if (Reader.currentPage === 0) {
            return Reader.readPreviousArchive();
        }
        destination = Reader.mangaMode ? Reader.maxPage : 0;
    } else if (targetPage === "last") {
        if (Reader.currentPage === Reader.maxPage) {
            return Reader.readNextArchive();
        }
        destination = Reader.mangaMode ? 0 : Reader.maxPage;
    } else {
        let offset = targetPage;
        if (Reader.doublePageMode && !Reader.showingSinglePage && Reader.currentPage > 0) {
            offset *= 2;
        }
        destination = Reader.currentPage + (Reader.mangaMode ? -offset : offset);
    }
    if (destination < 0) {
        return Reader.readPreviousArchive();
    } else if (destination > Reader.maxPage) {
        return Reader.readNextArchive();
    } else {
        return Reader.goToPage(destination);
    }
};

Reader.handlePaginator = function () {
    switch (this.getAttribute("value")) {
    case "outer-left":
        Reader.changePage("first");
        break;
    case "left":
        Reader.changePage(-1);
        break;
    case "right":
        Reader.changePage(1);
        break;
    case "outer-right":
        Reader.changePage("last");
        break;
    default:
        break;
    }
};

Reader.loadPreviousDatatablesArchives = function () {
    if (localStorage.getItem('previousArchiveIds')) {
        return JSON.parse(localStorage.getItem('previousArchiveIds'));
    }
    const currentPage = parseInt(localStorage.getItem('currDatatablesPage') || '1', 10);
    if (currentPage <= 1) return null;
    const prevDTPage = currentPage - 1;
    return Reader.loadDatatablesArchives(prevDTPage);
}

Reader.loadNextDatatablesArchives = function () {
    if (localStorage.getItem('nextArchiveIds')) {
        return JSON.parse(localStorage.getItem('nextArchiveIds'));
    }
    const currentPage = parseInt(localStorage.getItem('currDatatablesPage') || '1', 10);
    const nextDTPage = currentPage + 1;
    return Reader.loadDatatablesArchives(nextDTPage);
}

// TODO: this can probably be refactored to Reader.changeArchive like in Reader.changePage
// but also it might be fine as is for readability
// when at start or end of list, perform list shifting
// if no previous/next list is available, this means we're at the first or last archive
Reader.readPreviousArchive = function () {
    if (window.fscreen.inFullscreen()) {
        return;
    }
    if (Reader.archiveIds.length > 0) {
        let previousArchiveId;
        if (Reader.archiveIndex === 0) {
            const previousArchiveIdsJson = localStorage.getItem('previousArchiveIds');
            const currArchiveIdsJson = localStorage.getItem('currArchiveIds');
            if (previousArchiveIdsJson && currArchiveIdsJson) {
                const previousArchiveIds = JSON.parse(previousArchiveIdsJson);
                localStorage.removeItem('previousArchiveIds');
                localStorage.setItem('currArchiveIds', previousArchiveIdsJson);
                localStorage.setItem('nextArchiveIds', currArchiveIdsJson);
                previousArchiveId = previousArchiveIds[previousArchiveIds.length - 1];
                const currentPage = parseInt(localStorage.getItem('currDatatablesPage') || '1', 10);
                localStorage.setItem('currDatatablesPage', currentPage - 1);
            } else {
                LRR.toast({"text": "This is the first archive"});
                return;
            }
        } else {
            previousArchiveId = Reader.archiveIds[Reader.archiveIndex - 1];
        }
        const newUrl = new LRR.apiURL(`/reader?id=${previousArchiveId}`).toString();
        history.replaceState(null, '', newUrl);
        window.location.href = newUrl;
    } else {
        LRR.toast({"text": "This is the first archive"});
    }
}

Reader.readNextArchive = function () {
    if (window.fscreen.inFullscreen()) {
        return;
    }
    if (Reader.archiveIds.length > 0) {
        let nextArchiveId;
        if (Reader.archiveIndex === Reader.archiveIds.length - 1) {
            const nextArchiveIdsJson = localStorage.getItem('nextArchiveIds');
            const currArchiveIdsJson = localStorage.getItem('currArchiveIds');
            if (nextArchiveIdsJson && currArchiveIdsJson) {
                const nextArchiveIds = JSON.parse(nextArchiveIdsJson);
                localStorage.removeItem('nextArchiveIds');
                localStorage.setItem('currArchiveIds', nextArchiveIdsJson);
                localStorage.setItem('previousArchiveIds', currArchiveIdsJson);
                nextArchiveId = nextArchiveIds[0];
                const currentPage = parseInt(localStorage.getItem('currDatatablesPage') || '1', 10);
                localStorage.setItem('currDatatablesPage', currentPage + 1);
            } else {
                LRR.toast({"text": "This is the last archive"});
                return;
            }
        } else {
            nextArchiveId = Reader.archiveIds[Reader.archiveIndex + 1];
        }
        const newUrl = new LRR.apiURL(`/reader?id=${nextArchiveId}`).toString();
        history.replaceState(null, '', newUrl);
        window.location.href = newUrl;
    } else {
        LRR.toast({"text": "This is the last archive"});
    }
}

// TODO: this needs to be checked.
/**
 * Loads the archives for the given datatables page.
 * This is to support archive navigation between datatables pages; in order to do that 
 * we need to know everything about the filter used to produce the datatables pages.
 * 
 * E.g., if we have two filters F, G, then the archives loaded under F on page 3 may be
 * different from the archives loaded under G on page 3.
 * 
 * We would also need to store the filter somewhere (localStorage), so it survives page
 * changes, history rewrites, etc.
 * 
 * @param {number} datatablesPage - The page number to load.
 * @returns {Array<string>} - The list of archive IDs
 */
Reader.loadDatatablesArchives = function (datatablesPage) {
    const indexSearchQuery = localStorage.getItem('currentSearch') || '';
    const indexSelectedCategory = localStorage.getItem('selectedCategory') || '';
    const datatablesPageSize = parseInt(localStorage.getItem('datatablesPageSize') || '100', 10);
    const indexSort = localStorage.getItem('indexSort') || '0';
    const indexOrder = localStorage.getItem('indexOrder') || 'asc';
    let searchUrlStr = `/api/search?start=${(datatablesPage-1) * datatablesPageSize}`;
    if (indexSearchQuery) searchUrlStr += `&filter=${encodeURIComponent(indexSearchQuery)}`;
    if (indexSelectedCategory) searchUrlStr += `&category=${encodeURIComponent(indexSelectedCategory)}`;

    // See IndexTable.drawCallback
    if (indexSort && indexSort !== '0') {
        const sortby = indexSort >= 1 ? localStorage[`customColumn${indexSort}`] || `Header ${indexSort}` : "title";
        searchUrlStr += `&sortby=${sortby}`;
        searchUrlStr += `&order=${indexOrder}`;
    }
    const searchUrl = new LRR.apiURL(searchUrlStr);
    console.debug("Using Search API URL:", searchUrl.toString());
    let archives = null;

    // See the result of this API here to get an idea of what the response looks like:
    // tools/Documentation/api-documentation/search-api.md
    $.ajax({
        url: searchUrl.toString(),
        type: 'GET',
        async: false,
        dataType: 'json',
        success: function(data) {
            if (data && data.data && data.data.length > 0) {
                archives = data.data.map(archive => archive.arcid);
            }
        },
        error: function(xhr, _status, error) {
            console.error('Failed to fetch archive list:', error);
            console.error('Response:', xhr.responseText);
        }
    });
    return archives;
}

// TODO: this needs to be checked too.
Reader.returnToIndex = function () {
    const indexSearchQuery = localStorage.getItem('currentSearch') || '';
    const indexSelectedCategory = localStorage.getItem('selectedCategory') || '';
    const indexSort = localStorage.getItem('indexSort') || 0;
    const indexOrder = localStorage.getItem('indexOrder') || 'asc';
    const currentPage = localStorage.getItem('currDatatablesPage') || '1';
    let returnUrl = '/';
    const params = new URLSearchParams();
    
    if (indexSearchQuery) params.append('q', indexSearchQuery);
    if (indexSelectedCategory) params.append('c', indexSelectedCategory);
    if (indexSort) params.append('sort', indexSort);
    if (indexOrder !== 'asc') params.append('sortdir', indexOrder);
    if (currentPage !== '1') params.append('p', currentPage);
    
    const queryString = params.toString();
    if (queryString) {
        returnUrl += '?' + queryString;
    }
    
    window.location.href = new LRR.apiURL(returnUrl).toString();
}
