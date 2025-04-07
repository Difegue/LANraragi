/**
 * All the Archive Index functions related to DataTables.
 */
const IndexTable = {};

IndexTable.dataTable = {};
IndexTable.originalTitle = document.title;
IndexTable.isComingFromPopstate = false;
IndexTable.currentSearch = "";

/**
 * Initialize DataTables.
 */
IndexTable.initializeAll = function () {
    // Bind events to DOM
    $(document).on("click.apply-search", "#apply-search", () => { IndexTable.currentSearch = $("#search-input").val(); IndexTable.doSearch(); });
    $(document).on("click.clear-search", "#clear-search", () => { IndexTable.currentSearch = ""; IndexTable.doSearch(); });
    $(document).on("keyup.search-input", "#search-input", (e) => {
        if (e.defaultPrevented) {
            return;
        } else if (e.key === "Enter") {
            IndexTable.currentSearch = $("#search-input").val();
            IndexTable.doSearch();
        }
        e.preventDefault();
    });

    // Catch tag div clicks and do a search instead of reloading the page
    $(document).on("click.gt", ".gt", (e) => {
        e.preventDefault();
        IndexTable.currentSearch = $(e.target).attr("search");
        IndexTable.doSearch();
    });

    // Add a listen event to window.popstate to update the search accordingly
    // if the user goes back using browser history
    $(window).on("popstate", () => {
        IndexTable.isComingFromPopstate = true;
        IndexTable.consumeURLParameters();
    });

    // Clear searchbar cache
    $("#search-input").val("");

    // Classes for even/odd lines
    $.fn.dataTableExt.oStdClasses.sStripeOdd = "gtr0";
    $.fn.dataTableExt.oStdClasses.sStripeEven = "gtr1";

    // Make sure we have the correct table headers before initializing
    const columnCount = Index.getColumnCount();
    Index.generateTableHeaders(columnCount);

    let columns = [];

    // bookmark column is not sortable because it is not derived from server
    if (LRR.bookmarkLinkConfigured()) {
        columns.push({ data: null, className: "bookmark itd", name: "bookmark", orderable: false, render: IndexTable.renderBookmark });
    }
    columns.push({ data: null, className: "title itd", name: "title", render: IndexTable.renderTitle });

    // set custom columns
    for (let i = 1; i <= columnCount; i++) {
        columns.push({
            data: "tags",
            className: `customheader${i} itd`,
            name: localStorage[`customColumn${i}`] || `defaultCol${i}`,
            render: (data, type) => IndexTable.renderColumn(localStorage[`customColumn${i}`], type, data)
        });
    }
    columns.push({ data: "tags", className: "tags itd", name: "tags", orderable: false, render: IndexTable.renderTags });

    // Datatables configuration
    IndexTable.dataTable = $(".datatables").DataTable({
        serverSide: true,
        processing: true,
        ajax: {
        url: "search",
        cache: true,
        },
        deferRender: true,
        lengthChange: false,
        pageLength: Index.pageSize,
        order: [[IndexTable.getTitleIndex(), "asc"]],
        dom: "<\"top\"ip>rt<\"bottom\"p><\"clear\">",
        language: {
            info: I18N.IndexPageCount,
            infoEmpty: `<h1><br/><i class="fas fa-4x fa-toilet-paper-slash"></i><br/><br/>
                        ${I18N.IndexNoArcsFound(new LRR.apiURL("/upload"))}</h1><br/>`,
            processing: `<div id="progress" class="indeterminate"><div class="bar-container"><div class="bar" style=" width: 80%; "></div></div></div>`,
        },
        preDrawCallback: IndexTable.initializeThumbView, // callbacks for thumbnail view
        drawCallback: IndexTable.drawCallback,
        rowCallback: IndexTable.buildThumbnailCell,
        columns: columns,
    });

    // If the url has parameters, handle them now by doing the matching search.
    IndexTable.consumeURLParameters();
};

/**
 * Looks at the active filters and performs a search using DataTables' API.
 * (which is hooked back to the internal Search API)
 * If you specify a page argument, the search will load the given page.
 * @param {*} page Page to load
 */
IndexTable.doSearch = function (page) {
    // Add the selected category to the tags column so it's picked up by the search engine
    // This allows for the regular search bar to be used in conjunction with categories.
    IndexTable.dataTable.column(".tags.itd").search(Index.selectedCategory);

    // Update search input field
    $("#search-input").val(IndexTable.currentSearch);
    IndexTable.dataTable.search(IndexTable.currentSearch);

    // Add the current search terms to the title tab
    document.title = IndexTable.originalTitle + ((IndexTable.currentSearch !== "") ? ` - ${IndexTable.currentSearch}` : "");

    if (page) {
        // Hack the displayStart value to draw at the page we asked
        // eslint-disable-next-line no-underscore-dangle
        const customDisplayStart = page * IndexTable.dataTable.settings()[0]._iDisplayLength;
        IndexTable.dataTable.settings()[0].iInitDisplayStart = customDisplayStart;
    } else {
        IndexTable.dataTable.settings()[0].iInitDisplayStart = 0;
    }
    IndexTable.dataTable.draw();

    // Re-load categories so the most recently selected/created ones appear first
    Index.loadCategories();

    // Re-load carousel
    Index.updateCarousel();
};

// #region Compact View

/**
 * Generic function for rendering namespace columns.
 * @param {*} namespace The tag namespace to render
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @param {*} data The tag contents
 * @returns The table HTML, or raw data if type is data
 */
IndexTable.renderColumn = function (namespace, type, data) {
    if (type === "display") {
        if (data === "") return "";

        let namespaceRegEx = namespace;
        if (namespace === "series") namespaceRegEx = "(?:series|parody)";
        const regex = new RegExp(`.*${namespaceRegEx}:\\s?([^,]*),*.*`, "gi"); // Catch last namespace:xxx value in tags
        const match = regex.exec(data);

        if (match != null) {
            let tagText = match[1].replace(/\b./g, (m) => m.toUpperCase());
            // If namespace is a date, consider the contents are a UNIX timestamp
            if (namespace === "date_added" || namespace === "timestamp") {
                const date = new Date(match[1] * 1000);
                tagText = date.toLocaleDateString();
            }

            return `<a style="cursor:pointer" href="${LRR.getTagSearchURL(namespace, match[1])}">
                        ${tagText}
                    </a>`;
        } else return "";
    }
    return data;
};

/**
 * Render the bookmark column. Checkbox is enabled only if the user is logged in.
 * @param {*} data Archive data
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw data if type is data
 */
IndexTable.renderBookmark = function (data, type) {
    if ( LRR.bookmarkLinkConfigured() ) {
        const isBookmarked = JSON.parse(localStorage.getItem("bookmarkedArchives") || "[]").includes(data.arcid);
        if (type === "display") {
            const disabledAttr = LRR.isUserLogged() ? '' : 'disabled';
            const disabledStyle = LRR.isUserLogged() ? '' : 'style="opacity: 0.5; cursor: not-allowed;"';
            return `<input class="bookmark-checkbox" id="${data.arcid}" type="checkbox" title="Toggle Bookmark" ${isBookmarked ? 'checked' : ''} ${disabledAttr} ${disabledStyle}>`;
        }
        return isBookmarked;
    }
    if (type === "display") {
        return `<input class="bookmark-checkbox" id="${data.arcid}" type="checkbox" disabled title="Link bookmark to category to use the checkbox.">`;
    }
    return false;
}

/**
 * Render the title column.
 * @param {*} data Title
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw title if type is data
 */
IndexTable.renderTitle = function (data, type) {
    if (type === "display") {
        // For compact mode, the thumbnail API call enforces no_fallback=true in order to queue Minion jobs for missing thumbnails.
        // (Since compact mode is the "base", it's always loaded first even if you're in table mode)
        return `${LRR.buildProgressDiv(data)} 
                <a class="context-menu" id="${data.arcid}" onmouseover="IndexTable.buildImageTooltip(this)" href="${new LRR.apiURL(`/reader?id=${data.arcid}`)}"> 
                    ${LRR.encodeHTML(data.title)}
                </a>
                <div class="caption" style="display: none;">
                    <img style="height:300px" src="${new LRR.apiURL(`/api/archives/${data.arcid}/thumbnail?no_fallback=true`)}" 
                         onerror="this.src='${new LRR.apiURL('/img/noThumb.png')}'">
                </div>`;
    }

    return data.title;
};

/**
 * Render the tags column.
 * @param {*} data Tags
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw tags if type is data
 */
IndexTable.renderTags = function (data, type) {
    if (type === "display") {
        return `<span class="tag-tooltip" onmouseover="IndexTable.buildTagTooltip(this)" style="text-overflow:ellipsis;">
                    ${LRR.colorCodeTags(data)}
                </span>
                <div class="caption caption-tags" style="display: none;" >
                    ${LRR.buildTagsDiv(data)}
                </div>`;
    }
    return data;
};

// #endregion

// #region Thumbnail View
// Functions executed on DataTables draw callbacks to build the thumbnail view if it's enabled:

/**
 * Inits the div that contains the thumbnails
 */
IndexTable.initializeThumbView = function () {
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

        IndexTable.dataTable.columns?.adjust();
    }
};

/**
 * Builds a id1 class div to jam in the thumb container for the given archive data
 * @param {*} row matching DataTables row
 * @param {*} data raw data
 */
IndexTable.buildThumbnailCell = function (row, data) {
    if (localStorage.indexViewMode === "1") {
        // Build a thumb-like div with the data
        $("#thumbs_container").append(LRR.buildThumbnailDiv(data));
    }
};

// #endregion

// #region Pushstate/Popstate URL parameters handling

/**
 * Called after the table is drawn. Updates page selector.
 * (And handles pushing the search parameters to the URL)
 */
IndexTable.drawCallback = function () {
    if (typeof (IndexTable.dataTable) !== "undefined") {
        const pageInfo = IndexTable.dataTable.page.info();
        if (pageInfo.pages === 0) {
            $(".itg").hide();
        } else {
            $(".itg").show();
        }

        // Update url to contain all search parameters, and push it to the history
        if (IndexTable.isComingFromPopstate) {
            // But don't fire this if we're coming from popstate
            IndexTable.isComingFromPopstate = false;
        } else {
            let params = IndexTable.buildURLParameters();
            if (params === "?") params = "/";
            window.history.pushState(null, null, params);
        }

        const currentSort = IndexTable.dataTable.order()[0][0];
        const currentOrder = IndexTable.dataTable.order()[0][1];

        // Save sort/order/page to localStorage
        localStorage.indexSort = currentSort;
        localStorage.indexOrder = currentOrder;

        let titleIndex = IndexTable.getTitleIndex();
        let sortNamespace;
        if (currentSort >= titleIndex + 1 && currentSort < (titleIndex + 1 + Index.getColumnCount())) {
            const customIndex = currentSort - 1;
            sortNamespace = localStorage[`customColumn${customIndex}`] || `Header ${customIndex}`;
        } else {
            sortNamespace = "title";
        }

        Index.updateTableControls(sortNamespace, currentOrder, pageInfo.pages, pageInfo.page + 1);

        // Clear potential leftover tooltips
        tippy.hideAll();
    }
};

IndexTable.buildURLParameters = function () {
    const cat = IndexTable.dataTable.column(".tags.itd").search();
    const page = IndexTable.dataTable.page.info().page + 1;
    const sortby = IndexTable.dataTable.order()[0][0];
    const sortorder = IndexTable.dataTable.order()[0][1];

    const encodedSearch = encodeURIComponent(IndexTable.dataTable.search());

    // Check each parameter and append them to the URL if they exist
    let params = "?";
    if (page !== 1) params += `p=${page}&`;
    if (sortby !== 0) params += `sort=${sortby}&`;
    if (sortorder !== "asc") params += `sortdir=${sortorder}&`;
    if (encodedSearch !== "") params += `q=${encodedSearch}&`;
    if (cat !== "") params += `c=${cat}&`;

    return params;
};

IndexTable.consumeURLParameters = function () {
    const params = new URLSearchParams(window.location.search);

    if (params.has("c")) Index.selectedCategory = params.get("c");
    else Index.selectedCategory = "";

    if (params.has("q")) { IndexTable.currentSearch = decodeURIComponent(params.get("q")); }

    const titleIndex = IndexTable.getTitleIndex();
    const order = [[titleIndex, "asc"]];

    if (params.has("sort")) {
        order[0][0] = parseInt(params.get("sort"), 10);
    } else if (localStorage.indexSort) {
        order[0][0] = parseInt(localStorage.indexSort, 10);
    }

    // Validate column count and fallback to title.
    const columnCount = IndexTable.dataTable.columns().count();
    if (order[0][0] >= columnCount) {
        console.warn(`Invalid sort index ${order[0][0]} >= ${columnCount}, fallback to title.`);
        order[0][0] = titleIndex;
    }

    if (params.has("sortdir")) {
        order[0][1] = params.get("sortdir");
    } else if (localStorage.indexOrder) {
        order[0][1] = localStorage.indexOrder;
    }

    IndexTable.dataTable.order(order);

    if (params.has("p")) {
        IndexTable.doSearch(params.get("p") - 1);
    } else {
        IndexTable.doSearch();
    }
};

// #endregion

/**
 * Build a tooltip when hovering over an archive title, then display it.
 * The tooltip is saved in DOM for further uses.
 * @param {*} target The target archive title
 * @returns
 */
IndexTable.buildImageTooltip = function (target) {
    if (target.innerHTML === "") return;

    tippy(target, {
        content: $(target).next("div").clone().attr("style", "height:300px;")[0],
        delay: 0,
        animation: false,
        maxWidth: "none",
        followCursor: true,
    }).show(); // Call show() so that the tooltip shows now

    $(target).attr("onmouseover", ""); // Don't trigger this function again for this element
};

/**
 * Build a tooltip when hovering over a tag div, then display it.
 * @param {*} target The target tags div
 */
IndexTable.buildTagTooltip = function (target) {
    tippy(target, {
        content: $(target).next("div").attr("style", "")[0],
        delay: 0,
        placement: "auto-start",
        maxWidth: "none",
        interactive: true,
        // Have to be outside so that it is not hidden by other elements.
        appendTo: document.body,
    }).show(); // Call show() so that the tooltip shows now

    $(target).attr("onmouseover", "");
};

/**
 * When bookmark is configured, the title column is the second column, otherwise it's the first column
 * @returns index of title column in compact mode
 */
IndexTable.getTitleIndex = function () {
    return LRR.bookmarkLinkConfigured() ? 1 : 0;
};
