/**
 * Functions that get used in multiple pages but don't really depend on networking.
 */
const LRR = {};

/**
 * Quick HTML encoding function.
 * @param {*} r The HTML to encode
 * @returns Encoded string
 */
LRR.encodeHTML = function (r) {
    if (r === undefined) return r;
    if (Array.isArray(r)) {
        return r[0].replace(/[\n&<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
    } else {
        return r.replace(/[\n&<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
    }
};

/**
 * Unix timestamp converting function.
 * @param {number} r The timestamp to convert
 * @returns Converted string
 */
LRR.convertTimestamp = function (r) {
    return (new Date(r * 1000)).toLocaleDateString();
};

/**
 * Check if we're running on a mobile browser.
 */
LRR.isMobile = function () {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
};

/**
 * Checks if the given string is null or whitespace.
 * @param {*} input The string to check
 * @returns true or false
 */
LRR.isNullOrWhitespace = function (input) {
    return !input || !input.trim();
};

/**
 * Get the URL to search for a given tag.
 * @param {*} namespace Tag namespace
 * @param {*} tag tag
 * @returns The URL.
 */
LRR.getTagSearchURL = function (namespace, tag) {
    const namespacedTag = this.buildNamespacedTag(namespace, tag);
    if (namespace !== "source") {
        return `/?q=${encodeURIComponent(namespacedTag)}`;
    } else if (/https?:\/\//.test(tag)) {
        return `${tag}`;
    } else {
        return `https://${tag}`;
    }
};

/**
 * Open the given URL in a new browser tab.
 * @param {*} url The URL
 */
LRR.openInNewTab = function (url) {
    const win = window.open(url, "_blank");
    win.focus();
};

/**
 * Toggles the visibility of the base-overlay div that's in the given selector.
 * @param {*} selector
 * @returns
 */
LRR.toggleOverlay = function (selector) {
    const overlay = $(selector);
    overlay.is(":visible")
        ? LRR.closeOverlay()
        : $("#overlay-shade").fadeTo(150, 0.6, () => overlay.show());

    return false; // needs to return false to prevent scrolling to top
};

/**
 * Close any opened overlay that uses base-overlay.
 */
LRR.closeOverlay = function () {
    $("#overlay-shade").fadeOut(300);
    $(".base-overlay").css("display", "none");
};

/**
 * Get a string representation of a namespace+tag combo.
 * The namespace is omitted if blank or "other".
 * @param {*} namespace The namespace
 * @param {*} tag The tag
 * @returns namespace:tag, or tag alone.
 */
LRR.buildNamespacedTag = function (namespace, tag) {
    return (namespace !== "" && namespace !== "other") ? `${namespace}:${tag}` : tag;
};

/**
 * Remove namespace from tags and color-code them. Meant for inline display.
 * @param {*} tags string containing all tags, split by commas.
 * @returns
 */
LRR.colorCodeTags = function (tags) {
    let line = "";
    if (tags === "") return line;

    const tagsByNamespace = LRR.splitTagsByNamespace(tags);
    const filteredTags = Object.keys(tagsByNamespace).filter((tag) => tag !== "date_added" && tag !== "timestamp");
    let tagsToEncode;

    if (filteredTags.length) {
        tagsToEncode = filteredTags.sort();
    } else {
        tagsToEncode = Object.keys(tagsByNamespace).sort();
    }

    tagsToEncode.sort().forEach((key) => {
        tagsByNamespace[key].forEach((tag) => {
            const encodedK = LRR.encodeHTML(key.toLowerCase());
            const encodedVal = LRR.encodeHTML(key === "date_added" || key === "timestamp" ? LRR.convertTimestamp(tag) : tag);
            line += `<span class='${encodedK}-tag'>${encodedVal}</span>, `;
        });
    });
    // Remove last comma
    return line.slice(0, -2);
};

/**
 * Splits a LRR tag string into a per-namespace dictionary of arrays.
 * @param {*} tags string containing all tags, split by commas.
 * @returns The tag dictionary
 */
LRR.splitTagsByNamespace = function (tags) {
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
};

/**
 * Builds a caption div containing clickable tags. Namespaces are resolved on the fly.
 * @param {*} tags string containing all tags, split by commas.
 * @returns the div
 */
LRR.buildTagsDiv = function (tags) {
    if (tags === "") return "";

    const tagsByNamespace = LRR.splitTagsByNamespace(tags);

    let line = "<table class=\"itg\" style=\"box-shadow: 0 0 0 0; border: none; border-radius: 0\" ><tbody>";

    // Go through resolved namespaces and print tag divs
    Object.keys(tagsByNamespace).sort().forEach((key) => {
        let ucKey = key.charAt(0).toUpperCase() + key.slice(1);
        ucKey = LRR.encodeHTML(ucKey);

        const encodedK = LRR.encodeHTML(key.toLowerCase());
        line += `<tr><td class='caption-namespace ${encodedK}-tag'>${ucKey}:</td><td>`;

        tagsByNamespace[key].forEach((tag) => {
            const url = LRR.getTagSearchURL(key, tag);
            const searchTag = LRR.buildNamespacedTag(key, tag);

            const tagText = LRR.encodeHTML(key === "date_added" || key === "timestamp" ? LRR.convertTimestamp(tag) : tag);

            line += `<div class="gt">
                        <a href="${url}" search="${LRR.encodeHTML(searchTag)}">
                            ${tagText}
                        </a>
                    </div>`;
        });

        line += "</td></tr>";
    });

    line += "</tbody></table>";
    return line;
};

/**
 * Build a thumbnail div for the given archive data.
 * @param {*} data The archive data
 * @param {boolean} tagTooltip Option to build TagTooltip on mouseover
 * @returns HTML component string
 */
LRR.buildThumbnailDiv = function (data, tagTooltip = true) {
    const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
    // The ID can be in a different field depending on the archive object...
    const id = data.arcid || data.id;

    return `<div class="id1 context-menu swiper-slide" id="${id}">
                <div class="id2">
                    ${LRR.buildProgressDiv(data)}
                    <a href="reader?id=${id}" title="${LRR.encodeHTML(data.title)}">${LRR.encodeHTML(data.title)}</a>
                </div>
                <div class="${thumbCss}">
                    <a href="reader?id=${id}" title="${LRR.encodeHTML(data.title)}">
                        <img style="position:relative;" id="${id}_thumb" src="./img/wait_warmly.jpg"/>
                        <i id="${id}_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>
                        <img src="./api/archives/${id}/thumbnail" 
                                onload="$('#${id}_thumb').remove(); $('#${id}_spinner').remove();" 
                                onerror="this.src='./img/noThumb.png'"/>
                    </a>
                </div>
                <div class="id4">
                        <span class="tags tag-tooltip" ${tagTooltip === true ? "onmouseover=\"IndexTable.buildTagTooltip(this)\"" : ""}>${LRR.colorCodeTags(data.tags)}</span>
                        ${tagTooltip === true ? `<div class="caption caption-tags" style="display: none;" >${LRR.buildTagsDiv(data.tags)}</div>` : ""}
                </div>
            </div>`;
};

/**
 * Show an emoji or a progress number for the given archive data.
 * @param {*} arcdata The archive data object
 * @returns HTML string
 */
LRR.buildProgressDiv = function (arcdata) {
    const id = arcdata.arcid;
    const { isnew } = arcdata;
    const pagecount = parseInt(arcdata.pagecount || 0, 10);
    let progress = -1;

    if (Index.isProgressLocal) {
        progress = parseInt(localStorage.getItem(`${id}-reader`) || 0, 10);
    } else {
        progress = parseInt(arcdata.progress || 0, 10);
    }

    if (isnew === "true") {
        return "<div class=\"isnew\">🆕</div>";
    } else if (pagecount > 0) {
        // Consider an archive read if progress is past 85% of total
        if ((progress / pagecount) > 0.85) return "<div class='isnew'>👑</div>";
        else return `<div class='isnew'><sup>${progress}/${pagecount}</sup></div>`;
    }
    // If there wasn't sufficient data, return an empty string
    return "";
};

/**
 * Show a generic error toast with a given header and message.
 * @param {*} header Error header
 * @param {*} error Error message
 */
LRR.showErrorToast = function (header, error) {
    LRR.toast({
        heading: header,
        text: error,
        icon: "error",
        hideAfter: false,
    });
};

/**
 * Show a pop-up window to request user input.
 * @param {*} c Pop-up body
 */
LRR.showPopUp = function (c) {
    return window.Swal.fire(c);
};

/**
 * Fires a HEAD request to get filesize of a given URL.
 * return target img size.
 * @param {*} target Target URL String
 */
LRR.getImgSize = function (target) {
    let imgSize = 0;
    $.ajax({
        async: false,
        url: target,
        type: "HEAD",
        success: (data, textStatus, request) => {
            imgSize = parseInt(request.getResponseHeader("Content-Length") / 1024, 10);
        },
    });
    return imgSize;
};

/**
 * Show a generic toast with a given header and message.
 * This is a compatibility layer to migrate jquery-toast-plugin to react-toastify.
 * @param {*} c Toast body
 */
LRR.toast = function (c) {
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
};

jQuery(() => {
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
});
