
/**
 * Functions that get used in multiple pages but don't really depend on networking.
 */

// Quick 'n dirty HTML encoding function.
function encode(r) {
    if (r === undefined)
        return r;
    if (Array.isArray(r))
        return r[0].replace(/[\x26\x0A\<>'"]/g, function (r) { return "&#" + r.charCodeAt(0) + ";" });
    else
        return r.replace(/[\x26\x0A\<>'"]/g, function (r) { return "&#" + r.charCodeAt(0) + ";" })
}

function openInNewTab(url) {
    var win = window.open(url, '_blank');
    win.focus();
}

// Applies to Index and Reader.
function openSettings() {
    $('#overlay-shade').fadeTo(150, 0.6, function () {
        $('#settingsOverlay').css('display', 'block');
    });
}

// Ditto
function closeOverlay() {
    $('#overlay-shade').fadeOut(300);
    $('.base-overlay').css('display', 'none');
}

/**
 * Remove namespace from tags and color-code them. Meant for inline display.
 * @param {*} tags string containing all tags, split by commas.
 * @returns 
 */
function colorCodeTags(tags) {
    line = "";
    if (tags === "")
        return line;

    tagsByNamespace = splitTagsByNamespace(tags);
    Object.keys(tagsByNamespace).sort().forEach(function (key, index) {
        tagsByNamespace[key].forEach(function (tag) {
            var encodedK = encode(key.toLowerCase());
            line += `<span class='${encodedK}-tag'>${encode(tag)}</span>, `;
        });
    });
    // Remove last comma
    return line.slice(0, -2);
}

function splitTagsByNamespace(tags) {

    var tagsByNamespace = {};

    if (tags === null || tags === undefined) {
        return tagsByNamespace;
    }

    tags.split(/,\s?/).forEach(function (tag) {
        nspce = null;
        val = null;

        //Split the tag from its namespace
        arr = tag.split(/:\s?/);
        if (arr.length == 2) {
            nspce = arr[0].trim();
            val = arr[1].trim();
        } else {
            nspce = "other";
            val = arr;
        }

        if (nspce in tagsByNamespace)
            tagsByNamespace[nspce].push(val);
        else
            tagsByNamespace[nspce] = [val];

    });

    return tagsByNamespace;
}

/**
 * Builds a caption div containing clickable tags. Namespaces are resolved on the fly.
 * @param {*} tags string containing all tags, split by commas.
 * @returns the div
 */
function buildTagsDiv(tags) {
    if (tags === "")
        return "";

    tagsByNamespace = splitTagsByNamespace(tags);

    line = '<table class="itg" style="box-shadow: 0 0 0 0; border: none; border-radius: 0" ><tbody>';

    //Go through resolved namespaces and print tag divs
    Object.keys(tagsByNamespace).sort().forEach(function (key, index) {

        ucKey = key.charAt(0).toUpperCase() + key.slice(1);
        ucKey = encode(ucKey);
        encodedK = encode(key.toLowerCase());
        line += `<tr><td class='caption-namespace ${encodedK}-tag'>${ucKey}:</td><td>`;

        tagsByNamespace[key].forEach(function (tag) {
            fullTag = (key !== "other") ? key + ":" + tag : tag;

            line += `<div class="gt">
					 	<a onclick="fillSearchField(event, '${encode(fullTag)}')" 
						   href="/?q=${encodeURIComponent(fullTag)}">
						   ${encode(tag)}
						</a>
					 </div>`;
        });

        line += "</td></tr>";
    });

    line += '</tbody></table>';
    return line;
}