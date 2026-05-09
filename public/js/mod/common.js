/**
 * Functions that get used in multiple pages but don't really depend on networking.
 * @global
 */
import * as Index from "mod/index";
import * as Server from "mod/server";
import * as IndexTable from "mod/index_datatables";

let toastsInitialized = false;
let isProgressLocal = true;          // Whether to use local (localStorage) progress tracking
let isProgressAuthenticated = true;  // Whether progress requires authentication

function _get_baseurl_cookie() {
    let cookies = document.cookie;
    let val = cookies.split("; ").find((r) => r.startsWith("lrr_baseurl="))?.split("=")[1];
    if (val === undefined) {
        console.warn("lrr_baseurl cookie undefined, must be set by backend");
        val = "";
    }
    return val;
}

// This class is used to wrap URLs that point into the app, including
// API endpoints and browser targets. It reads the configured base URL
// from the template, then prepends it to the provided URL in the
// toString() method.

// Every operation involving an app-internal URL should be wrapped in
// this class before use. It can be passed to any API that expects a
// URL, and can be wrapped around another instance of itself without a
// change.
export class ApiURL {
    static base_url = _get_baseurl_cookie();
    load_url = "";

    /**
     * @param {string|ApiURL} load_url
     */
    constructor(load_url) {
        // accept instances of self as well, to make wrapping
        // idempotent
        if (load_url instanceof ApiURL) {
            this.load_url = load_url.load_url;
        }
        else {
            this.load_url = load_url;
        }
        if (!this.load_url.startsWith("/")) {
            console.trace("passed non-absolute URL to ApiURL");
            this.load_url = "/" + this.load_url;
        }
    }

    toString() {
        // in the default case, this will be empty string and will
        // leave the load URL unchanged
        return ApiURL.base_url + this.load_url;
    }
}

/**
 * Helper function to get user logged status based on tt2 userLogged attribute.
 * @returns true if user is logged in, else false.
 */
export function isUserLogged() {
    const value = document.body.dataset.userLogged;
    return value === "1";
}

/**
 * @returns true if bookmark icon is linked to a category, else false.
 */
export function bookmarkLinkConfigured() {
    return localStorage.getItem("bookmarkCategoryId") !== null && localStorage.getItem("bookmarkCategoryId").startsWith("SET_");
}

/**
 * Quick HTML encoding function.
 * @param {string} r The HTML to encode
 * @returns Encoded string
 */
export function encodeHTML(r) {
    if (r === undefined) return r;
    if (Array.isArray(r)) {
        return r[0].replace(/[\n&<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
    } else {
        return r.replace(/[\n&<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
    }
}

/**
 * Unix timestamp converting function.
 * @param {number} r The timestamp to convert
 * @returns Converted string
 */
export function convertTimestamp(r) {
    return (new Date(r * 1000)).toLocaleDateString();
}

/**
 * Check if we're running on a mobile browser.
 */
export function isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

/**
 * Checks if the given string is null or whitespace.
 * @param {string} input The string to check
 * @returns true or false
 */
export function isNullOrWhitespace(input) {
    return !input || !input.trim();
}

/**
 * Get the URL to search for a given tag.
 * @param {string} namespace Tag namespace
 * @param {string} tag tag
 * @returns The URL.
 */
export function getTagSearchURL(namespace, tag) {
    const namespacedTag = buildNamespacedTag(namespace, tag);
    if (namespace !== "source") {
        return new ApiURL(`/?q=${encodeURIComponent(namespacedTag)}$`);
    } else if (/https?:\/\//.test(tag)) {
        return `${tag}`;
    } else {
        return `https://${tag}`;
    }
}

/**
 * Open the given URL in a new browser tab.
 * @param {string} url The URL
 */
export function openInNewTab(url) {
    const win = window.open(url, "_blank");
    win.focus();
}

/**
 * Close any opened overlay that uses base-overlay.
 */
export function closeOverlay() {
    $("#overlay-shade").fadeOut(300);
    $(".base-overlay").css("display", "none");
}

/**
 * Get a string representation of a namespace+tag combo.
 * The namespace is omitted if blank or "other".
 * @param {string} namespace The namespace
 * @param {string} tag The tag
 * @returns {string} namespace:tag, or tag alone.
 */
export function buildNamespacedTag(namespace, tag) {
    return (namespace !== "" && namespace !== "other") ? `${namespace}:${tag}` : tag;
}

/**
 * Remove namespace from tags and color-code them. Meant for inline display.
 * @param {string} tags string containing all tags, split by commas.
 * @returns {string}
 */
export function colorCodeTags(tags) {
    let line = "";
    if (tags === "") return line;

    const tagsByNamespace = splitTagsByNamespace(tags);
    const filteredTags = Object.keys(tagsByNamespace).filter((tag) => ! /^(date|time)/.test(tag));
    let tagsToEncode;

    if (filteredTags.length) {
        tagsToEncode = filteredTags.sort();
    } else {
        tagsToEncode = Object.keys(tagsByNamespace).sort();
    }

    tagsToEncode.sort().forEach((key) => {
        tagsByNamespace[key].forEach((tag) => {
            const encodedK = encodeHTML(key.toLowerCase());
            const encodedVal = encodeHTML(/^(date|time)/.test(key) ? convertTimestamp(tag) : tag);
            line += `<span class='${encodedK}-tag'>${encodedVal}</span>, `;
        });
    });
    // Remove last comma
    return line.slice(0, -2);
}

/**
 * Splits a LRR tag string into a per-namespace dictionary of arrays.
 * @param {string} tags string containing all tags, split by commas.
 * @returns {object} The tag dictionary
 */
export function splitTagsByNamespace(tags) {
    const tagsByNamespace = {};
    const namespaceRegex = /([^:]*):(.*)/i;

    if (tags === null || tags === undefined) {
        return tagsByNamespace;
    }

    tags.split(/,\s?/).forEach((tag) => {
        let nspce = null;
        let val = null;

        // Split the tag from its namespace
        const arr = namespaceRegex.exec(tag);

        if (arr != null) {
            nspce = arr[1].trim();
            val = arr[2].trim();
        } else {
            nspce = "other";
            val = tag.trim();
        }

        if (nspce in tagsByNamespace) tagsByNamespace[nspce].push(val);
        else tagsByNamespace[nspce] = [val];
    });

    return tagsByNamespace;
}

/**
 * Converts tag dictionary into list of tags.
 * @param {{ [namespace: string]: string[] }} tagsDict Per-namespace dictionary of arrays containing tags under each namespace.
 * @returns List of tags prefixed with namespace.
 */
export function buildTagList(tagsDict) {
    return Object.entries(tagsDict).flatMap(([namespace, tagArray]) => tagArray.map(tag => buildNamespacedTag(namespace, tag)));
}

/**
 * Builds a caption div containing clickable tags. Namespaces are resolved on the fly.
 * @param {string} tags string containing all tags, split by commas.
 * @returns the div
 */
export function buildTagsDiv(tags) {
    if (tags === "") return "";

    const tagsByNamespace = splitTagsByNamespace(tags);

    let line = `<table class="itg" style="box-shadow: 0 0 0 0; border: none; border-radius: 0" ><tbody>`;

    // Go through resolved namespaces and print tag divs
    Object.keys(tagsByNamespace).sort().forEach((key) => {
        let ucKey = (key === "date_added")
            ? "Date Added"
            : key.charAt(0).toUpperCase() + key.slice(1);
        ucKey = encodeHTML(ucKey);

        const encodedK = encodeHTML(key.toLowerCase());
        line += `<tr><td class='caption-namespace ${encodedK}-tag'>${ucKey}:</td><td>`;

        tagsByNamespace[key].forEach((tag) => {
            const url = getTagSearchURL(key, tag);
            const searchTag = buildNamespacedTag(key, tag);

            const tagText = encodeHTML(/^(date|time)/.test(key) ? convertTimestamp(tag) : tag);

            line += `<div class="gt">
                        <a href="${url}" search="${encodeHTML(searchTag)}">
                            ${tagText}
                        </a>
                    </div>`;
        });

        line += `</td></tr>`;
    });

    line += `</tbody></table>`;
    return line;
}

/**
 * Build a tooltip when hovering over a tag div, then display it.
 * @param {string} target The target tags div
 */
export function buildTagTooltip(target) {
    tippy(target, {
        content: $(target).next("div").attr("style", "")[0],
        delay: 0,
        placement: "auto-start",
        maxWidth: "none",
        interactive: true,
        appendTo: document.body,
    }).show();

    $(target).attr("onmouseover", "");
};


/**
 * Build bookmark icon for an archive.
 * @param {string} id
 * @param {string} bookmark_class Either "thumbnail-bookmark-icon" or "title-bookmark-icon".
 * @returns HTML component string
 */
export function buildBookmarkIconElement(id, bookmark_class) {
    if (!bookmarkLinkConfigured()) {
        return "";
    }
    const isBookmarked = JSON.parse(localStorage.getItem("bookmarkedArchives") || "[]").includes(id);
    const bookmarkClass = isBookmarked ? "fas fa-bookmark" : "far fa-bookmark";
    const disabledClass = isUserLogged() ? "" : " disabled";
    const style = !isUserLogged() ? `style="opacity: 0.5; cursor: not-allowed;"` : "";
    return `<i id="${id}" class="${bookmarkClass} ${bookmark_class}${disabledClass}" title="${I18N.ToggleBookmark}" ${style}></i>`;
}

/**
 * Build a thumbnail div for the given archive data. Dynamically generates a bookmark icon,
 * such that the toggleability depends on whether the user is logged in.
 * @param {object} data The archive data
 * @param {boolean} tagTooltip Option to build TagTooltip on mouseover
 * @returns {string} HTML component string
 */
export function buildThumbnailDiv(data, tagTooltip = true) {
    const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
    // The ID can be in a different field depending on the archive object...
    const id = data.arcid || data.id;
    let reader_url = new ApiURL(`/reader?id=${id}`);
    const bookmarkIcon = buildBookmarkIconElement(id, "thumbnail-bookmark-icon");

    // For tankoubons, use the first archive's thumbnail (thumb_archive field)
    // If thumb_archive is empty string (empty tank), show noThumb.png directly
    // If thumb_archive is undefined (regular archive), use the item's own ID
    const thumbId = data.thumb_archive || id;
    const thumbSrc = data.thumb_archive === ""
        ? new ApiURL("/img/noThumb.png")
        : new ApiURL(`/api/archives/${thumbId}/thumbnail`);

    // Don't enforce no_fallback=true here, we don't want those divs to trigger Minion jobs
    return `<div class="id1 context-menu swiper-slide" id="${id}">
                <div class="id2">
                    ${buildStatusDiv(data)}
                    <a href="${reader_url}" title="${encodeHTML(data.title)}">${encodeHTML(data.title)}</a>
                </div>
                <div class="${thumbCss}">
                    <a href="${reader_url}" title="${encodeHTML(data.title)}">
                        <img style="position:relative;" id="${id}_thumb" src="${new ApiURL("/img/wait_warmly.jpg")}"/>
                        <i id="${id}_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>
                        <img src="${thumbSrc}"
                                onload="$('#${id}_thumb').remove(); $('#${id}_spinner').remove();"
                                onerror="this.src='${new ApiURL("/img/noThumb.png")}'"/>
                    </a>
                    ${bookmarkIcon}
                </div>
                <div class="id4">
                        ${buildPageCountDiv(data)}
                        <span class="tags tag-tooltip" ${tagTooltip === true ? "onmouseover=\"window.LRR.buildTagTooltip(this)\"" : ""}>${colorCodeTags(data.tags)}</span>
                        ${tagTooltip === true ? `<div class="caption caption-tags" style="display: none;" >${buildTagsDiv(data.tags)}</div>` : ""}
                </div>
            </div>`;
}

/**
 * Show an emoji for the given archive data.
 * @param {object} arcdata The archive data object
 * @returns HTML string
 */
export function buildStatusDiv(arcdata) {
    const { isnew } = arcdata;
    let { progress, pagecount } = getProgress(arcdata);
    const isTank = arcdata.arcid.startsWith("TANK_");

    let statuses = [];

    // New indicator
    if (isnew === "true") {
        statuses.push(`<span title="${I18N.StatusNew}">🆕</span>`);
    }

    // Read indicator - consider read if progress is past 85% of total
    // For archives: only show if not new (mutually exclusive)
    // For tankoubons: can show alongside new (tank can have new archives AND be mostly read)
    if (pagecount > 0 && (progress / pagecount) > 0.85) {
        if (isTank || isnew !== "true") {
            statuses.push(`<span title="${I18N.StatusRead}">👑</span>`);
        }
    }

    // Tankoubon indicator (last)
    if (isTank) {
        statuses.push(`<span title="${I18N.StatusTankoubon}">📚</span>`);
    }

    if (statuses.length === 0) return "";
    return `<div class='isnew status-icons'>${statuses.join("")}</div>`;
}

export function buildPageCountDiv(arcdata) {

    const isTank = arcdata.arcid.startsWith("TANK_");
    let { progress, pagecount } = getProgress(arcdata);

    if (isTank && pagecount > 0) {
        const archiveCount = arcdata.archive_count ?? 0;
        return `<div class='isnew'><sup title="${I18N.TankPageCount}">${progress}/${pagecount}/${archiveCount}</sup></div>`;
    }
    if (pagecount > 0) {
        return `<div class='isnew'><sup title="${I18N.PageCount}">${progress}/${pagecount}</sup></div>`;
    }
    return "";
}

export function buildChapterObject(toc, totalpages) {
    const chapters = [];
    if (toc.length === 0) {
        return chapters;
    }

    if (toc[0].page > 1) {
        // Fill in gap before first chapter
        chapters.push({
            name: I18N.UntitledChapter,
            startPage: 1,
            endPage: toc[0].page - 1,
        });
    }

    toc.forEach((entry) => {

        if (chapters.length > 0) {
            // Fill in gap between previous chapter and this one
            const prevChapter = chapters[chapters.length - 1];
            if (entry.page > prevChapter.startPage + 1) {
                prevChapter.endPage = entry.page - 1;
            } else {
                prevChapter.endPage = prevChapter.startPage;
            }
        }

        chapters.push({
            name: entry.name,
            startPage: entry.page,
            endPage: null, // to be filled in later
        });
    });

    // Fill in end page for last chapter
    const lastChapter = chapters[chapters.length - 1];
    if (lastChapter.startPage <= totalpages) {
        lastChapter.endPage = totalpages;
    } else {
        lastChapter.endPage = lastChapter.startPage;
    }

    return chapters;
}

/**
 * Get the progress and pagecount for the given archive data, considering localStorage if needed.
 * @param {object} arcdata The archive data object
 * @returns progress and pagecount
 */
export function getProgress(arcdata) {
    const id = arcdata.arcid;

    const pagecount = parseInt(arcdata.pagecount || 0, 10);
    let progress = -1;

    if (isProgressLocal && !(isProgressAuthenticated && isUserLogged())) {
        progress = parseInt(localStorage.getItem(`${id}-reader`) || 0, 10);
    } else {
        progress = parseInt(arcdata.progress || 0, 10);
    }

    return { progress, pagecount };
}

/**
 * Show a generic error toast with a given header and message.
 * @param {*} header Error header
 * @param {*} error Error message
 */
export function showErrorToast(header, error) {
    toast({
        heading: header,
        text: error,
        icon: "error",
        hideAfter: false,
    });
}

/**
 * Show a pop-up window to request user input.
 * @param {*} c Pop-up body
 */
export function showPopUp(c) {
    if (!c.customClass) {
        c.customClass = {
            cancelButton: "stdbtn",
            confirmButton: "stdbtn",
        };
    }

    if (c.icon === "warning" && !c.title) {
        c.title = I18N.ConfirmDestructive;
    }
    return window.Swal.fire(c);
}

/**
 * Fires a HEAD request to get filesize of a given URL.
 * return target img size.
 * @param {string} target Target URL String
 */
export function getImgSize(target) {
    let imgSize = 0;
    $.ajax({
        async: false,
        url: target,
        cache: true,
        type: "HEAD",
        success: (data, textStatus, request) => {
            imgSize = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
        },
    });
    return imgSize;
}

/**
 * Show a generic toast with a given header and message.
 * This is a compatibility layer to migrate jquery-toast-plugin to react-toastify.
 * @param {*} c Toast body
 */
export function toast(c) {
    if (!toastsInitialized) {
        initializeToasts();
    }

    return window.reactToastify.toast(
        window.React.createElement("div", { dangerouslySetInnerHTML: { __html: `${c.heading ? `<h2>${c.heading}</h2>` : ""}${c.text ?? ""}` } }), (() => {
            const toastType = c.icon || c.typel;
            const isWarningOrError = (toastType === "warning") || (toastType === "error");
            const autoCloseTime = {
                info: 5000,
                success: 5000,
                warning: 10000,
                error: false,
            };
            return {
                toastId: c.toastId,
                type: toastType || "info",
                position: c.position || "top-left",
                onOpen: c.onOpen,
                onClose: c.onClose,
                autoClose: c.hideAfter ?? c.autoClose ?? autoCloseTime[toastType] ?? 7000,
                closeButton: c.allowToastClose ?? c.closeButton ?? true,
                hideProgressBar: (typeof (c.loader) === "boolean" && !c.loader) ?? c.hideProgressBar ?? false,
                pauseOnHover: c.pauseOnHover ?? true,
                pauseOnFocusLoss: c.pauseOnFocusLoss ?? true,
                closeOnClick: c.closeOnClick ?? (!isWarningOrError),
                draggable: c.draggable ?? (!isWarningOrError),
            };
        })());
}

// #region Context Menu Functions

/**
 * Build category list for contextMenu and checkoff the ones the given ID belongs to.
 * @param {*} catList The list of categories, obtained statically
 * @param {*} id The ID of the archive or tankoubon to check
 * @returns Categories
 */
export function loadContextMenuCategories(catList, id){
    return Server.callAPI(`/api/archives/${id}/categories`, "GET", null, I18N.IndexIdLoadError(id),
        (data) => {
            const items = {};

            for (let i = 0; i < catList.length; i++) {
                const catId = catList[i].id;

                // If the category is also in the API results,
                // we can pre-check it when creating the checkbox
                const isSelected = data.categories.map((x) => x.id).includes(catId);
                items[catId] = { name: catList[i].name, type: "checkbox" };
                if (isSelected) { items[catId].selected = true; }

                items[catId].events = {
                    click() {
                        if ($(this).is(":checked")) {
                            Server.addArchiveToCategory(id, catId);
                            if (typeof Index !== "undefined" && catId === localStorage.getItem("bookmarkCategoryId")) {
                                Index.bookmarkIconOn(id);
                            }
                        } else {
                            Server.removeArchiveFromCategory(id, catId);
                            if (typeof Index !== "undefined" && catId === localStorage.getItem("bookmarkCategoryId")) {
                                Index.bookmarkIconOff(id);
                            }
                        }
                    },
                };
            }

            if (Object.keys(items).length === 0) {
                items.noop = { name: I18N.IndexNoCategories, icon: "far fa-sad-cry" };
            }

            return items;
        },
    );
}

/**
 * Build rating options for contextMenu and select the one for the current ID.
 * @param {*} id The ID of the archive to check
 * @param {*} refreshCallback Optional callback to refresh the view after rating change
 * @returns Ratings
 */
export function loadContextMenuRatings(id, refreshCallback) {
    return Server.callAPI(`/api/archives/${id}/metadata`, "GET", null, I18N.IndexIdLoadError(id),
        (data) => {
            const items = {};
            const ratings = [{
                name: I18N.IndexRemoveRating
            }, {
                name: "⭐",
            }, {
                name: "⭐⭐",
            }, {
                name: "⭐⭐⭐",
            }, {
                name: "⭐⭐⭐⭐",
            }, {
                name: "⭐⭐⭐⭐⭐",
            }];
            const tags = splitTagsByNamespace(data.tags);
            const hasRating = Object.keys(tags).some(x => x === "rating");
            const ratingValue = hasRating ? tags["rating"] : [0];

            for (let i = 0; i < ratings.length; i++) {
                items[i] = ratings[i];
                items[i].type = "checkbox";

                if (items[i].name === ratingValue[0]) { items[i].selected = true; }
                items[i].events = {
                    click() {
                        if(i === 0) delete tags["rating"];
                        else tags["rating"] = [ratings[i].name];

                        Server.updateTagsFromArchive(id, buildTagList(tags));

                        if (refreshCallback) {
                            refreshCallback();
                        } else if (IndexTable.dataTable) {
                            IndexTable.dataTable.ajax.reload(null, false);
                            Index.updateCarousel();
                        }
                        $(this).parents("ul.context-menu-list").find("input[type='checkbox']").toArray().filter((x) => x !== this).forEach(x => x.checked = false);
                    },
                };
            }

            return items;
        },
    );
}

// #endregion

export function initializeToasts() {
    // Initialize toast.
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.textAlign = "initial";
    window.React.render(
        window.React.createElement(window.reactToastify.ToastContainer, {
            style: {},
            limit: 7,
            theme: "light",
        }, undefined), toastDiv);
}

export function setProgressTracking(_isProgressLocal, _isProgressAuthenticated) {
    isProgressLocal = _isProgressLocal;
    isProgressAuthenticated = _isProgressAuthenticated;
}