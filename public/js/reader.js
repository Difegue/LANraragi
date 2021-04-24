// functions to navigate in reader with the keyboard.
// also handles the thumbnail archive explorer.

const Reader = {};
Reader.previousPage = -1;
Reader.showingSinglePage = true;
Reader.imagesLoaded = 0;

Reader.initializeAll = function () {
    Reader.maxPage = Reader.pages.length - 1;

    $(window).on("resize", updateImageMap);
    $(document).on("keyup", Reader.handleShortcuts);

    // check and display warnings for unsupported filetypes
    Reader.checkFiletypeSupport();

    // remove the "new" tag with an api call
    clearNew(Reader.id);

    // initialize current page and bind popstate
    $(window).on("popstate", () => {
        const params = new URLSearchParams(window.location.search);
        if (params.has("p")) {
            const paramsPage = +params.get("p");
            goToPage(paramsPage - 1);
        }
    });
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
        if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
            (localStorage.readorder === "true") ? advancePage(-1) : advancePage(1);
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
    case 81: // q
        openOverlay();
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

function toastHelpReader() {
    $.toast().reset("all");

    $.toast({
        heading: "Navigation Help",
        text: `
            You can navigate between pages using:
            <ul>
                <li>The arrow icons</li>
                <li>The a/d keys</li>
                <li>Your keyboard arrows (and the spacebar)</li>
                <li>Touching the left/right side of the image.</li>
            </ul>
            <br>To return to the archive index, touch the arrow pointing down or use Backspace.
            <br>Pressing the q key will bring up the thumbnail index and archive options.
        `,
        hideAfter: false,
        position: "top-left",
        icon: "info"
    });
}

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
            url: Reader.pages[currentPage],
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

    Reader.previousPage = currentPage;

    // Clear out style overrides
    $("#img").attr("style", "");
    $(".sni").attr("style", "");

    if (page < 0)
        currentPage = 0;
    else if (page >= Reader.maxPage)
        currentPage = Reader.maxPage;
    else currentPage = page;

    if (localStorage.containerwidth !== "" && !isNaN(localStorage.containerwidth)) {
        $(".sni").attr("style", `max-width: ${localStorage.containerwidth}px`);
    }

    // if double-page view is enabled(and the current page isn"t the first or the last)
    if (localStorage.doublepage === "true" && currentPage > 0 && currentPage < Reader.maxPage) {
        // composite an image and use that as the source
        img1 = loadImage(Reader.pages[currentPage], canvasCallback);
        img2 = loadImage(Reader.pages[currentPage + 1], canvasCallback);

        // We can also override the 1200px maxwidth since we usually have twice the pages
        if (localStorage.containerwidth === "" || isNaN(localStorage.containerwidth))
            $(".sni").attr("style", "max-width: 90%");

        // Preload next two images
        loadImage(Reader.pages[currentPage + 2], null);
        loadImage(Reader.pages[currentPage + 3], null);
    }
    else {
        // In single view, just use the source URLs as is
        $("#img").attr("src", Reader.pages[currentPage]);
        Reader.showingSinglePage = true;

        // Preload next image
        loadImage(Reader.pages[currentPage + 1], null);
    }

    // Fit to screen simply forces image height at 90vh (90% of viewport height)
    if (localStorage.scaletoview === "true")
        $("#img").attr("style", "max-height: 90vh;");

    // hide/show toplevel nav depending on the pref
    if (localStorage.hidetop === "true") {
        $("#i2").attr("style", "display:none");
        $("div.sni h1").attr("style", "display:none");

        // Since the topnav is gone, we can afford to make the image a bit bigger.
        if (localStorage.scaletoview === "true")
            $("#img").attr("style", "max-height: 98vh;");
    }
    else {
        $("#i2").attr("style", "");
        $("div.sni h1").attr("style", "");
    }

    // Force full width discards fit to screen and just forces img width to 100%
    if (localStorage.forcefullwidth === "true") {
        $("#img").attr("style", "width: 100%;");
        $(".sni").attr("style", "max-width: 98%");
    }

    // update numbers
    $(".current-page").each(function () {
        $(this).html(parseInt(currentPage) + 1);
    });

    loaded = false;

    // display overlay if it takes too long to load a page
    setTimeout(function () {
        if (!loaded)
            $("#i3").addClass("loading");
    }, 500);

    // update full image link
    $("#imgLink").attr("href", Reader.pages[currentPage]);

    // Send an API request to update progress on the server
    genericAPICall(`api/archives/${Reader.id}/progress/${currentPage + 1}`, "PUT", null, "Error updating reading progress!", null);

    // scroll to top
    window.scrollTo(0, 0);

    // Update url to contain all search parameters, and push it to the history
    if (isComingFromPopstate) // But don"t fire this if we"re coming from popstate
        isComingFromPopstate = false;
    else {
        window.history.pushState(null, null, `?id=${Reader.id}&p=${page + 1}`);
    }
}

function initArchivePageOverlay() {

    $("#tagContainer").append(buildTagsDiv(Reader.tags));

    // For each link in the pages array, craft a div and jam it in the overlay.
    for (index = 0; index < Reader.pages.length; ++index) {

        thumb_css = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        thumbnail = `<div class="${thumb_css}" style="display: inline-block; cursor: pointer">` +
            `<a onclick="goToPage(${index}); closeOverlay()">` +
            `<span class="page-number">Page ${(index + 1)}</span>` +
            `<img src="${Reader.pages[index]}" /></a></div>`;

        $("#archivePagesOverlay").append(thumbnail);
    }
    $("#archivePagesOverlay").attr("loaded", "true");
}

function applySettings() {

    $(".favtag-btn").removeClass("toggled");
    $("#containersetting").hide();

    if (!isNaN(localStorage.containerwidth))
        $("#containerwidth").val(localStorage.containerwidth);

    if (localStorage.readorder === "true")
        $("#mangaread").addClass("toggled");
    else
        $("#normalread").addClass("toggled");

    if (localStorage.doublepage === "true")
        $("#doublepage").addClass("toggled");
    else
        $("#singlepage").addClass("toggled");

    if (localStorage.forcefullwidth === "true")
        $("#fitwidth").addClass("toggled");
    else if (localStorage.scaletoview === "true")
        $("#fitheight").addClass("toggled");
    else {
        $("#fitcontainer").addClass("toggled");
        $("#containersetting").show();
    }

    if (localStorage.hidetop === "true")
        $("#hidetop").addClass("toggled");
    else
        $("#showtop").addClass("toggled");

    if (localStorage.nobookmark === "true")
        $("#nobookmark").addClass("toggled");
    else
        $("#dobookmark").addClass("toggled");

    // Reset reader
    goToPage(currentPage);
}

function setDisplayMode(fittowidth, fittoheight) {
    localStorage.forcefullwidth = fittowidth;
    localStorage.scaletoview = fittoheight;
    applySettings();
}

function setDoublePage(doublepage) {
    localStorage.doublepage = doublepage;
    applySettings();
}

function setRTL(righttoleft) {
    localStorage.readorder = righttoleft;
    applySettings();
}

function setHideHeader(hideheader) {
    localStorage.hidetop = hideheader;
    applySettings();
}

function setTracking(disablebookmark) {
    localStorage.nobookmark = disablebookmark;
    applySettings();
}

function applyContainerWidth() {
    input = $("#containerwidth").val().trim();

    if (!isNaN(input))
        localStorage.containerwidth = input;
    else
        localStorage.removeItem("containerwidth");

    applySettings();
}

function openOverlay() {
    if ($("#archivePagesOverlay").attr("loaded") === "false")
        initArchivePageOverlay();

    $("#overlay-shade").fadeTo(150, 0.6, function () {
        $("#archivePagesOverlay").css("display", "block");
    });
}

function confirmThumbnailReset(id) {

    if (confirm("Are you sure you want to regenerate the thumbnail for this archive?")) {

        $.get(`./reader?id=${id}&reload_thumbnail=1`).done(function () {
            $.toast({
                showHideTransition: "slide",
                position: "top-left",
                loader: false,
                heading: "Thumbnail Regenerated.",
                icon: "success"
            });
        });
    }
}

function canvasCallback() {
    Reader.imagesLoaded += 1;

    if (Reader.imagesLoaded === 2) {

        // If w > h on one of the images(widespread), set canvasdata to the first image only
        if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {

            // Depending on whether we were going forward or backward, display img1 or img2
            if (Reader.previousPage > currentPage)
                $("#img").attr("src", img2.src);
            else
                $("#img").attr("src", img1.src);

            Reader.showingSinglePage = true;
            Reader.imagesLoaded = 0;
            return;
        }

        // Double page confirmed
        Reader.showingSinglePage = false;

        // Create an adequately-sized canvas
        var canvas = $("#dpcanvas")[0];
        canvas.width = img1.naturalWidth + img2.naturalWidth;
        canvas.height = Math.max(img1.naturalHeight, img2.naturalHeight);

        // Draw both images on it
        ctx = canvas.getContext("2d");
        if (localStorage.readorder === "true") {
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
    if (localStorage.doublepage === "true" && Reader.showingSinglePage == false)
        pageModifier = pageModifier * 2;

    if (localStorage.readorder === "true")
        pageModifier = -pageModifier;

    goToPage(currentPage + pageModifier);
}

function goFirst() {
    if (localStorage.readorder === "true")
        goToPage(Reader.maxPage);
    else
        goToPage(0);
}

function goLast() {
    if (localStorage.readorder === "true")
        goToPage(0);
    else
        goToPage(Reader.maxPage);
}

$(document).ready(() => {
    Reader.initializeAll();
});

window.Reader = Reader;
