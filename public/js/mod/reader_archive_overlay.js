/**
 * Reader archive overlay.
 */
import * as Server from "./server.js";
import * as LRR from "./common.js";
import I18N from "i18n";
import { state, goToPage, loadContentData, stopAutoNextPage, toggleOverlay, getCurrentChapter, getArchiveForPage } from "./reader_common.js";

export function initializeArchiveOverlay() {
    $(document).on("click.toggle-archive-overlay", "#toggle-archive-overlay", toggleArchiveOverlay);
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

    $(document).on("click.filter-stamped", "#filter-stamped", filterStampedOverlay);
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

export function toggleArchiveOverlay() {
    stopAutoNextPage();
    return toggleOverlay("#archivePagesOverlay");
}

export function updateArchiveOverlay(forceUpdate = false) {
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

export function checkStampedPages() {
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
