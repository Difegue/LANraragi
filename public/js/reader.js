// functions to navigate in reader with the keyboard.
// also handles the thumbnail archive explorer.

const Reader = {};
Reader.previousPage = -1;
Reader.showingSinglePage = true;
Reader.imagesLoaded = 0;

Reader.initializeAll = function () {
    Reader.maxPage = Reader.pages.length - 1;
    Reader.initializeSettings();

    // bind events to DOM
    $(window).on("resize", updateImageMap);
    $(document).on("keyup", Reader.handleShortcuts);

    $(document).on("click.toggle_fit_mode", "#fit-mode input", Reader.toggleFitMode);
    $(document).on("click.toggle_double_mode", "#toggle-double-mode input", Reader.toggleDoublePageMode);
    $(document).on("click.toggle_manga_mode", "#toggle-manga-mode input", Reader.toggleMangaMode);
    $(document).on("click.toggle_header", "#toggle-header input", Reader.toggleHeader);
    $(document).on("click.toggle_progress", "#toggle-progress input", Reader.toggleProgressTracking);
    $(document).on("submit.container_width", "#container-width-input", Reader.registerContainerWidth);
    $(document).on("click.container_width", "#container-width-apply", Reader.registerContainerWidth);

    $(document).on("click.toggle_archive_overlay", "#toggle-archive-overlay", Reader.toggleArchiveOverlay);
    $(document).on("click.toggle_settings_overlay", "#toggle-settings-overlay", Reader.toggleSettingsOverlay);
    $(document).on("click.toggle_help", "#toggle-help", Reader.toggleHelp);
    $(document).on("click.regenerate_thumbnail", "#regenerate-thumbnail", Reader.regenerateThumbnail);

    // check and display warnings for unsupported filetypes
    Reader.checkFiletypeSupport();

    // remove the "new" tag with an api call
    clearNew(Reader.id);

    let params = new URLSearchParams(window.location.search);

    // initialize current page and bind popstate
    $(window).on("popstate", () => {
        params = new URLSearchParams(window.location.search);
        if (params.has("p")) {
            const paramsPage = +params.get("p");
            goToPage(paramsPage - 1);
        }
    });

    Reader.currentPage = (+params.get("p") || 1) - 1;
    // when there's no parameter, null is coerced to 0 so it becomes -1
    Reader.currentPage ||= (
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
    goToPage(Reader.currentPage);
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
    Reader.mangaMode ? $("#manga-mode").addClass("toggled") : $("#normal-mode").addClass("toggled");

    Reader.doublePageMode = localStorage.doublePageMode === "true" || localStorage.doublepage === "true" || false;
    Reader.doublePageMode ? $("#double-page").addClass("toggled") : $("#single-page").addClass("toggled");

    Reader.ignoreProgress = localStorage.ignoreProgress === "true" || localStorage.nobookmark === "true" || false;
    Reader.ignoreProgress ? $("#untrack-progress").addClass("toggled") : $("#track-progress").addClass("toggled");

    if (localStorage.forcefullwidth === "true" || localStorage.fitMode === "fit-width") {
        Reader.fitMode = "fit-width";
        $("#fit-width").addClass("toggled");
    } else if (localStorage.scaletoview === "true" || localStorage.fitMode === "fit-height") {
        Reader.fitMode = "fit-height";
        $("#fit-height").addClass("toggled");
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

Reader.handleShortcuts = function (e) {
    if (e.target.tagName === "INPUT") {
        return;
    }
    switch (e.keyCode) {
    case 8: // backspace
        document.location.href = "/";
        break;
    case 27: // escape
        closeOverlay();
        break;
    case 32: // spacebar
        if ($(".page-overlay").is(":visible")) { break; }
        if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
            (Reader.mangaMode) ? advancePage(-1) : advancePage(1);
        }
        break;
    case 37: // left arrow
    case 65: // a
        advancePage(-1);
        break;
    case 39: // right arrow
    case 68: // d
        advancePage(1);
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
                <li>P: toggle double page mode</li>
                <li>O: show advanced reader options.</li>
                <li>Q: bring up the thumbnail index and archive options.</li>
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

function updateMetadata() {

    // remove overlay
    loaded = true;
    $("#i3").removeClass("loading");

    filename = $("#img").get(0).src.replace(/^.*[\\\/]/, "");
    w = $("#img").get(0).naturalWidth;
    h = $("#img").get(0).naturalHeight;
    size = "UNKNOWN"

    if (Reader.showingSinglePage) {

        // HEAD request to get filesize
        xhr = $.ajax({
            url: Reader.pages[Reader.currentPage],
            type: "HEAD",
            success: function () {
                size = parseInt(xhr.getResponseHeader("Content-Length") / 1024, 10);
            }
        }).done(function (data) {

            metadataString = filename + " :: " + w + " x " + h + " :: " + size + " KB";

            $(".file-info").each(function () {
                $(this).html(metadataString);
            });

            updateImageMap();
        });

    } else {

        metadataString = "Double-Page View :: " + w + " x " + h;

        $(".file-info").each(function () {
            $(this).html(metadataString);
        });

        updateImageMap();

    }

}

function updateImageMap() {

    // update imagemap with the w/h parameters we obtained
    mapWidth = $("#img").get(0).width / 2;
    mapHeight = $("#img").get(0).height;
    $("#leftmap").attr("coords", "0,0," + mapWidth + "," + mapHeight);
    $("#rightmap").attr("coords", (mapWidth + 1) + ",0," + $("#img").get(0).width + "," + mapHeight);
}

function goToPage(page) {

    Reader.previousPage = Reader.currentPage;

    if (page < 0)
        Reader.currentPage = 0;
    else if (page >= Reader.maxPage)
        Reader.currentPage = Reader.maxPage;
    else Reader.currentPage = page;

    // if double-page view is enabled(and the current page isn"t the first or the last)
    Reader.showingSinglePage = false;
    if (Reader.doublePageMode && Reader.currentPage > 0 && Reader.currentPage < Reader.maxPage) {
        // composite an image and use that as the source
        img1 = loadImage(Reader.pages[Reader.currentPage], canvasCallback);
        img2 = loadImage(Reader.pages[Reader.currentPage + 1], canvasCallback);

        // Preload next two images
        loadImage(Reader.pages[Reader.currentPage + 2], null);
        loadImage(Reader.pages[Reader.currentPage + 3], null);
    }
    else {
        // In single view, just use the source URLs as is
        $("#img").attr("src", Reader.pages[Reader.currentPage]);
        Reader.showingSinglePage = true;

        // Preload next image
        loadImage(Reader.pages[Reader.currentPage + 1], null);
    }

    // update numbers
    $(".current-page").each(function () {
        $(this).html(Reader.currentPage + 1);
    });

    Reader.applyContainerWidth();

    loaded = false;

    // display overlay if it takes too long to load a page
    setTimeout(function () {
        if (!loaded)
            $("#i3").addClass("loading");
    }, 500);

    // update full image link
    $("#imgLink").attr("href", Reader.pages[Reader.currentPage]);

    // Send an API request to update progress on the server
    genericAPICall(`api/archives/${Reader.id}/progress/${Reader.currentPage + 1}`, "PUT", null, "Error updating reading progress!", null);

    // scroll to top
    window.scrollTo(0, 0);

    // Update url to contain all search parameters, and push it to the history
    if (isComingFromPopstate) // But don"t fire this if we"re coming from popstate
        isComingFromPopstate = false;
    else {
        window.history.pushState(null, null, `?id=${Reader.id}&p=${page + 1}`);
    }
}

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
        value ||= 1200;
        type ||= "px";

        Reader.containerWidth = localStorage.containerWidth = `${value}${type}`;
    }
    Reader.applyContainerWidth();
};

Reader.applyContainerWidth = function () {
    $("#img, .sni").attr("style", "");

    if (Reader.fitMode === "fit-height") {
        // Fit to height forces the image to 90% of visible screen height.
        // If the header is hidden, then the image can take up to
        // 98% of visible screen height because there's more free space
        $("#img").attr("style", `max-height: ${Reader.hideHeader ? 98 : 90}vh;`);
        $(".sni").attr("style", "width: fit-content; width: -moz-fit-content");
    } else if (Reader.fitMode === "fit-width") {
        $("#img").attr("style", "width: 100%;");
        $(".sni").attr("style", "max-width: 98%");
    } else if (Reader.containerWidth) {
        // If the user defined a custom width, then we can fall back to that one
        $(".sni").attr("style", `max-width: ${Reader.containerWidth}`);
        $("#img").attr("style", "width: 100%");
    } else if (!Reader.showingSinglePage) {
        // Otherwise, if we are showing two pages we can override the default width
        $(".sni").attr("style", "max-width: 90%");
    } else {
        // Finally, fall back to 1200px width if none of the above matches
        $(".sni").attr("style", "max-width: 1200px");
    }
};

Reader.toggleDoublePageMode = function () {
    Reader.doublePageMode = localStorage.doublePageMode = !Reader.doublePageMode;
    $("#toggle-double-mode input").toggleClass("toggled");

    goToPage(Reader.currentPage);
};

Reader.toggleMangaMode = function () {
    Reader.mangaMode = localStorage.mangaMode = !Reader.mangaMode;
    $("#toggle-manga-mode input").toggleClass("toggled");

    if (!Reader.showingSinglePage) { goToPage(Reader.currentPage); }
};

Reader.toggleHeader = function () {
    localStorage.hideHeader = $("#i2").is(":visible");
    $("#toggle-header input").toggleClass("toggled");
    $("#i2").toggle();
};

Reader.toggleProgressTracking = function () {
    Reader.ignoreProgress = localStorage.ignoreProgress = !Reader.ignoreProgress;
    $("#toggle-progress input").toggleClass("toggled");
};

Reader.toggleOverlay = function (selector) {
    // This function would be better fit for common.js
    const overlay = $(selector);
    overlay.is(":visible")
        ? closeOverlay()
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
    $("#tagContainer").append(buildTagsDiv(Reader.tags));

    // For each link in the pages array, craft a div and jam it in the overlay.
    for (let index = 0; index < Reader.pages.length; ++index) {
        const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        const thumbnail = `
            <div class='${thumbCss}' style='display: inline-block; cursor: pointer'>
                <a onclick='goToPage(${index}); closeOverlay()'>
                    <span class='page-number'>Page ${(index + 1)}</span>
                    <img src='${Reader.pages[index]}'/>
                </a>
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

function canvasCallback() {
    Reader.imagesLoaded += 1;

    if (Reader.imagesLoaded === 2) {

        // If w > h on one of the images(widespread), set canvasdata to the first image only
        if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {

            // Depending on whether we were going forward or backward, display img1 or img2
            if (Reader.previousPage > Reader.currentPage)
                $("#img").attr("src", img2.src);
            else
                $("#img").attr("src", img1.src);

            Reader.showingSinglePage = true;
            Reader.imagesLoaded = 0;
            return;
        }

        // Create an adequately-sized canvas
        var canvas = $("#dpcanvas")[0];
        canvas.width = img1.naturalWidth + img2.naturalWidth;
        canvas.height = Math.max(img1.naturalHeight, img2.naturalHeight);

        // Draw both images on it
        ctx = canvas.getContext("2d");
        if (Reader.mangaMode) {
            ctx.drawImage(img2, 0, 0);
            ctx.drawImage(img1, img2.naturalWidth + 1, 0);
        } else {
            ctx.drawImage(img1, 0, 0);
            ctx.drawImage(img2, img1.naturalWidth + 1, 0);
        }

        Reader.imagesLoaded = 0;
        $("#img").attr("src", canvas.toDataURL("image/jpeg"));

    }
}

function loadImage(src, onload) {
    var img = new Image();

    img.onload = onload;
    img.src = src;

    return img;
}

// Go forward or backward in pages. Pass -1 for left, +1 for right.
function advancePage(pageModifier) {
    if (Reader.doublePageMode && !Reader.showingSinglePage)
        pageModifier = pageModifier * 2;

    if (Reader.mangaMode)
        pageModifier = -pageModifier;

    goToPage(Reader.currentPage + pageModifier);
}

function goFirst() {
    if (Reader.mangaMode)
        goToPage(Reader.maxPage);
    else
        goToPage(0);
}

function goLast() {
    if (Reader.mangaMode)
        goToPage(0);
    else
        goToPage(Reader.maxPage);
}

$(document).ready(() => {
    Reader.initializeAll();
});

window.Reader = Reader;
