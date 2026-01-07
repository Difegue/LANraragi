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
TankoubonView.tagInput = null;        // Tagger instance for tag editing
TankoubonView.suggestions = [];       // Tag autocomplete suggestions
TankoubonView.userLogged = false;     // Whether user is logged in
TankoubonView.reorderMode = false;    // Whether reorder mode is active
TankoubonView.sortableInstance = null; // Sortable.js instance
TankoubonView.saveTimeout = null;     // Debounce timer for saving order

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

    // Edit mode handlers (only if logged in)
    TankoubonView.userLogged = $("body").data("user-logged") === 1;
    if (TankoubonView.userLogged) {
        $(document).on("click.edit-field", ".edit-field-btn", TankoubonView.editField);
        $(document).on("click.save-field", ".save-field-btn", TankoubonView.saveField);
        $(document).on("click.cancel-field", ".cancel-field-btn", TankoubonView.cancelField);
        $(document).on("click.reorder-toggle", ".reorder-toggle", TankoubonView.toggleReorderMode);

        // Keyboard shortcuts: Enter for title, Ctrl+Enter for summary/tags
        $(document).on("keydown.edit-title", "#edit-title", function(e) {
            if (e.key === "Enter") {
                e.preventDefault();
                $("#title-field .save-field-btn").trigger("click");
            }
        });
        $(document).on("keydown.edit-summary", "#edit-summary", function(e) {
            if (e.key === "Enter" && e.ctrlKey) {
                e.preventDefault();
                $("#summary-field .save-field-btn").trigger("click");
            }
        });
        $(document).on("keydown.edit-tags", "#edit-tags", function(e) {
            if (e.key === "Enter" && e.ctrlKey) {
                e.preventDefault();
                $("#tags-field .save-field-btn").trigger("click");
            }
        });

        // Preload tag suggestions for autocomplete
        TankoubonView.loadTagSuggestions();
    }

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

    // Summary - show placeholder if blank and user logged in
    if (data.summary) {
        $("#tankoubon-summary").html(LRR.encodeHTML(data.summary)).removeClass("field-placeholder").show();
    } else if (TankoubonView.userLogged) {
        $("#tankoubon-summary").html(I18N.TankoubonNoSummary).addClass("field-placeholder").show();
    } else {
        $("#tankoubon-summary").hide();
    }

    // Tags - show placeholder if blank and user logged in
    if (data.tags) {
        $("#tankoubon-tags").html(LRR.buildTagsDiv(data.tags)).removeClass("field-placeholder").show();
    } else if (TankoubonView.userLogged) {
        $("#tankoubon-tags").html(I18N.TankoubonNoTags).addClass("field-placeholder").show();
    } else {
        $("#tankoubon-tags").hide();
    }

    // Count
    const archiveCount = TankoubonView.archives.length;
    $("#tankoubon-count").text(I18N.TankoubonArchiveCount(archiveCount));

    // Show edit buttons for logged-in users
    if (TankoubonView.userLogged) {
        $(".edit-field-btn").show();
    }
};

/**
 * Render archives (current page or all if showAll is true)
 * @param {boolean} showAll If true, render all archives (for reorder mode)
 */
TankoubonView.renderPage = function(showAll = false) {
    let start, end, pageArchives;

    if (showAll) {
        start = 0;
        end = TankoubonView.archives.length;
        pageArchives = TankoubonView.archives;
    } else {
        start = TankoubonView.currentPage * TankoubonView.pageSize;
        end = Math.min(start + TankoubonView.pageSize, TankoubonView.archives.length);
        pageArchives = TankoubonView.archives.slice(start, end);
    }

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

    if (showAll) {
        $("#archive-count-info").text("");
    } else {
        $("#archive-count-info").text(I18N.TankoubonShowingCount(start + 1, end, TankoubonView.archives.length));
    }

    const viewMode = localStorage.tankoubonViewMode || "1";
    const inReorderMode = TankoubonView.reorderMode;

    if (viewMode === "1") {
        // Thumbnail view
        $("#archive-table").hide();
        $("#thumbs_container").show().empty();

        pageArchives.forEach((archive, index) => {
            // Don't show checkboxes in tankoubon view
            const $thumb = $(LRR.buildThumbnailDiv(archive, true, false));
            $thumb.attr("data-id", archive.arcid);
            // Add drag handle as full-width bar at top (hidden by CSS unless in reorder mode)
            $thumb.prepend('<div class="drag-handle drag-handle-bar"><i class="fas fa-grip-horizontal"></i></div>');
            $("#thumbs_container").append($thumb);
        });
    } else {
        // Table view
        $("#thumbs_container").hide();
        $("#archive-table").show();
        const tbody = $("#archive-table tbody").empty();

        pageArchives.forEach((archive, index) => {
            const globalIndex = start + index + 1;
            const row = $(`<tr class="context-menu gtr${index % 2}" id="${archive.arcid}" data-id="${archive.arcid}">
                <td class="itd" style="text-align: center;">
                    <i class="fas fa-grip-vertical drag-handle"></i>
                    <span class="row-index">${globalIndex}</span>
                </td>
                <td class="itd"><a href="${new LRR.apiURL(`/reader?id=${archive.arcid}`)}">${LRR.encodeHTML(archive.title)}</a></td>
                <td class="itd">${LRR.colorCodeTags(archive.tags)}</td>
            </tr>`);
            tbody.append(row);
        });
    }

    // Update page selector and paginator (hide in reorder mode)
    if (showAll) {
        $("#paginator-top, #paginator-bottom, #page-select").hide();
        $("#page-select").parent().find("*:contains('Go to Page')").first().hide();
    } else {
        $("#page-select").val(TankoubonView.currentPage + 1).show();
        TankoubonView.buildPaginator();
    }

    // Push state unless we're responding to popstate or in reorder mode
    if (!TankoubonView.isComingFromPopstate && !showAll) {
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

    if (TankoubonView.reorderMode) {
        // Re-initialize sortable when switching views in reorder mode
        TankoubonView.destroySortable();
        TankoubonView.renderPage(true);
        TankoubonView.initSortable();
    } else {
        TankoubonView.renderPage();
    }
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

    // Show reorder button when logged in and more than 1 archive
    if (TankoubonView.userLogged && TankoubonView.archives.length > 1) {
        $(".reorder-toggle").show();
    } else {
        $(".reorder-toggle").hide();
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

/**
 * Load tag suggestions for autocomplete
 */
TankoubonView.loadTagSuggestions = function() {
    Server.callAPI("/api/database/stats?minweight=2", "GET", null, I18N.TagStatsLoadFailure,
        (data) => {
            TankoubonView.suggestions = data.reduce((res, tag) => {
                let label = tag.text;
                if (tag.namespace !== "") { label = `${tag.namespace}:${tag.text}`; }
                res.push(label);
                return res;
            }, []);
        }
    );
};

/**
 * Enter edit mode for a specific field
 * @param {Event} e Click event
 */
TankoubonView.editField = function(e) {
    e.preventDefault();
    const field = $(this).data("field");
    const $container = $(`#${field}-field`);

    // Populate input with current value
    switch (field) {
        case "title":
            $("#edit-title").val(TankoubonView.data.name);
            break;
        case "summary":
            $("#edit-summary").val(TankoubonView.data.summary || "");
            break;
        case "tags":
            $("#edit-tags").val(TankoubonView.data.tags || "");
            // Initialize or refresh tagger (skip on mobile)
            if (!LRR.isMobile()) {
                if (!TankoubonView.tagInput) {
                    TankoubonView.tagInput = tagger($("#edit-tags")[0], {
                        allow_duplicates: false,
                        allow_spaces: true,
                        wrap: true,
                        completion: { list: TankoubonView.suggestions },
                        link: (name) => new LRR.apiURL(`/?q=${name}`),
                    });
                } else {
                    TankoubonView.tagInput.tags_from_input();
                }
            }
            break;
    }

    // Toggle visibility
    $container.find(".field-display").hide();
    $container.find(".edit-field-btn").hide();
    $container.find(".field-edit").show();

    // Focus the input
    $container.find("input, textarea").first().focus();
};

/**
 * Cancel editing a field
 * @param {Event} e Click event
 */
TankoubonView.cancelField = function(e) {
    e.preventDefault();
    const field = $(this).data("field");
    const $container = $(`#${field}-field`);

    // Toggle visibility
    $container.find(".field-edit").hide();
    $container.find(".field-display").show();
    $container.find(".edit-field-btn").show();
};

/**
 * Save a specific field
 * @param {Event} e Click event
 */
TankoubonView.saveField = function(e) {
    e.preventDefault();
    const field = $(this).data("field");
    const $btn = $(this);

    // Get the new value
    let value;
    switch (field) {
        case "title":
            value = $("#edit-title").val().trim();
            if (!value) {
                LRR.showErrorToast(I18N.MissingTankName);
                return;
            }
            break;
        case "summary":
            value = $("#edit-summary").val().trim();
            break;
        case "tags":
            value = $("#edit-tags").val().trim();
            break;
    }

    // Show saving indicator
    const originalClasses = $btn.attr("class");
    $btn.removeClass("fa-check").addClass("fa-spin fa-compact-disc");

    // Build metadata update - include all fields to preserve unchanged ones
    const metadata = {
        name: field === "title" ? value : TankoubonView.data.name,
        summary: field === "summary" ? value : (TankoubonView.data.summary || ""),
        tags: field === "tags" ? value : (TankoubonView.data.tags || "")
    };

    const body = JSON.stringify({ metadata });

    Server.callAPIBody(`/api/tankoubons/${TankoubonView.id}`, "PUT", body, null, I18N.TankoubonEditError,
        (response) => {
            // Update local data
            TankoubonView.data.name = metadata.name;
            TankoubonView.data.summary = metadata.summary;
            TankoubonView.data.tags = metadata.tags;

            // Re-render metadata display
            TankoubonView.renderMetadata();

            // Exit edit mode for this field
            const $container = $(`#${field}-field`);
            $container.find(".field-edit").hide();
            $container.find(".field-display").show();
            $container.find(".edit-field-btn").show();

            // Restore icon
            $btn.removeClass("fa-spin fa-compact-disc").addClass("fa-check");

            LRR.toast({
                heading: I18N.TankoubonEditSaved,
                icon: "success",
            });
        }
    ).catch(() => {
        // Restore icon on error
        $btn.removeClass("fa-spin fa-compact-disc").addClass("fa-check");
    });
};

/**
 * Toggle reorder mode
 * @param {Event} e Click event
 */
TankoubonView.toggleReorderMode = function(e) {
    e.preventDefault();
    TankoubonView.reorderMode = !TankoubonView.reorderMode;

    if (TankoubonView.reorderMode) {
        // Enter reorder mode
        $("body").addClass("reorder-mode");
        $(".reorder-toggle").addClass("active");

        // Render all archives and initialize sortable
        TankoubonView.renderPage(true);
        TankoubonView.initSortable();
    } else {
        // Exit reorder mode
        $("body").removeClass("reorder-mode");
        $(".reorder-toggle").removeClass("active");

        // Destroy sortable and restore pagination
        TankoubonView.destroySortable();
        TankoubonView.renderPage();
    }
};

/**
 * Initialize Sortable.js on the current view container
 */
TankoubonView.initSortable = function() {
    const viewMode = localStorage.tankoubonViewMode || "1";
    const container = viewMode === "1"
        ? document.getElementById("thumbs_container")
        : document.querySelector("#archive-table tbody");

    if (!container) return;

    TankoubonView.sortableInstance = new Sortable(container, {
        animation: 150,
        handle: ".drag-handle",
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        onEnd: TankoubonView.onReorderEnd
    });
};

/**
 * Destroy Sortable.js instance
 */
TankoubonView.destroySortable = function() {
    if (TankoubonView.sortableInstance) {
        TankoubonView.sortableInstance.destroy();
        TankoubonView.sortableInstance = null;
    }
};

/**
 * Handle reorder drag end - update archives array and save
 * @param {Event} evt Sortable onEnd event
 */
TankoubonView.onReorderEnd = function(evt) {
    const oldIndex = evt.oldIndex;
    const newIndex = evt.newIndex;

    if (oldIndex === newIndex) return;

    // Move item in the archives array
    const [moved] = TankoubonView.archives.splice(oldIndex, 1);
    TankoubonView.archives.splice(newIndex, 0, moved);

    // Update row indices in table view
    if ((localStorage.tankoubonViewMode || "1") === "0") {
        $("#archive-table tbody tr").each(function(index) {
            $(this).find(".row-index").text(index + 1);
        });
    }

    // Debounce save to batch rapid changes
    clearTimeout(TankoubonView.saveTimeout);
    TankoubonView.saveTimeout = setTimeout(TankoubonView.saveOrder, 500);
};

/**
 * Save the current archive order to the server
 */
TankoubonView.saveOrder = function() {
    const archiveIds = TankoubonView.archives.map(a => a.arcid);
    const body = JSON.stringify({ archives: archiveIds });

    Server.callAPIBody(`/api/tankoubons/${TankoubonView.id}`, "PUT", body, null, I18N.TankoubonReorderError,
        () => {
            LRR.toast({
                heading: I18N.TankoubonReorderSaved,
                icon: "success",
            });
        }
    );
};
