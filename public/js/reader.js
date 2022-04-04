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
Reader.isFullscreen = false;
Reader.preloadedImg = {};
Reader.preloadedSizes = {};

Reader.initializeAll = function () {
    Reader.initializeSettings();
    Reader.applyContainerWidth();
    Reader.registerPreload();

    // Bind events to DOM
    $(document).on("keyup", Reader.handleShortcuts);

    $(document).on("click.toggle_fit_mode", "#fit-mode input", Reader.toggleFitMode);
    $(document).on("click.toggle_double_mode", "#toggle-double-mode input", Reader.toggleDoublePageMode);
    $(document).on("click.toggle_manga_mode", "#toggle-manga-mode input, .reading-direction", Reader.toggleMangaMode);
    $(document).on("click.toggle_header", "#toggle-header input", Reader.toggleHeader);
    $(document).on("click.toggle_progress", "#toggle-progress input", Reader.toggleProgressTracking);
    $(document).on("click.toggle_infinite_scroll", "#toggle-infinite-scroll input", Reader.toggleInfiniteScroll);
    $(document).on("click.toggle_overlay", "#toggle-overlay input", Reader.toggleOverlayByDefault);
    $(document).on("submit.container_width", "#container-width-input", Reader.registerContainerWidth);
    $(document).on("click.container_width", "#container-width-apply", Reader.registerContainerWidth);
    $(document).on("submit.preload", "#preload-input", Reader.registerPreload);
    $(document).on("click.preload", "#preload-apply", Reader.registerPreload);
    $(document).on("click.pagination_change_pages", ".page-link", Reader.handlePaginator);

    $(document).on("click.close_overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.toggle_full_screen", "#toggle-full-screen", Reader.toggleFullScreen);
    $(document).on("click.toggle_archive_overlay", "#toggle-archive-overlay", Reader.toggleArchiveOverlay);
    $(document).on("click.toggle_settings_overlay", "#toggle-settings-overlay", Reader.toggleSettingsOverlay);
    $(document).on("click.toggle_help", "#toggle-help", Reader.toggleHelp);
    $(document).on("click.regenerate_archive_cache", "#regenerate-cache", () => {
        window.location.href = `./reader?id=${Reader.id}&force_reload`;
    });
    $(document).on("click.edit_metadata", "#edit-archive", () => LRR.openInNewTab(`./edit?id=${Reader.id}`));
    $(document).on("click.add_category", "#add-category", () => Server.addArchiveToCategory(Reader.id, $("#category").val()));
    $(document).on("click.set_thumbnail", "#set-thumbnail", () => Server.callAPI(`/api/archives/${Reader.id}/thumbnail?page=${Reader.currentPage + 1}`,
        "PUT", `Successfully set page ${Reader.currentPage + 1} as the thumbnail!`, "Error updating thumbnail!", null));

    $(document).on("click.thumbnail", ".quick-thumbnail", (e) => {
        LRR.closeOverlay();
        const pageNumber = +$(e.target).closest("div[page]").attr("page");
        if (Reader.infiniteScroll) {
            $("#display img").get(pageNumber).scrollIntoView({ behavior: "smooth" });
        } else {
            Reader.goToPage(pageNumber);
        }
    });

    // Infer initial information from the URL
    const params = new URLSearchParams(window.location.search);
    Reader.id = params.get("id");
    Reader.force = params.get("force_reload") !== null;
    Reader.currentPage = (+params.get("p") || 1) - 1;

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

            $("#archive-title").html(title);
            if (data.pagecount) { $(".max-page").html(data.pagecount); }
            document.title = title;

            Reader.tags = data.tags;
            $("#tagContainer").append(LRR.buildTagsDiv(Reader.tags));

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
        });
};

Reader.loadImages = function () {
    Server.callAPI(`/api/archives/${Reader.id}/files?force=${Reader.force}`, "GET", null, "Error getting the archive's imagelist!",
        (data) => {
            Reader.pages = data.pages;
            Reader.maxPage = Reader.pages.length - 1;
            $(".max-page").html(Reader.pages.length);

            $("#img").on("load", Reader.updateMetadata);

            if (Reader.infiniteScroll) {
                Reader.initInfiniteScrollView();
            } else {
                $(window).on('wheel', function(e) {
                    if(Reader.isFullscreen) {
                        if (e.originalEvent.deltaY > 0) Reader.changePage(-1);
                        else Reader.changePage(1);
                        return false;
                    }
                });
                $(document).on('click', function(event) {
                    var img_y_offset = $('a#display img').offset()['top'] + $('a#display img').height();
                    if (event.pageY < img_y_offset && !$('#overlay-shade').is(':visible') ){
                        var whereside = event.pageX < $(window).width()/2 ? 'left' : 'right';
                        if (!$(event.target).closest('a#display').length) {
                            whereside = 'outer-'+whereside;
                        }
                        switch (whereside) {
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
                    }
                });
                $(window).on("resize", Reader.updateImagemap);

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
            }

            if (Reader.showOverlayByDefault) { Reader.toggleArchiveOverlay(); }

            // Wait for the extraction job to conclude before getting thumbnails
            Server.checkJobStatus(data.job, false,
                () => Reader.initializeArchiveOverlay(),
                () => LRR.showErrorToast("The extraction job didn't conclude properly. Your archive might be corrupted."));
        }).finally(() => {
        if (Reader.pages === undefined) {
            $("#img").attr("src", "img/flubbed.gif");
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
        document.location.href = $("#return-to-index").attr("href");
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
    case 70: // d
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
        document.location.href = "/random";
        break;
    default:
        break;
    }
};

Reader.checkFiletypeSupport = function (extension) {
    if ((extension === "rar" || extension === "cbr") && !localStorage.rarWarningShown) {
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
    } else if (extension === "epub" && !localStorage.epubWarningShown) {
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
        text: $("#reader-help").children().first().html(),
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
    const img_pre = $("#img_pre")[0];
    const imageUrl_pre = new URL(img_pre.src);
    const filename_pre = imageUrl_pre.searchParams.get("path");
    if (!filename && Reader.showingSinglePage) {
        Reader.currentPageLoaded = true;
        $("#i3").removeClass("loading");
        return;
    }

    const width = img.naturalWidth;
    const height = img.naturalHeight;
    const width_pre = img_pre.naturalWidth;
    const height_pre = img_pre.naturalHeight;
    const width_view = width + width_pre;
    const height_view = height > height_pre ? height : height_pre;

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
    } else { 
        // HEAD request to get filesize
        let size = Reader.preloadedSizes[Reader.currentPage];
        let size_pre = Reader.preloadedSizes[Reader.currentPage+1];
        let size_view = size + size_pre;
        if (!size || !size_pre) {
            $.ajax({
                url: Reader.pages[Reader.currentPage],
                type: "HEAD",
                success: (data, textStatus, request) => {
                    size = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
                    Reader.preloadedSizes[Reader.currentPage] = size;
                    $.ajax({
                        url: Reader.pages[Reader.currentPage+1],
                        type: "HEAD",
                        success: (data, textStatus, request) => {
                            size_pre = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
                            Reader.preloadedSizes[Reader.currentPage+1] = size_pre;
                            size_view = size + size_pre;
                            $(".file-info").text(`${filename} - ${filename_pre} :: ${width_view} x ${height} :: ${size_view} KB`);
                            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB - ${filename_pre} :: ${width_pre} x ${height_pre} :: ${size_pre} KB`);
                        },
                    });
                },
            });
        } else { 
            $(".file-info").text(`${filename} - ${filename_pre} :: ${width_view} x ${height} :: ${size_view} KB`);
            $(".file-info").attr("title", `${filename} :: ${width} x ${height} :: ${size} KB - ${filename_pre} :: ${width_pre} x ${height_pre} :: ${size_pre} KB`);
        }
    }

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

Reader.goToPage = function (page) {
    Reader.previousPage = Reader.currentPage;
    Reader.currentPage = Math.min(Reader.maxPage, Math.max(0, +page));

    Reader.showingSinglePage = false;
    if (Reader.doublePageMode && Reader.currentPage > 0 && Reader.currentPage < Reader.maxPage) {
        // composite an image and use that as the source
        const img1 = Reader.loadImage(Reader.currentPage);
        const img2 = Reader.loadImage(Reader.currentPage + 1);
        if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {
            // Depending on whether we were going forward or backward, display img1 or img2
            $("#img").attr("src", Reader.previousPage > Reader.currentPage ? img2.src : img1.src);
            $("#img_pre").attr("src", "");
            Reader.showingSinglePage = true;
        } else {
            if (Reader.mangaMode) {
                $("#img").attr("src", img2.src);
                $("#img_pre").attr("src", img1.src);
            } else {
                $("#img").attr("src", img1.src);
                $("#img_pre").attr("src", img2.src);
            }
        }
    } else {
        const img = Reader.loadImage(Reader.currentPage);
        $("#img").attr("src", img.src);
        $("#img_pre").attr("src", "");
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
    if (Reader.infiniteScroll) { return false; }
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
  // if already full screen; exit
  // else go fullscreen
  if (
    document.fullscreenElement ||
    document.webkitFullscreenElement ||
    document.mozFullScreenElement ||
    document.msFullscreenElement
  ) {
    if($('body').hasClass('infinite-scroll')) {
        $('div#i3').removeClass('fullscreen-infinite');
    } else {
        $('div#i3').removeClass('fullscreen');
    }
    if (document.exitFullscreen) {
      document.exitFullscreen();
    } else if (document.mozCancelFullScreen) {
      document.mozCancelFullScreen();
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen();
    } else if (document.msExitFullscreen) {
      document.msExitFullscreen();
    }
    Reader.isFullscreen = false;
  } else {
    if($('body').hasClass('infinite-scroll')) {
        $('div#i3').addClass('fullscreen-infinite');
    } else {
        $('div#i3').addClass('fullscreen');
    }
    element = $('div#i3').get(0);
    if (element.requestFullscreen) {
      element.requestFullscreen();
    } else if (element.mozRequestFullScreen) {
      element.mozRequestFullScreen();
    } else if (element.webkitRequestFullscreen) {
      element.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
    } else if (element.msRequestFullscreen) {
      element.msRequestFullscreen();
    }
    Reader.isFullscreen = true;
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
        const thumbnail = `
            <div class='${thumbCss} quick-thumbnail' page='${index}' style='display: inline-block; cursor: pointer'>
                <span class='page-number'>Page ${page}</span>
                <img src="./img/wait_warmly.jpg" id="${index}_thumb" />
                <i id="${index}_spinner" class="fa fa-4x fa-circle-notch fa-spin ttspinner" style="display:flex;justify-content: center; align-items: center;"></i>
            </div>`;

        // Try to load the thumbnail and see if we have to wait for a Minion job (202 vs 200)
        const thumbnailUrl = `/api/archives/${Reader.id}/thumbnail?page=${page}`;

        const thumbSuccess = function () {
            // Set image source to the thumbnail
            $(`#${index}_thumb`).attr("src", thumbnailUrl);
            $(`#${index}_spinner`).hide();
        };

        const thumbFail = function () {
            // If we fail to load the thumbnail, then we'll just show a placeholder
            $(`#${index}_thumb`).attr("src", "/img/noThumb.png");
            $(`#${index}_spinner`).hide();
        };

        fetch(`${thumbnailUrl}&no_fallback=true`, { method: "GET" })
            .then((response) => {
                if (response.status === 200) {
                    thumbSuccess();
                } else if (response.status === 202) {
                    // Wait for Minion job to finish
                    response.json().then((data) => Server.checkJobStatus(data.job, false,
                        () => thumbSuccess(),
                        () => thumbFail()));
                } else {
                    // We don't have a thumbnail for this page
                    thumbFail();
                }
            });

        $("#archivePagesOverlay").append(thumbnail);
    }
    $("#archivePagesOverlay").attr("loaded", "true");
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
