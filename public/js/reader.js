// functions to navigate in reader with the keyboard.
// also handles the thumbnail archive explorer.

const Reader = {};
Reader.previousPage = -1;
Reader.showingSinglePage = true;
Reader.preloadedImg = {};
Reader.preloadedSizes = {};

Reader.initializeAll = function () {
    Reader.maxPage = Reader.pages.length - 1;
    Reader.initializeSettings();

    // bind events to DOM
    $(document).on("keyup", Reader.handleShortcuts);

    $(document).on("click.toggle_fit_mode", "#fit-mode input", Reader.toggleFitMode);
    $(document).on("click.toggle_double_mode", "#toggle-double-mode input", Reader.toggleDoublePageMode);
    $(document).on("click.toggle_manga_mode", "#toggle-manga-mode input, .reading-direction", Reader.toggleMangaMode);
    $(document).on("click.toggle_header", "#toggle-header input", Reader.toggleHeader);
    $(document).on("click.toggle_progress", "#toggle-progress input", Reader.toggleProgressTracking);
    $(document).on("click.toggle_infinite_scroll", "#toggle-infinite-scroll input", Reader.toggleInfiniteScroll);
    $(document).on("submit.container_width", "#container-width-input", Reader.registerContainerWidth);
    $(document).on("click.container_width", "#container-width-apply", Reader.registerContainerWidth);
    $(document).on("submit.preload", "#preload-input", Reader.registerPreload);
    $(document).on("click.preload", "#preload-apply", Reader.registerPreload);
    $(document).on("click.pagination_change_pages", ".page-link", Reader.handlePaginator);

    $(document).on("click.close_overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.toggle_archive_overlay", "#toggle-archive-overlay", Reader.toggleArchiveOverlay);
    $(document).on("click.toggle_settings_overlay", "#toggle-settings-overlay", Reader.toggleSettingsOverlay);
    $(document).on("click.toggle_help", "#toggle-help", Reader.toggleHelp);
    $(document).on("click.regenerate_thumbnail", "#regenerate-thumbnail", Reader.regenerateThumbnail);
    $(document).on("click.regenerate_archive_cache", "#regenerate-cache", () => {
        window.location.href = `./reader?id=${Reader.id}&force_reload=1`;
    });
    $(document).on("click.edit_metadata", "#edit-archive", () => LRR.openInNewTab(`./edit?id=${Reader.id}`));
    $(document).on("click.add_category", "#add-category", () => Server.addArchiveToCategory(Reader.id, $("#category").val()));

    // check and display warnings for unsupported filetypes
    Reader.checkFiletypeSupport();

    // Use localStorage progress value instead of the server one if needed
    if (Reader.trackProgressLocally) {
        Reader.progress = localStorage.getItem(`${Reader.id}-reader`) - 1 || 0;
    }

    // remove the "new" tag with an api call
    Server.callAPI(`/api/archives/${Reader.id}/isnew`, "DELETE", null, "Error clearing new flag! Check Logs.", null);

    Reader.registerPreload();

    Reader.infiniteScroll = localStorage.infiniteScroll === "true" || false;
    $(Reader.infiniteScroll ? "#infinite-scroll-on" : "#infinite-scroll-off").addClass("toggled");

    $(document).on("click.thumbnail", ".quick-thumbnail", (e) => {
        LRR.closeOverlay();
        const pageNumber = +$(e.target).closest("div[page]").attr("page");
        if (Reader.infiniteScroll) {
            $("#display img").get(pageNumber).scrollIntoView({ behavior: "smooth" });
        } else {
            Reader.goToPage(pageNumber);
        }
    });

    if (Reader.infiniteScroll) {
        Reader.initInfiniteScrollView();
        return;
    }

    // all these init values need to be after the infinite loader check
    $(document).on("click.imagemap_change_pages", "#Map area", Reader.handlePaginator);
    $(window).on("resize", Reader.updateImagemap);

    let params = new URLSearchParams(window.location.search);

    // initialize current page and bind popstate
    $(window).on("popstate", () => {
        params = new URLSearchParams(window.location.search);
        if (params.has("p")) {
            const paramsPage = +params.get("p");
            Reader.goToPage(paramsPage - 1, true);
        }
    });

    Reader.currentPage = (+params.get("p") || 1) - 1;
    // when there's no parameter, null is coerced to 0 so it becomes -1
    Reader.currentPage = Reader.currentPage || (
        !Reader.ignoreProgress && Reader.progress < Reader.maxPage
            ? Reader.progress
            : 0
    );
    // Choices in order for page picking:
    // * p is in parameters and is not the first page
    // * progress is tracked and is not the last page
    // * first page
    // This allows for bookmarks to trump progress

    $(".current-page").each((_i, el) => $(el).html(Reader.currentPage + 1));
    Reader.goToPage(Reader.currentPage);
};

Reader.initializeSettings = function () {
    // Initialize settings and button toggles
    // Has legacy localstorage options from before the refactoring, these can be removed later on
    if (localStorage.hideHeader === "true" || localStorage.hidetop === "true" || false) {
        $("#hide-header").addClass("toggled");
        $("#i2").hide();
    } else {
        $("#show-header").addClass("toggled");
    }

    Reader.mangaMode = localStorage.mangaMode === "true" || localStorage.righttoleft === "true" || false;
    if (Reader.mangaMode) {
        $("#manga-mode").addClass("toggled");
        $(".reading-direction").toggleClass("fa-arrow-left fa-arrow-right");
    } else {
        $("#normal-mode").addClass("toggled");
    }

    Reader.doublePageMode = localStorage.doublePageMode === "true" || localStorage.doublepage === "true" || false;
    Reader.doublePageMode ? $("#double-page").addClass("toggled") : $("#single-page").addClass("toggled");

    Reader.ignoreProgress = localStorage.ignoreProgress === "true" || localStorage.nobookmark === "true" || false;
    Reader.ignoreProgress ? $("#untrack-progress").addClass("toggled") : $("#track-progress").addClass("toggled");

    if (localStorage.forcefullwidth === "true" || localStorage.fitMode === "fit-width") {
        Reader.fitMode = "fit-width";
        $("#fit-width").addClass("toggled");
        $("#container-width").hide();
    } else if (localStorage.scaletoview === "true" || localStorage.fitMode === "fit-height") {
        Reader.fitMode = "fit-height";
        $("#fit-height").addClass("toggled");
        $("#container-width").hide();
    } else {
        Reader.fitMode = "fit-container";
        $("#fit-container").addClass("toggled");
    }

    Reader.containerWidth = localStorage.containerWidth || +localStorage.containerwidth;
    if (Reader.containerWidth) { $("#container-width-input").val(Reader.containerWidth); }

    // remove legacy options
    localStorage.removeItem("doublepage");
    localStorage.removeItem("righttoleft");
    localStorage.removeItem("hidetop");
    localStorage.removeItem("nobookmark");
    localStorage.removeItem("forcefullwidth");
    localStorage.removeItem("scaletoview");
    localStorage.removeItem("containerwidth");
};

Reader.initInfiniteScrollView = function () {
    $("body").addClass("infinite-scroll");
    $("#Map").remove();
    $(".reader-image").first().attr("src", Reader.pages[0]);

    Reader.pages.slice(1).forEach((source) => {
        const img = new Image();
        img.src = source;
        $(img).addClass("reader-image");
        $("#display").append(img);
    });

    $("#i3").removeClass("loading");
    $(document).on("click.infinite_scroll_map", "#display .reader-image", () => Reader.changePage(1));
    Reader.applyContainerWidth();
};

Reader.handleShortcuts = function (e) {
    if (e.target.tagName === "INPUT") {
        return;
    }
    switch (e.keyCode) {
    case 8: // backspace
        document.location.href = "/";
        break;
    case 27: // escape
        LRR.closeOverlay();
        break;
    case 32: // spacebar
        if ($(".page-overlay").is(":visible")) { break; }
        if (e.originalEvent.getModifierState("Shift") && (window.scrollY) === 0) {
            (Reader.mangaMode) ? Reader.changePage(1) : Reader.changePage(-1);
        } else if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
            (Reader.mangaMode) ? Reader.changePage(-1) : Reader.changePage(1);
        }
        // spacebar is always forward regardless of reading direction, so it needs to be flipped
        // to always result in a positive offset when it reaches the changePage() logic
        break;
    case 37: // left arrow
    case 65: // a
        Reader.changePage(-1);
        break;
    case 39: // right arrow
    case 68: // d
        Reader.changePage(1);
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
        document.location.href = "/random";
        break;
    default:
        break;
    }
};

Reader.checkFiletypeSupport = function () {
    if ((Reader.filename.endsWith(".rar") || Reader.filename.endsWith(".cbr")) && !localStorage.rarWarningShown) {
        localStorage.rarWarningShown = true;
        $.toast({
            showHideTransition: "slide",
            position: "top-left",
            loader: false,
            heading: "This archive seems to be in RAR format!",
            text: "RAR archives might not work properly in LANraragi depending on how they were made. If you encounter errors while reading, consider converting your archive to zip.",
            hideAfter: false,
            icon: "warning",
        });
    } else if (Reader.filename.endsWith(".epub") && !localStorage.epubWarningShown) {
        localStorage.epubWarningShown = true;
        $.toast({
            showHideTransition: "slide",
            position: "top-left",
            loader: false,
            heading: "EPUB support in LANraragi is minimal",
            text: "EPUB books will only show images in the Web Reader. If you want text support, consider pairing LANraragi with an <a href='https://sugoi.gitbook.io/lanraragi/advanced-usage/external-readers#generic-opds-readers'>OPDS reader.</a>",
            hideAfter: false,
            icon: "warning",
        });
    }
};

Reader.toggleHelp = function () {
    const existingToast = $(".navigation-help-toast:visible");
    if (existingToast.length) {
        // ugly hack: this is an abandoned plugin, we should be using something like toastr
        existingToast.closest(".jq-toast-wrap").find(".close-jq-toast-single").click();
        return false;
    }

    $.toast({
        heading: "Navigation Help",
        text: `
        <div class="navigation-help-toast">
            You can navigate between pages using:
            <ul>
                <li>The arrow icons</li>
                <li>The a/d keys</li>
                <li>Your keyboard arrows (and the spacebar)</li>
                <li>Touching the left/right side of the image.</li>
            </ul>
            <br>Other keyboard shortcuts:
            <ul>
                <li>M: toggle manga mode (right-to-left reading)</li>
                <li>O: show advanced reader options.</li>
                <li>P: toggle double page mode</li>
                <li>Q: bring up the thumbnail index and archive options.</li>
                <li>R: open a random archive.</li>
            </ul>
            <br>To return to the archive index, touch the arrow pointing down or use Backspace.
        </div>
        `,
        hideAfter: false,
        position: "top-left",
        icon: "info",
    });

    return false;
    // all toggable panes need to return false to avoid scrolling to top
};

Reader.updateMetadata = function () {
    const img = $("#img")[0];
    const imageUrl = new URL(img.src);
    const filename = imageUrl.searchParams.get("path");
    if (!filename && Reader.showingSinglePage) {
        Reader.currentPageLoaded = true;
        $("#i3").removeClass("loading");
        return;
    }

    const width = img.naturalWidth;
    const height = img.naturalHeight;

    if (Reader.showingSinglePage) {
        // HEAD request to get filesize
        let size = Reader.preloadedSizes[Reader.currentPage];
        if (!size) {
            $.ajax({
                url: Reader.pages[Reader.currentPage],
                type: "HEAD",
                success: (data, textStatus, request) => {
                    size = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
                    Reader.preloadedSizes[Reader.currentPage] = size;
                    $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`);
                },
            });
        } else { $(".file-info").text(`${filename} :: ${width} x ${height} :: ${size} KB`); }
    } else { $(".file-info").text(`Double-Page View :: ${width} x ${height}`); }

    // Update page numbers in the paginator
    const newVal = Reader.showingSinglePage
        ? Reader.currentPage + 1
        : `${Reader.currentPage + 1} + ${Reader.currentPage + 2}`;
    $(".current-page").each((_i, el) => $(el).html(newVal));

    Reader.updateImageMap();
    Reader.currentPageLoaded = true;
    $("#i3").removeClass("loading");
};

Reader.updateImageMap = function () {
    // update imagemap with the w/h parameters we obtained
    const img = $("#img")[0];
    const mapWidth = img.width / 2;
    const mapHeight = img.height;

    $("#leftmap").attr("coords", `0,0,${mapWidth},${mapHeight}`);
    $("#rightmap").attr("coords", `${mapWidth + 1},0,${img.width},${mapHeight}`);
};

Reader.goToPage = function (page, fromHistory = false) {
    Reader.previousPage = Reader.currentPage;
    Reader.currentPage = Math.min(Reader.maxPage, Math.max(0, +page));

    Reader.showingSinglePage = false;
    if (Reader.doublePageMode && Reader.currentPage > 0 && Reader.currentPage < Reader.maxPage) {
        // composite an image and use that as the source
        const img1 = Reader.loadImage(Reader.currentPage);
        const img2 = Reader.loadImage(Reader.currentPage + 1);
        let imagesLoaded = 0;
        const loadHandler = () => { (imagesLoaded += 1) === 2 && Reader.drawCanvas(img1, img2); };
        $([img1, img2]).each((_i, img) => {
            img.onload = loadHandler;
            // If the image is preloaded it does not trigger onload, so we have to call it manually
            if (img.complete) { loadHandler(); }
        });
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

    // Send an API request to update progress on the server
    if (Reader.trackProgressLocally) {
        localStorage.setItem(`${Reader.id}-reader`, Reader.currentPage + 1);
    } else {
        Server.callAPI(`api/archives/${Reader.id}/progress/${Reader.currentPage + 1}`, "PUT", null, "Error updating reading progress!", null);
    }

    // scroll to top
    window.scrollTo(0, 0);

    // Update url to contain all search parameters, and push it to the history
    if (!fromHistory) { window.history.pushState(null, null, `?id=${Reader.id}&p=${Reader.currentPage + 1}`); }
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
    localStorage.hideHeader = $("#i2").is(":visible");
    $("#toggle-header input").toggleClass("toggled");
    $("#i2").toggle();
    Reader.applyContainerWidth();
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

Reader.toggleOverlay = function (selector) {
    // This function would be better fit for common.js
    const overlay = $(selector);
    overlay.is(":visible")
        ? LRR.closeOverlay()
        : $("#overlay-shade").fadeTo(150, 0.6, () => overlay.show());

    return false; // needs to return false to prevent scrolling to top
};

Reader.toggleSettingsOverlay = function () {
    return Reader.toggleOverlay("#settingsOverlay");
};

Reader.toggleArchiveOverlay = function () {
    Reader.initializeArchiveOverlay();
    return Reader.toggleOverlay("#archivePagesOverlay");
};

Reader.initializeArchiveOverlay = function () {
    if ($("#archivePagesOverlay").attr("loaded") === "true") {
        return;
    }
    $("#tagContainer").append(LRR.buildTagsDiv(Reader.tags));

    // For each link in the pages array, craft a div and jam it in the overlay.
    for (let index = 0; index < Reader.pages.length; ++index) {
        const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        const thumbnail = `
            <div class='${thumbCss} quick-thumbnail' page='${index}' style='display: inline-block; cursor: pointer'>
                <span class='page-number'>Page ${(index + 1)}</span>
                <img src='${Reader.pages[index]}'/>
            </div>`;

        $("#archivePagesOverlay").append(thumbnail);
    }
    $("#archivePagesOverlay").attr("loaded", "true");
};

Reader.regenerateThumbnail = function () {
    // this function would be better suited for common.js, since it can be reused in the index
    if (!window.confirm("Are you sure you want to regenerate the thumbnail for this archive?")) {
        return;
    }

    $.get(`./reader?id${Reader.id}&reload_thumbnail=1`).done(() => {
        $.toast({
            showHideTransition: "slide",
            position: "top-left",
            loader: false,
            heading: "Thumbnail regenerated.",
            icon: "success",
        });
    });
};

Reader.drawCanvas = function (img1, img2) {
    // If w > h on one of the images(widespread), set canvasdata to the first image only
    if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {
        // Depending on whether we were going forward or backward, display img1 or img2
        $("#img").attr("src", Reader.previousPage > Reader.currentPage ? img2.src : img1.src);
        Reader.showingSinglePage = true;
        return;
    }

    // Create an adequately-sized canvas
    const canvas = $("#dpcanvas")[0];
    canvas.width = img1.naturalWidth + img2.naturalWidth;
    canvas.height = Math.max(img1.naturalHeight, img2.naturalHeight);

    // Draw both images on it
    const ctx = canvas.getContext("2d");
    if (Reader.mangaMode) {
        ctx.drawImage(img2, 0, 0);
        ctx.drawImage(img1, img2.naturalWidth + 1, 0);
    } else {
        ctx.drawImage(img1, 0, 0);
        ctx.drawImage(img2, img1.naturalWidth + 1, 0);
    }

    $("#img").attr("src", canvas.toDataURL("image/jpeg"));
};

Reader.changePage = function (targetPage) {
    let destination;
    if (Reader.infiniteScroll) {
        if (targetPage === 1) {
            destination = $.grep($("#display img"), (img) => $(img).position().top >= $(window).scrollTop())[0];
        } else {
            destination = $.grep($("#display img"), (img) => $(img).position().top + (img.naturalHeight / 2) <= $(window).scrollTop()).pop();
        }
        if (!destination) { return; }
        destination.scrollIntoView();
        return;
    }
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

$(document).ready(() => {
    Reader.initializeAll();
});

window.Reader = Reader;
