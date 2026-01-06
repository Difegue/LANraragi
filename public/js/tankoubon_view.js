/**
 * Tankoubon View page functions.
 */
const TankoubonView = {};

TankoubonView.id = null;              // Tankoubon ID
TankoubonView.data = null;            // Full tankoubon metadata
TankoubonView.archives = [];          // Array of archive objects (full data)
TankoubonView.currentPage = 0;        // Current page (0-indexed)
TankoubonView.pageSize = 100;         // Archives per page (from /api/info)
TankoubonView.totalPages = 0;         // Total pages
TankoubonView.isComingFromPopstate = false;

/**
 * Initialize the tankoubon view
 * @param {string} id Tankoubon ID
 */
TankoubonView.init = function(id) {
    TankoubonView.id = id;

    // Bind events
    $(document).on("click.mode-toggle", ".mode-toggle", TankoubonView.toggleMode);
    $(document).on("change.page-select", "#page-select", function() {
        TankoubonView.goToPage(parseInt($(this).val()) - 1);
    });
    $(document).on("click.paginate", ".paginate_button:not(.current)", function() {
        TankoubonView.goToPage(parseInt($(this).data("page")));
    });

    // Handle browser back/forward
    $(window).on("popstate", () => {
        TankoubonView.isComingFromPopstate = true;
        TankoubonView.consumeURLParameters();
    });

    // 0 = List/table view
    // 1 = Thumbnail view (default)
    if (localStorage.getItem("tankoubonViewMode") === null) {
        localStorage.tankoubonViewMode = "1";
    }

    // Get page size from server info, then load tankoubon
    Server.callAPI("/api/info", "GET", null, I18N.ServerInfoError,
        (data) => {
            TankoubonView.pageSize = data.archives_per_page;
            TankoubonView.loadTankoubon();
        }
    );
};

/**
 * Load tankoubon data from API
 */
TankoubonView.loadTankoubon = function() {
    Server.callAPI(`/api/tankoubons/${TankoubonView.id}?include_full_data=true&page=-1`,
        "GET", null, I18N.TankoubonLoadError,
        (response) => {
            TankoubonView.data = response.result;
            TankoubonView.archives = response.result.full_data || [];
            TankoubonView.totalPages = Math.max(1, Math.ceil(TankoubonView.archives.length / TankoubonView.pageSize));

            TankoubonView.renderMetadata();
            TankoubonView.updateControls();
            TankoubonView.consumeURLParameters();
        }
    );
};

/**
 * Render tankoubon metadata (name, summary, tags, count)
 */
TankoubonView.renderMetadata = function() {
    const data = TankoubonView.data;

    // Title
    $("#tankoubon-title").text(data.name);
    document.title = document.title.replace(I18N.Tankoubon || "Tankoubon", data.name);

    // Summary
    if (data.summary) {
        $("#tankoubon-summary").html(LRR.encodeHTML(data.summary));
    } else {
        $("#tankoubon-summary").hide();
    }

    // Tags
    if (data.tags) {
        $("#tankoubon-tags").html(LRR.buildTagsDiv(data.tags));
    } else {
        $("#tankoubon-tags").hide();
    }

    // Count
    const archiveCount = TankoubonView.archives.length;
    $("#tankoubon-count").text(I18N.TankoubonArchiveCount(archiveCount));
};

/**
 * Render the current page of archives
 */
TankoubonView.renderPage = function() {
    const start = TankoubonView.currentPage * TankoubonView.pageSize;
    const end = Math.min(start + TankoubonView.pageSize, TankoubonView.archives.length);
    const pageArchives = TankoubonView.archives.slice(start, end);

    // Handle empty state
    if (TankoubonView.archives.length === 0) {
        $("#archive-count-info").text("");
        $("#empty-message").show();
        $("#thumbs_container").hide();
        $("#archive-table").hide();
        $(".table-options").hide();
        return;
    }

    $("#empty-message").hide();
    $(".table-options").show();
    $("#archive-count-info").text(I18N.TankoubonShowingCount(start + 1, end, TankoubonView.archives.length));

    const viewMode = localStorage.tankoubonViewMode || "1";

    if (viewMode === "1") {
        // Thumbnail view
        $("#archive-table").hide();
        $("#thumbs_container").show().empty();

        pageArchives.forEach((archive) => {
            // Don't show checkboxes in tankoubon view
            $("#thumbs_container").append(LRR.buildThumbnailDiv(archive, true, false));
        });
    } else {
        // Table view
        $("#thumbs_container").hide();
        $("#archive-table").show();
        const tbody = $("#archive-table tbody").empty();

        pageArchives.forEach((archive, index) => {
            const globalIndex = start + index + 1;
            const row = $(`<tr class="context-menu gtr${index % 2}" id="${archive.arcid}">
                <td class="itd" style="text-align: center;">${globalIndex}</td>
                <td class="itd"><a href="${new LRR.apiURL(`/reader?id=${archive.arcid}`)}">${LRR.encodeHTML(archive.title)}</a></td>
                <td class="itd">${LRR.colorCodeTags(archive.tags)}</td>
            </tr>`);
            tbody.append(row);
        });
    }

    // Update page selector and paginator
    $("#page-select").val(TankoubonView.currentPage + 1);
    TankoubonView.buildPaginator();

    // Push state unless we're responding to popstate
    if (!TankoubonView.isComingFromPopstate) {
        TankoubonView.pushState();
    }
    TankoubonView.isComingFromPopstate = false;
};

/**
 * Toggle between thumbnail and table view
 * @param {Event} e Click event
 */
TankoubonView.toggleMode = function(e) {
    e.preventDefault();
    localStorage.tankoubonViewMode = (localStorage.tankoubonViewMode === "1") ? "0" : "1";
    TankoubonView.updateControls();
    TankoubonView.renderPage();
};

/**
 * Go to a specific page
 * @param {number} page Page number (0-indexed)
 */
TankoubonView.goToPage = function(page) {
    TankoubonView.currentPage = Math.max(0, Math.min(page, TankoubonView.totalPages - 1));
    TankoubonView.renderPage();
};

/**
 * Update UI controls (view toggle visibility, page selector)
 */
TankoubonView.updateControls = function() {
    const viewMode = localStorage.tankoubonViewMode || "1";

    if (viewMode === "1") {
        $(".thumbnail-toggle").show();
        $(".compact-toggle").hide();
    } else {
        $(".thumbnail-toggle").hide();
        $(".compact-toggle").show();
    }

    // Build page selector
    const select = $("#page-select").empty();
    for (let i = 1; i <= TankoubonView.totalPages; i++) {
        select.append(`<option value="${i}" ${i === TankoubonView.currentPage + 1 ? "selected" : ""}>${i}</option>`);
    }
};

/**
 * Build pagination buttons matching DataTables style.
 * Shows all pages if total <= 7, otherwise shows ellipsis.
 */
TankoubonView.buildPaginator = function() {
    const current = TankoubonView.currentPage;  // 0-indexed
    const total = TankoubonView.totalPages;

    // Hide paginators if only one page
    if (total <= 1) {
        $("#paginator-top, #paginator-bottom").empty().hide();
        return;
    }

    /**
     * Build a single page button
     * @param {number} pageIndex 0-indexed page number
     * @returns {string} HTML for the button
     */
    function buildButton(pageIndex) {
        const isCurrent = pageIndex === current ? " current" : "";
        return `<span class="paginate_button${isCurrent}" data-page="${pageIndex}">${pageIndex + 1}</span>`;
    }

    let html = "";

    // DataTables "numbers" pagination shows all pages when <= 7, otherwise uses ellipsis
    if (total <= 7) {
        // Show all pages
        for (let i = 0; i < total; i++) {
            html += buildButton(i);
        }
    } else {
        // Always show first page
        html += buildButton(0);

        if (current > 2) {
            html += '<span class="ellipsis">…</span>';
        }

        // Pages around current (current-1, current, current+1), but not first or last
        for (let i = Math.max(1, current - 1); i <= Math.min(total - 2, current + 1); i++) {
            html += buildButton(i);
        }

        if (current < total - 3) {
            html += '<span class="ellipsis">…</span>';
        }

        // Always show last page
        html += buildButton(total - 1);
    }

    $("#paginator-top, #paginator-bottom").html(html).show();
};

/**
 * Refresh current page (called after context menu actions like delete/rating)
 */
TankoubonView.refreshPage = function() {
    TankoubonView.loadTankoubon();
};

/**
 * Push current state to URL
 */
TankoubonView.pushState = function() {
    let params = `?id=${TankoubonView.id}`;
    if (TankoubonView.currentPage > 0) {
        params += `&p=${TankoubonView.currentPage + 1}`;
    }
    window.history.pushState(null, null, params);
};

/**
 * Consume URL parameters (page)
 */
TankoubonView.consumeURLParameters = function() {
    const params = new URLSearchParams(window.location.search);

    if (params.has("p")) {
        const page = parseInt(params.get("p")) - 1;
        if (!isNaN(page) && page >= 0 && page < TankoubonView.totalPages) {
            TankoubonView.currentPage = page;
        }
    }

    TankoubonView.renderPage();
};
