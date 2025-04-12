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

Reader.initializeAll = function () {
    Reader.initializeSettings();
    Reader.applyContainerWidth();
    Reader.registerPreload();
    document.documentElement.style.scrollBehavior = 'smooth';

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
    $(document).on("click.toggle-full-screen", "#toggle-full-screen", () => Reader.handleFullScreen(true));
    $(document).on("click.toggle-archive-overlay", "#toggle-archive-overlay", Reader.toggleArchiveOverlay);
    $(document).on("click.toggle-settings-overlay", "#toggle-settings-overlay", Reader.toggleSettingsOverlay);
    $(document).on("click.toggle-help", "#toggle-help", Reader.toggleHelp);
    $(document).on("click.toggle-bookmark", ".toggle-bookmark", Reader.toggleBookmark);
    $(document).on("click.regenerate-archive-cache", "#regenerate-cache", () => {
        window.location.href = new LRR.apiURL(`/reader?id=${Reader.id}&force_reload`);
    });
    $(document).on("click.edit-metadata", "#edit-archive", () => LRR.openInNewTab(new LRR.apiURL(`/edit?id=${Reader.id}`)));
    $(document).on("click.delete-archive", "#delete-archive", () => {
        LRR.closeOverlay();
        LRR.showPopUp({
            text: I18N.ConfirmArchiveDeletion,
            icon: "warning",
            showCancelButton: true,
            focusConfirm: false,
            confirmButtonText: I18N.ConfirmYes,
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
        const categoryId = $("#category").val();
        Reader.addCategoryBadge( categoryId );

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
        Server.removeArchiveFromCategory(Reader.id, $(e.target).attr("data-id"));
        $(e.target).closest(".gt").remove();
        // Turn OFF the bookmark icon
        if (catId == localStorage.bookmarkCategoryId) {
            $(".toggle-bookmark")
                .removeClass("fas fa-bookmark")
                .addClass("far fa-bookmark");
        }
    });
    $(document).on("click.set-thumbnail", "#set-thumbnail", () => Server.callAPI(`/api/archives/${Reader.id}/thumbnail?page=${Reader.currentPage + 1}`,
        "PUT", I18N.ReaderUpdateThumbnail(Reader.currentPage), I18N.ReaderUpdateThumbnailError, null));

    $(document).on("click.thumbnail", ".quick-thumbnail", (e) => {
        LRR.closeOverlay();
        const pageNumber = +$(e.target).closest("div[page]").attr("page");
        Reader.goToPage(pageNumber);
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

    // Remove the "new" tag with an api call
    Server.callAPI(`/api/archives/${Reader.id}/isnew`, "DELETE", null, I18N.ReaderErrorClearingNew, null);

    // Get basic metadata
    Server.callAPI(`/api/archives/${Reader.id}/metadata`, "GET", null, I18N.ServerInfoError,
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

    // Fetch "bookmark" category ID and setup icon
    Reader.loadBookmarkStatus();
};

/**
 * Adds a removable category flag to the categories section within archive overview.
 */
Reader.addCategoryBadge = function ( categoryId ) {
    const categoryName = $(`#category option[value="${categoryId}"]`).text();
    const url = new LRR.apiURL(`/?c=${categoryId}`);
    const html = `<div class="gt" style="font-size:14px; padding:4px">
        <a href="${url}">
        <span class="label">${categoryName}</span>
        <a href="#" class="remove-category" data-id="${categoryId}"
            style="margin-left:4px; margin-right:2px">×</a>
    </a>`;
    $("#archive-categories").append(html);
}

Reader.removeCategoryBadge = function ( categoryId ) {
    $(`#archive-categories a.remove-category[data-id="${categoryId}"]`).closest(".gt").remove();
}

Reader.loadImages = function () {
    Server.callAPI(`/api/archives/${Reader.id}/files?force=${Reader.force}`, "GET", null, I18N.ReaderArchiveError,
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
            $("#display").append("<h2>"+I18N.ReaderArchiveError+"</h2>");
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
    case 32: { // spacebar
    //Break if overlay is open, browser detects repeatkey but not held, or webtoon gallery and in infinite scroll
    if ($(".page-overlay").is(":visible") || e.repeat || (Reader.infiniteScroll && Reader.tags?.includes("webtoon"))) break;
    e.preventDefault();

    const scrollDown = !e.shiftKey;
    const h = window.innerHeight;
    const scrollTop = window.scrollY;
    const images = document.querySelectorAll(".reader-image");
    const img = [...images].find(i => {
        const r = i.getBoundingClientRect();
        return r.top <= h && r.bottom >= 0;
    });

    if (!img) {
        (images[scrollDown ? 0 : images.length - 1] || images[0])?.scrollIntoView();
        break;
    }

    const r = img.getBoundingClientRect();
    const imgBottom = r.bottom + scrollTop;
    const newPos = scrollTop + (scrollDown ? h : -h);

    if ((scrollDown && scrollTop + h > imgBottom - h * 0.2) ||
        (!scrollDown && scrollTop < r.top + scrollTop + h * 0.2)) {
        const imgIndex = [...images].indexOf(img);
        const nextImg = images[imgIndex + (scrollDown ? 1 : -1)];
        nextImg?.scrollIntoView() || 
        (!Reader.infiniteScroll && Reader.changePage(scrollDown ? 1 : -1));
    } else {
        window.scrollTo({
            top: scrollDown ? 
                Math.min(newPos, imgBottom - h) : 
                Math.max(newPos, r.top + scrollTop)
        });
    }
    break;
}
    case 37: // left arrow
        Reader.changePage(-1);
        break;
    case 39: // right arrow
        Reader.changePage(1);
        break;
    case 65: // a
        Reader.changePage(-1);
        break;
    case 66: // b
        Reader.toggleBookmark(e);
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
    }
};

Reader.toggleHelp = function () {
    LRR.toast({
        toastId: "readerHelp",
        heading: I18N.ReaderNavHelp,
        text: $("#reader-help").children().first().html(),
        icon: "info",
        hideAfter: 60000,
    });

    return false;
    // all toggable panes need to return false to avoid scrolling to top
};

Reader.toggleBookmark = function(e) {
    e.preventDefault();
    if ( !localStorage.getItem("bookmarkCategoryId") ) {
        return;
    };

    if (!LRR.isUserLogged()) {
        LRR.toast({
            text: I18N.LoginRequired(new LRR.apiURL("/login")),
            icon: "warning",
            hideAfter: 5000,
        });
        return;
    }

    if ($(".toggle-bookmark").hasClass("fas fa-bookmark")) {
        // Remove from category
        Server.removeArchiveFromCategory(Reader.id, localStorage.getItem("bookmarkCategoryId"));
        Reader.removeCategoryBadge( localStorage.getItem("bookmarkCategoryId") );
        $(".toggle-bookmark")
            .removeClass("fas fa-bookmark")
            .addClass("far fa-bookmark");
    } else {
        // Add to category
        Server.addArchiveToCategory(Reader.id, localStorage.getItem("bookmarkCategoryId"));
        Reader.addCategoryBadge( localStorage.getItem("bookmarkCategoryId") );
        $(".toggle-bookmark")
            .removeClass("far fa-bookmark")
            .addClass("fas fa-bookmark");
    }
}

// dynamically add bookmark icon if bookmark link is configured.
Reader.loadBookmarkStatus = function() {
    Server.loadBookmarkCategoryId().then(
        category_id => {
            if ( !LRR.bookmarkLinkConfigured() ) {
                return;
            }
            fetch(new LRR.apiURL(`/api/categories/${category_id}`))
                .then(response => response.json()).then(categoryData => {
                    const isBookmarked = categoryData.archives.includes(Reader.id);
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
                    })
                })
        }
    )
}

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
        $("#display img").get(Reader.currentPage).scrollIntoView();
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
        Server.callAPI(`/api/archives/${Reader.id}/progress/${Reader.currentPage + 1}`, "PUT", null, I18N.ReaderErrorProgress, null);
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
                <span class='page-number'>${I18N.ReaderPage(page)}</span>
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

    fetch(new LRR.apiURL(`/api/archives/${Reader.id}/files/thumbnails`), { method: "POST" })
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
                    () => LRR.showErrorToast(I18N.ThumbJobError),
                    thumbProgress,
                ));
            }
        });
};

Reader.changePage = function(targetPage) {
    // Sync position if in infinite scroll mode
    if (Reader.infiniteScroll) {
        const images = [...document.querySelectorAll('.reader-image')];
        const midViewport = window.innerHeight / 2;
        for (let i = 0; i < images.length; i++) {
            const rect = images[i].getBoundingClientRect();
            if (rect.top <= midViewport && rect.bottom >= midViewport) {
                Reader.currentPage = i;
                break;
            }
        }
    }
    let destination;
    if (targetPage === "first") {
        destination = Reader.mangaMode ? Reader.maxPage : 0;
    } else if (targetPage === "last") {
        destination = Reader.mangaMode ? 0 : Reader.maxPage;
    } else {
        let offset = targetPage;
        if (Reader.doublePageMode && !Reader.showingSinglePage && Reader.currentPage > 0) {
            offset *= 2;
        }
        destination = Reader.currentPage + (Reader.mangaMode ? -offset : offset);
    }
    Reader.goToPage(destination);
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
