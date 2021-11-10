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

    // Datatables configuration
    IndexTable.dataTable = $(".datatables").DataTable({
        serverSide: true,
        processing: true,
        ajax: "search",
        deferRender: true,
        lengthChange: false,
        pageLength: Index.pageSize,
        order: [[0, "asc"]],
        dom: "<\"top\"ip>rt<\"bottom\"p><\"clear\">",
        language: {
            info: "Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.",
            infoEmpty: "<h1><br/><i class=\"fas fa-4x fa-toilet-paper-slash\"></i><br/><br/>No archives to show you! Try <a href=\"upload\">uploading some</a>?</h1><br/>",
            processing: "<div id=\"progress\" class=\"indeterminate\"\"><div class=\"bar-container\"><div class=\"bar\" style=\" width: 80%; \"></div></div></div>",
        },
        preDrawCallback: IndexTable.initializeThumbView, // callbacks for thumbnail view
        drawCallback: IndexTable.drawCallback,
        rowCallback: IndexTable.buildThumbnailCell,
        columns: [
            /* eslint-disable object-curly-newline */
            { data: null, className: "title itd", name: "title", render: IndexTable.renderTitle },
            { data: "tags", className: "custom1 itd", name: localStorage.customColumn1, render: (data, type) => IndexTable.renderColumn(localStorage.customColumn1, type, data) },
            { data: "tags", className: "custom2 itd", name: localStorage.customColumn2, render: (data, type) => IndexTable.renderColumn(localStorage.customColumn2, type, data) },
            { data: "tags", className: "tags itd", name: "tags", orderable: false, render: IndexTable.renderTags },
            { data: "isnew", className: "isnew itd", name: "isnew", visible: false },
            { data: null, className: "untagged itd", name: "untagged", visible: false },
        ],
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

    // Add the isnew filter if asked
    // TODO: replace with carousel
    let input = $("#inboxbtn");

    if (input.prop("checked")) {
        IndexTable.dataTable.column(".isnew").search("true");
    } else {
        // no fav filters
        IndexTable.dataTable.column(".isnew").search("");
    }

    // Add the untagged filter if asked
    // TODO: replace with carousel
    input = $("#untaggedbtn");

    if (input.prop("checked")) {
        IndexTable.dataTable.column(".untagged").search("true");
    } else {
        // no fav filters
        IndexTable.dataTable.column(".untagged").search("");
    }

    // Update search input field
    $("#search-input").val(IndexTable.currentSearch);
    IndexTable.dataTable.search(IndexTable.currentSearch.replace(",", ""));

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
            return `<a style="cursor:pointer" href="${LRR.getTagSearchURL(namespace, match[1])}">
                        ${match[1].replace(/\b./g, (m) => m.toUpperCase())}
                    </a>`;
        } else return "";
    }
    return data;
};

/**
 * Render the title column.
 * @param {*} data Title
 * @param {*} type Whether this is a displayed column (html) or just a data request
 * @returns The table HTML, or raw title if type is data
 */
IndexTable.renderTitle = function (data, type) {
    if (type === "display") {
        return `${IndexTable.buildProgressDiv(data)} 
                <a class="context-menu" id="${data.arcid}" onmouseover="IndexTable.buildImageTooltip(this)" href="reader?id=${data.arcid}"> 
                    ${LRR.encodeHTML(data.title)}
                </a>
                <div class="caption" style="display: none;">
                    <img style="height:300px" src="./api/archives/${data.arcid}/thumbnail" onerror="this.src='./img/noThumb.png'">
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
        const thumbCss = (localStorage.cropthumbs === "true") ? "id3" : "id3 nocrop";
        const thumbDiv = `<div style="height:335px" class="id1 context-menu" id="${data.arcid}">
                        <div class="id2">
                            ${IndexTable.buildProgressDiv(data)}
                            <a href="reader?id=${data.arcid}" title="${LRR.encodeHTML(data.title)}">${LRR.encodeHTML(data.title)}</a>
                        </div>
                        <div style="height:280px" class="${thumbCss}">
                            <a href="reader?id=${data.arcid}" title="${LRR.encodeHTML(data.title)}">
                                <img style="position:relative;" id="${data.arcid}_thumb" src="./img/wait_warmly.jpg"/>
                                <i id="${data.arcid}_spinner" class="fa fa-4x fa-cog fa-spin ttspinner"></i>
                                <img src="./api/archives/${data.arcid}/thumbnail" 
                                        onload="$('#${data.arcid}_thumb').remove(); $('#${data.arcid}_spinner').remove();" 
                                        onerror="this.src='./img/noThumb.png'"/>
                            </a>
                        </div>
                        <div class="id4">
                            <span class="tags tag-tooltip" onmouseover="IndexTable.buildTagTooltip(this)">${LRR.colorCodeTags(data.tags)}</span>
                            <div class="caption caption-tags" style="display: none;" >${LRR.buildTagsDiv(data.tags)}</div>
                        </div>
                    </div>`;

        $("#thumbs_container").append(thumbDiv);
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

        let currentSort = IndexTable.dataTable.order()[0][0];
        // Using double equals here since the sort column can be either a string or an int
        // eslint-disable-next-line eqeqeq
        if (currentSort == 1) {
            currentSort = localStorage.customColumn1;
            // eslint-disable-next-line eqeqeq
        } else if (currentSort == 2) {
            currentSort = localStorage.customColumn2;
        } else {
            currentSort = "title";
        }

        const currentOrder = IndexTable.dataTable.order()[0][1];
        Index.updateTableControls(currentSort, currentOrder, pageInfo.pages, pageInfo.page + 1);

        // Clear potential leftover tooltips
        tippy.hideAll();
    }
};

IndexTable.buildURLParameters = function () {
    const cat = IndexTable.dataTable.column(".tags.itd").search();
    const untag = IndexTable.dataTable.column(".untagged").search();
    const isnew = IndexTable.dataTable.column(".isnew").search();
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
    if (untag !== "") params += "untagged&";
    if (isnew !== "") params += "isnew&";

    return params;
};

IndexTable.consumeURLParameters = function () {
    const params = new URLSearchParams(window.location.search);

    if (params.has("c")) Index.selectedCategory = params.get("c");
    else Index.selectedCategory = "";

    // TODO
    $("#untaggedbtn").prop("checked", params.has("untagged"));
    // updateToggleClass($("#untaggedbtn"));

    $("#inboxbtn").prop("checked", params.has("isnew"));
    // updateToggleClass($("#inboxbtn"));

    if (params.has("q")) { IndexTable.currentSearch = decodeURIComponent(params.get("q")); }

    const order = [[0, "asc"]];
    if (params.has("sort")) order[0][0] = params.get("sort");
    if (params.has("sortdir")) order[0][1] = params.get("sortdir");

    IndexTable.dataTable.order(order);

    if (params.has("p")) {
        IndexTable.doSearch(params.get("p") - 1);
    } else {
        IndexTable.doSearch();
    }
};

// #endregion

/**
 * Show an emoji or a progress number for the given archive data.
 * @param {*} arcdata The archive data
 * @returns HTML string
 */
IndexTable.buildProgressDiv = function (arcdata) {
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

    return "";
};

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
    }).show(); // Call show() so that the tooltip shows now

    $(target).attr("onmouseover", "");
};
