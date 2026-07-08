/**
 * All the Archive Index functions related to DataTables.
 */
import * as LRR from "./common.js";
import * as Index from "./index.js";
import I18N from "i18n";

export let dataTable = {};
let originalTitle = document.title;
let isComingFromPopstate = false;
export let currentSearch = "";

/**
 * Initialize DataTables.
 */
export function initializeAll() {
    // Bind events to DOM
    $(document).on("click.apply-search", "#apply-search", () => { currentSearch = $("#search-input").val(); doSearch(); });
    $(document).on("click.clear-search", "#clear-search", () => { currentSearch = ""; doSearch(); });
    $(document).on("keyup.search-input", "#search-input", (e) => {
        if (e.defaultPrevented) {
            return;
        } else if (e.key === "Enter") {
            currentSearch = $("#search-input").val();
            doSearch();
        }
        e.preventDefault();
    });

    // Catch tag div clicks and do a search instead of reloading the page
    $(document).on("click.gt", ".gt", (e) => {

        if (e.target.hasAttribute("search")) {
            e.preventDefault();
            currentSearch = $(e.target).attr("search");
            doSearch();
        }
    });

    // Mark datatables-originated reader links so Reader can decide whether to enable cross-archive navigation.
    // Excludes anything inside the carousel; that's tagged separately in ContextMenu.initializeAll.
    $(document).on("click.datatables-navstate", "a[href*='/reader?id=']", function () {
        if ($(this).closest(".swiper-wrapper").length > 0) return;
        sessionStorage.setItem("navigationState", "datatables");
    });

    // Add a listen event to window.popstate to update the search accordingly
    // if the user goes back using browser history
    $(window).on("popstate", () => {
        isComingFromPopstate = true;
        consumeURLParameters();
    });

    // Clear searchbar cache
    $("#search-input").val("");

    // Classes for even/odd lines
    $.fn.dataTableExt.oStdClasses.sStripeOdd = "gtr0";
    $.fn.dataTableExt.oStdClasses.sStripeEven = "gtr1";

    // set custom columns
    const columns = [];
    columns.push({
        data: null, className: "title itd", name: "title", render: renderTitle,
    });
    const columnCount = Index.getColumnCount();
    // set custom columns
    for (let i = 1; i <= columnCount; i++) {
        columns.push({
            data: "tags",
            className: `customheader${i} itd`,
            name: localStorage[`customColumn${i}`] || `defaultCol${i}`,
            render: (data, type) => renderColumn(localStorage[`customColumn${i}`], type, data),
        });
    }
    columns.push({
        data: "tags", className: "tags itd", name: "tags", orderable: false, render: renderTags,
    });

    // Store the page size in localStorage for use in the reader
    localStorage.setItem("datatablesPageSize", Index.pageSize.toString());

    // Datatables configuration
    dataTable = $(".datatables").DataTable({
        serverSide: true,
        processing: true,
        ajax: {
            url: "search",
            cache: true,
            data: (d) => {
                if (localStorage.hidecompleted === "true") {
                    d.hidecompleted = "true";
                }
                if (localStorage.grouptanks === "false") {
                    d.grouptanks = "false";
                }
                return d;
            },
        },
        deferRender: true,
        lengthChange: false,
        pageLength: Index.pageSize,
        order: [[0, "asc"]],
        dom: `<"top"ip>rt<"bottom"p><"clear">`,
        language: {
            info: I18N.IndexPageCount,
            infoEmpty: `<h1><br/><i class="fas fa-4x fa-sad-cry"></i><br/><br/>
                        ${I18N.IndexNoArcsFound(new LRR.ApiURL("/upload"))}</h1><br/>`,
            processing: `<div id="progress" class="indeterminate"><div class="bar-container"><div class="bar" style="width: 80%;"></div></div></div>`,
        },
        preDrawCallback: initializeThumbView, // callbacks for thumbnail view
        drawCallback: drawCallback,
        createdRow: createdRow,
        columns,
    });

    // If the url has parameters, handle them now by doing the matching search.
    consumeURLParameters();
}

/**
 * Looks at the active filters and performs a search using DataTables' API.
 * (which is hooked back to the internal Search API)
 * If you specify a page argument, the search will load the given page.
 * @param {number} page Page to load
 */
export function doSearch(page) {
    // Add the selected category to the tags column so it's picked up by the search engine
    // This allows for the regular search bar to be used in conjunction with categories.
    dataTable.column(".tags.itd").search(Index.selectedCategory);

    // Store search parameters in localStorage for archive navigation
    localStorage.setItem("currentSearch", currentSearch);
    localStorage.setItem("selectedCategory", Index.selectedCategory);

    // Update search input field
    $("#search-input").val(currentSearch);
    dataTable.search(currentSearch);

    // Add the current search terms to the title tab
    document.title = originalTitle + ((currentSearch !== "") ? ` - ${currentSearch}` : "");

    if (page) {
        // Hack the displayStart value to draw at the page we asked
        const customDisplayStart = page * dataTable.settings()[0]._iDisplayLength;
        dataTable.settings()[0].iInitDisplayStart = customDisplayStart;
    } else {
        dataTable.settings()[0].iInitDisplayStart = 0;
    }
    dataTable.draw();

    // Re-load categories so the most recently selected/created ones appear first
    Index.loadCategories();

    // Re-load carousel
    Index.updateCarousel();
}

// #region Compact View

/**
 * Generic function for rendering namespace columns.
 * @param {*} namespace The tag namespace to render
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @param {*} data The tag contents
 * @returns The table HTML, or raw data if type is data
 */
export function renderColumn(namespace, type, data) {
    if (type === "display") {
        if (data === "") return "";
        const regex = new RegExp(`${namespace}:([^,]+)`, "g"); // catch all values associated to the given namespace
        const matches = [...data.matchAll(regex)];

        if (matches != null) {
            let tagLinks = "";
            matches.forEach((match) => {
                let tagText = match[1];
                // If namespace is a date, consider the contents are a UNIX timestamp
                if (namespace === "date_added" || namespace === "timestamp") {
                    tagText = LRR.convertTimestamp(tagText);
                } else if (namespace !== "source") {
                    // Don't capitalize URLs to avoid breaking the hotlink
                    tagText = tagText.replace(/\b./g, (m) => m.toUpperCase());
                }
                const tagUrl = `${LRR.getTagSearchURL(namespace, tagText)}`;
                tagLinks += `<a style="cursor:pointer" href="${LRR.encodeHTML(tagUrl)}">${LRR.encodeHTML(tagText)}</a>, `;
            });

            const spanTags = tagLinks.slice(0, -2); // remove the last comma and space
            const popupTags = matches.map((match) => match[0]).join(","); //
            return `
                <span class="tag-tooltip" onmouseover="window.LRR.buildTagTooltip(this)" style="text-overflow:ellipsis;">${spanTags}</span>
                <div class="caption caption-tags" style="display: none;" >${LRR.buildTagsDiv(popupTags)}</div>
            `;
        } else return "";
    }
    return data;
}

/**
 * Render the title column.
 * @param {*} data Title
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw title if type is data
 */
export function renderTitle(data, type) {
    if (type === "display") {
        const bookmarkIcon = LRR.buildBookmarkIconElement(data.arcid, "title-bookmark-icon");
        // For compact mode, the thumbnail API call enforces no_fallback=true in order to queue Minion jobs for missing thumbnails.
        // (Since compact mode is the "base", it's always loaded first even if you're in table mode)
        const thumbSrc = data.arcid.startsWith("TANK_")
            ? new LRR.ApiURL(`/api/tankoubons/${data.arcid}/thumbnail?no_fallback=true`)
            : new LRR.ApiURL(`/api/archives/${data.arcid}/thumbnail?no_fallback=true`);

        return `${LRR.buildStatusDiv(data)}${LRR.buildPageCountDiv(data)}${bookmarkIcon}
                <a id="${data.arcid}"
                   onmouseover="IndexTable.buildImageTooltip(this)"
                   href="${new LRR.ApiURL(`/reader?id=${data.arcid}`)}">
                    ${LRR.encodeHTML(data.title)}
                </a>
                <div class="caption" style="display: none;">
                    <img style="height:300px" src="${thumbSrc}"
                         onerror="this.src='${new LRR.ApiURL("/img/noThumb.png")}'">
                </div>`;
    }

    return data.title;
}

/**
 * Render the tags column.
 * @param {*} data Tags
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw tags if type is data
 */
export function renderTags(data, type) {
    if (type === "display") {
        return `<span class="tag-tooltip" onmouseover="window.LRR.buildTagTooltip(this)" style="text-overflow:ellipsis;">
                    ${LRR.colorCodeTags(data)}
                </span>
                <div class="caption caption-tags" style="display: none;" >
                    ${LRR.buildTagsDiv(data)}
                </div>`;
    }
    return data;
}

// #endregion

// #region Thumbnail View
// Functions executed on DataTables draw callbacks to build the thumbnail view if it's enabled:

/**
 * Inits the div that contains the thumbnails
 */
export function initializeThumbView() {
    // we only do all this thingamajang if thumbnail view is enabled
    if (localStorage.indexViewMode === "1") {
        // Create a thumbs container if it doesn't exist. put it in the dataTables_scrollbody div
        if ($("#thumbs_container").length < 1) $(".datatables").after("<div id='thumbs_container'></div>");

        // clear out the thumbs container
        $("#thumbs_container").html("");

        $(".list").hide();
    } else {
        // Destroy the thumb container, make the table visible again and ensure autowidth is correct
        $("#thumbs_container").remove();
        $(".list").show();

        // Nuke style of table
        // Datatables' auto-width gets a bit lost when coming back from thumb view.
        $(".datatables").attr("style", "");

        dataTable.columns?.adjust();
    }
}

/**
 * Modifications when a row is created
 * @param {HTMLElement} row matching DataTables row
 * @param {[] | object} data raw data
 * @param {number} dataIndex index of row
 * @param {Node[]} cells cells for the column
 */
export function createdRow(row, data, dataIndex, cells) {
    // Update row with id and context-menu class
    row.id = data.arcid || data.id;
    row.classList.add("context-menu");
    // Builds a id1 class div to jam in the thumb container for the given archive data
    if (localStorage.indexViewMode === "1") {
        // Build a thumb-like div with the data
        $("#thumbs_container").append(LRR.buildThumbnailDiv(data));

        // Apply selection highlight immediately if the archive is already selected
        if (Index.isMultiSelectMode && Index.selectedArchives.has(data.arcid || data.id)) {
            $(`#thumbs_container #${data.arcid || data.id}`).addClass("msm-selected");
        }
    }
}

// #endregion

// #region Pushstate/Popstate URL parameters handling

/**
 * Called after the table is drawn. Updates page selector.
 * (And handles pushing the search parameters to the URL)
 */
export function drawCallback() {
    if (typeof (dataTable) !== "undefined") {
        const pageInfo = dataTable.page.info();
        if (pageInfo.pages === 0) {
            $(".itg").hide();
        } else {
            $(".itg").show();
        }

        // Store archive IDs in localStorage in the order they appear in the table,
        // so the Reader can navigate to neighbors without re-querying.
        const archiveIds = [];
        const archives = dataTable.rows().data();
        for (let i = 0; i < archives.length; i++) {
            archiveIds.push(archives[i].arcid);
        }
        localStorage.setItem("currArchiveIds", JSON.stringify(archiveIds));
        localStorage.setItem("currDatatablesPage", pageInfo.page + 1);

        // Clear previous/next archive IDs when changing pages manually
        // to avoid stale neighbors when using the browser back button.
        localStorage.removeItem("previousArchiveIds");
        localStorage.removeItem("nextArchiveIds");

        // Update url to contain all search parameters, and push it to the history
        if (isComingFromPopstate) {
            // But don't fire this if we're coming from popstate
            isComingFromPopstate = false;
        } else {
            let params = buildURLParameters();
            // don't push duplicate state entries, because that would wipe out forward history and
            // require multiple 'back' presses to go back)
            if (params === "?") {
                // special case for empty search params: window.location.search is "" if there are
                // no search params, even if window.location ends with '?'
                if (window.location.search !== "") {
                    window.history.pushState(null, null, "/");
                }
            } else if (params !== window.location.search) {
                window.history.pushState(null, null, params);
            }
        }

        const sortColumn = dataTable.order()[0][0];
        const currentOrder = dataTable.order()[0][1];
        const currentSort = dataTable.settings()[0].aoColumns[sortColumn].sName;

        // Save sort/order/page to localStorage
        localStorage.indexSort = currentSort;
        localStorage.indexOrder = currentOrder;

        Index.updateTableControls(currentSort, currentOrder, pageInfo.pages, pageInfo.page + 1);

        // Re-apply selection highlights after each draw
        Index.applySelectionHighlights();

        // Clear potential leftover tooltips
        tippy.hideAll();
    }
}

export function buildURLParameters() {
    const cat = dataTable.column(".tags.itd").search();
    const page = dataTable.page.info().page + 1;
    const sortby = dataTable.order()[0][0];
    const sortorder = dataTable.order()[0][1];

    const encodedSearch = encodeURIComponent(dataTable.search());

    // Check each parameter and append them to the URL if they exist
    let params = "?";
    if (page !== 1) params += `p=${page}&`;
    if (sortby !== 0) {
        const encodedSortBy = encodeURIComponent(dataTable.settings()[0].aoColumns[sortby].sName);
        params += `sort=${encodedSortBy}&`;
    }
    if (sortorder !== "asc") params += `sortdir=${sortorder}&`;
    if (encodedSearch !== "") params += `q=${encodedSearch}&`;
    if (cat !== "") params += `c=${cat}&`;

    return params;
}

export function consumeURLParameters() {
    const params = new URLSearchParams(window.location.search);

    if (params.has("c")) Index.setSelectedCategory(params.get("c"));
    else Index.setSelectedCategory("");

    if (params.has("q")) { currentSearch = decodeURIComponent(params.get("q")); }

    // Get order from URL, fallback to localstorage if available
    const order = [[0, "asc"]];

    // Resolve the sort sName to a column index.
    // Unresolvable values (an old numeric bookmark, or a namespace with no column) fall back to title (0).
    let sortName;
    if (params.has("sort")) {
        sortName = params.get("sort");
    } else {
        console.info("No sort field in query params; falling back to localStorage.indexSort.");
        sortName = localStorage.indexSort;
    }
    if (sortName) {
        const sortColumn = dataTable.settings()[0].aoColumns.findIndex((col) => col.sName === sortName);
        if (sortColumn !== -1) {
            order[0][0] = sortColumn;
        } else {
            console.warn(`Unresolvable sort "${sortName}"; no matching column, falling back to title.`);
            order[0][0] = 0;
        }
    }

    if (params.has("sortdir")) {
        order[0][1] = params.get("sortdir");
    } else if (localStorage.indexOrder) {
        order[0][1] = localStorage.indexOrder;
    }

    dataTable.order(order);

    if (params.has("p")) {
        doSearch(params.get("p") - 1);
    } else {
        doSearch();
    }
}

// #endregion

/**
 * Build a tooltip when hovering over an archive title, then display it.
 * The tooltip is saved in DOM for further uses.
 * @param {*} target The target archive title
 * @returns
 */
export function buildImageTooltip(target) {
    if (target.innerHTML === "") return;

    tippy(target, {
        content: $(target).next("div").clone().attr("style", "height:300px;")[0],
        delay: 0,
        animation: false,
        maxWidth: "none",
        followCursor: true,
    }).show(); // Call show() so that the tooltip shows now

    $(target).attr("onmouseover", ""); // Don't trigger this function again for this element
}
