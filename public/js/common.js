/**
 * Functions that get used in multiple pages but don't really depend on networking.
 */
const LRR = {};

/**
 * Quick 'n dirty HTML encoding function.
 * @param {*} r The HTML to encode
 * @returns Encoded string
 */
LRR.encodeHTML = function (r) {
    if (r === undefined) return r;
    if (Array.isArray(r)) return r[0].replace(/[\x26\x0A\<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
    else return r.replace(/[\x26\x0A\<>'"]/g, (r2) => `&#${r2.charCodeAt(0)};`);
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
    return (namespace !== "source") ? `/?q=${encodeURIComponent(namespacedTag)}` : `http://${tag}`;
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
 * Applies to Index and Reader.
 */
LRR.openSettings = function () {
    $("#overlay-shade").fadeTo(150, 0.6, () => {
        $("#settingsOverlay").css("display", "block");
    });
};

/**
 * Applies to Index and Reader.
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
    Object.keys(tagsByNamespace).sort().forEach((key) => {
        tagsByNamespace[key].forEach((tag) => {
            const encodedK = LRR.encodeHTML(key.toLowerCase());
            line += `<span class='${encodedK}-tag'>${LRR.encodeHTML(tag)}</span>, `;
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

            line += `<div class="gt">
                        <a href="${url}">
                            ${LRR.encodeHTML(tag)}
                        </a>
                    </div>`;
        });

        line += "</td></tr>";
    });

    line += "</tbody></table>";
    return line;
};

/**
 * Show a generic error toast with a given header and message.
 * @param {*} header Error header
 * @param {*} error Error message
 */
LRR.showErrorToast = function (header, error) {
    $.toast({
        showHideTransition: "slide",
        position: "top-left",
        loader: false,
        heading: header,
        text: error,
        hideAfter: false,
        icon: "error",
    });
};
