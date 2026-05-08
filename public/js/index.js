/**
 * Non-DataTables Index functions.
 * (The split is there to permit easier switch if we ever yeet datatables from the main UI)
 * @global
 */
const Index = {};
Index.selectedCategory = "";
Index.awesomplete = {};
Index.carouselInitialized = false;
Index.swiper = {};
Index.serverVersion = "";
Index.debugMode = false;
Index.isProgressLocal = true;
Index.isProgressAuthenticated = true;
Index.pageSize = 100;
Index.pseudoCopyBtn = undefined;
Index.isMultiSelectMode = false;
Index.selectedArchives = new Set();

/**
 * Initialize the Archive Index.
 */
Index.initializeAll = function () {
    // Bind events to DOM
    $(document).on("click", "[id^=edit-header-]", function () {
        const headerIndex = $(this).attr("id").split("-")[2];
        Index.promptCustomColumn(headerIndex);
    });
    $(document).on("change.page-select", "#page-select", () => IndexTable.dataTable.page($("#page-select").val() - 1).draw("page"));
    $(document).on("change.namespace-sortby", "#namespace-sortby", Index.handleCustomSort);
    $(document).on("change.columnCount", "#columnCount", Index.handleColumnNum);
    $(document).on("click.order-sortby", "#order-sortby", Index.toggleOrder);
    $(document).on("click.open-carousel", ".collapsible-title", Index.toggleCarousel);
    $(document).on("click.reload-carousel", "#reload-carousel", Index.updateCarousel);
    $(document).on("click.close-overlay", "#overlay-shade", LRR.closeOverlay);
    $(document).on("click.thumbnail-bookmark-icon", ".thumbnail-bookmark-icon", Index.toggleBookmarkStatusByIcon);
    $(document).on("click.title-bookmark-icon", ".title-bookmark-icon", Index.toggleBookmarkStatusByIcon);
    $(document).on("keydown.quick-search", Index.handleQuickSearch);
    $(document).on("keydown.escape-overlay", Index.handleEscapeKey);

    // MSM event bindings
    $(document).on("click.msm-toggle", "#msm-toggle", Index.toggleMultiSelectMode);
    $(document).on("click.msm-select-page", "#msm-select-page", Index.selectCurrentPage);
    $(document).on("click.msm-batch-ops", "#msm-batch-ops", Index.openBatchOnSelection);
    $(document).on("click.msm-clear", "#msm-clear", Index.clearSelection);
    // Intercept reader-link clicks while MSM is active to toggle archive selection instead
    $(document).on("click.msm-archive", "a[href*='/reader?id=']", function (e) {
        if (!Index.isMultiSelectMode) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        const id = $(this).closest("[id]").attr("id");
        if (id) Index.toggleArchiveSelection(id);
    });

    // 0 = List view
    // 1 = Thumbnail view
    // List view is at 0 but became the non-default state later so here's some legacy weirdness
    if (localStorage.getItem("indexViewMode") === null) {
        localStorage.indexViewMode = 1;
    }

    // Default to crop landscape
    if (localStorage.getItem("cropthumbs") === null) {
        localStorage.cropthumbs = true;
    }

    // Default custom columns
    if (localStorage.getItem("customColumn1") === null) {
        localStorage.customColumn1 = "artist";
        localStorage.customColumn2 = "series";
    }

    // Default to on deck for carousel
    if (localStorage.getItem("carouselType") === null) {
        localStorage.carouselType = "ondeck";
    }

    // Default to opened carousel
    if (localStorage.getItem("carouselOpen") === null) {
        localStorage.carouselOpen = 1;
    }

    // Force-open the collapsible if carouselOpen = true
    if (localStorage.carouselOpen === "1") {
        $(".collapsible-title").trigger("click", [false]);
        // Index.updateCarousel(); will be executed by toggleCarousel
    } else {
        Index.updateCarousel();
    }

    // Initialize carousel mode menu
    $.contextMenu({
        selector: "#carousel-mode-menu",
        trigger: "left",
        build: () => ({
            callback(key) {
                localStorage.carouselType = key;
                Index.updateCarousel();
            },
            items: {
                ondeck: { name: I18N.CarouselOnDeck, icon: "fas fa-book-reader" },
                random: { name: I18N.CarouselRandom, icon: "fas fa-random" },
                inbox: { name: I18N.NewArchives, icon: "fas fa-envelope-open-text" },
                untagged: { name: I18N.UntaggedArchives, icon: "fas fa-edit" },
            },
        }),
    });

    // Initialize settings menu (display mode, crop thumbnails, hide completed)
    $.contextMenu({
        selector: "#settings-menu",
        zIndex: 10,
        trigger: "left",
        build: () => {
            const isThumbnail = localStorage.indexViewMode === "1";
            return {
                items: {
                    "header": {
                        name: I18N.IndexSettingsDisplayMode,
                        icon: "fas fa-table",
                        disabled: true,
                    },
                    "mode-thumbnail": {
                        name: I18N.IndexSettingsThumbnail,
                        type: "radio",
                        radio: "displayMode",
                        value: "1",
                        selected: isThumbnail,
                        events: {
                            click() {
                                localStorage.indexViewMode = "1";
                                IndexTable.dataTable.draw();
                            },
                        }
                    },
                    "mode-compact": {
                        name: I18N.IndexSettingsCompact,
                        type: "radio",
                        radio: "displayMode",
                        value: "0",
                        selected: !isThumbnail,
                        events: {
                            click() {
                                localStorage.indexViewMode = "0";
                                IndexTable.dataTable.draw();
                            },
                        }
                    },
                    "sep1": "---------",
                    "crop-thumbnails": {
                        name: `<span title="${I18N.IndexSettingsCropDesc}">${I18N.IndexSettingsCropThumbs}</span>`,
                        isHtmlName: true,
                        type: "checkbox",
                        selected: localStorage.cropthumbs === "true",
                        events: {
                            click() {
                                localStorage.cropthumbs = $(this).is(":checked");
                                IndexTable.dataTable.draw();
                            },
                        },
                    },
                    "hide-completed": {
                        name: `<span title="${I18N.IndexSettingsHideCompletedDesc}">${I18N.IndexSettingsHideCompleted}</span>`,
                        isHtmlName: true,
                        type: "checkbox",
                        selected: localStorage.hidecompleted === "true",
                        events: {
                            click() {
                                localStorage.hidecompleted = $(this).is(":checked");
                                IndexTable.dataTable.draw();
                            },
                        },
                    },
                    "group-tanks": {
                        name: `<span title="${I18N.IndexSettingsGroupTanksDesc}">${I18N.IndexSettingsGroupTanks}</span>`,
                        isHtmlName: true,
                        type: "checkbox",
                        selected: localStorage.grouptanks !== "false",
                        events: {
                            click() {
                                localStorage.grouptanks = $(this).is(":checked");
                                IndexTable.dataTable.draw();
                            },
                        },
                    },
                },
            };
        },
    });

    // Tell user about the context menu
    if (localStorage.getItem("sawContextMenuToast") === null) {
        localStorage.sawContextMenuToast = true;

        LRR.toast({
            heading: I18N.IndexWelcome(Index.serverVersion),
            text: I18N.IndexWelcome2,
            icon: "info",
            hideAfter: 13000,
        });
    }

    // Get some info from the server: version, debug mode, local progress
    Server.callAPI("/api/info", "GET", null, I18N.ServerInfoError,
        (data) => {
            Index.serverVersion = data.version;
            Index.debugMode = !!data.debug_mode;
            Index.isProgressLocal = !data.server_tracks_progress;
            Index.isProgressAuthenticated = data.authenticated_progress;
            Index.pageSize = data.archives_per_page;

            // Check version if not in debug mode
            if (!Index.debugMode) {
                Index.checkVersion();
                Index.fetchChangelog();
            } else {
                LRR.toast({
                    heading: `<i class="fas fa-bug"></i> ` + I18N.DebugModeHeader,
                    text: I18N.DebugModeDesc(new LRR.apiURL("/debug")),
                    icon: "warning",
                });
            }

            Index.migrateProgress();
            Index.loadTagSuggestions();

            // Make bookmark category ID available to index and indextable
            Server.loadBookmarkCategoryId()
                .then(() => Index.loadCategories())
                .then(() => IndexTable.initializeAll())
                .catch(error => console.error("Error initializing index:", error));
        });

    const columnCountSelect = document.getElementById("columnCount");
    columnCountSelect.value = Index.getColumnCount();

    Index.updateTableHeaders();
    Index.resizableColumns();

    Index.pseudoCopyBtn = $("#pseudo-copy-btn")
    Index.clipboard = new window.ClipboardJS("#pseudo-copy-btn");

    Index.clipboard.on("success", function (e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkSuccess,
            icon: "info",
            hideAfter: 3000,
        });
        e.clearSelection();
    });

    Index.clipboard.on("error", function (e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkFail,
            icon: "error",
            hideAfter: false,
        });
    });
};

Index.toggleOrder = function (e) {
    e.preventDefault();
    const order = IndexTable.dataTable.order();
    order[0][1] = order[0][1] === "asc" ? "desc" : "asc";
    IndexTable.dataTable.order(order);
    IndexTable.dataTable.draw();
};

/**
 * Handle escape key to close overlays.
 * @param {KeyboardEvent} e - The keyboard event
 */
Index.handleEscapeKey = function (e) {
    if (e.key !== "Escape") return;
    if (e.target.tagName === "INPUT") return;
    LRR.closeOverlay();
};

// #region Bookmark/Favorite Icon

// Turn bookmark icons to OFF for all archives.
Index.bookmarkIconOff = function (arcid) {
    const icons = document.querySelectorAll(`.title-bookmark-icon[id='${arcid}'], .thumbnail-bookmark-icon[id='${arcid}']`);
    icons.forEach(el => {
        el.classList.remove("fas");
        el.classList.add("far");
    })
}

// Turn bookmark icons to ON for all archives.
Index.bookmarkIconOn = function (arcid) {
    const icons = document.querySelectorAll(`.title-bookmark-icon[id='${arcid}'], .thumbnail-bookmark-icon[id='${arcid}']`);
    icons.forEach(el => {
        el.classList.remove("far");
        el.classList.add("fas");
    })
}

Index.toggleBookmarkStatusByIcon = function (e) {
    const icon = e.currentTarget;
    const id = icon.id;

    if (!LRR.isUserLogged()) {
        LRR.toast({
            heading: I18N.LoginRequired(new LRR.apiURL("/login")),
            icon: "warning",
            hideAfter: 5000,
        });
        return;
    }

    if (icon.classList.contains("far")) {
        Server.addArchiveToCategory(id, localStorage.getItem("bookmarkCategoryId"));
        Index.bookmarkIconOn(id);
    } else if (icon.classList.contains("fas")) {
        Server.removeArchiveFromCategory(id, localStorage.getItem("bookmarkCategoryId"));
        Index.bookmarkIconOff(id);
    }
};

// #endregion

// #region Search and Suggestions 

/**
 * Handle quick search functionality. If user is in index page and
 * presses "/" key, focus to search input. If the release overlay
 * is open, closes it before focusing to search input.
 * 
 * @param {KeyboardEvent} e - The keyboard event
 */
Index.handleQuickSearch = function (e) {
    if (e.key !== "/") return;
    if (e.target.tagName === "INPUT") return;
    if (e.ctrlKey || e.altKey || e.shiftKey || e.metaKey) return;
    e.preventDefault();
    if ($("#overlay-shade").is(":visible")) LRR.closeOverlay();
    $("#search-input")[0].focus();
};

/**
 * Load tag suggestions for the tag search bar.
 */
Index.loadTagSuggestions = function () {
    // Query the tag cloud API to get the most used tags, excluding configured namespaces.
    Server.callAPI("/api/database/stats?minweight=2&hide_excluded_namespaces=true", "GET", null, I18N.TagStatsLoadFailure,
        (data) => {
            // Get namespaces objects in the data array to fill the namespace-sortby combobox
            const namespacesSet = new Set(data.map((element) => (element.namespace === "parody" ? "series" : element.namespace)));
            namespacesSet.forEach((element) => {
                if (element !== "") {
                    $("#namespace-sortby").append(`<option value="${element}">${element.charAt(0).toUpperCase() + element.slice(1)}</option>`);
                }
            });

            // Setup awesomplete for the tag search bar
            Index.awesomplete = new Awesomplete("#search-input", {
                list: data,
                data(tag) {
                    // Format tag objects from the API into a format awesomplete likes.
                    let label = tag.text;
                    if (tag.namespace !== "") label = `${tag.namespace}:${tag.text}`;

                    return { label, value: tag.weight };
                },
                // Sort by weight
                sort(a, b) {
                    return b.value - a.value;
                },
                filter(text, input) {
                    return Awesomplete.FILTER_CONTAINS(text, input.match(/[^, -]*$/)[0]);
                },
                item(text, input) {
                    return Awesomplete.ITEM(text, input.match(/[^, -]*$/)[0]);
                },
                replace(text) {
                    const before = this.input.value.match(/^.*(,|-)\s*-*|/)[0];
                    this.input.value = `${before + text}$, `;
                },
            });
        },
    );
};

// #endregion

// #region Carousel

Index.toggleCarousel = function (e, updateLocalStorage = true) {
    if (updateLocalStorage) 
        localStorage.carouselOpen = (localStorage.carouselOpen === "1") ? "0" : "1";

    if (!Index.carouselInitialized) {
        Index.carouselInitialized = true;
        $("#reload-carousel").show();

        Index.swiper = new Swiper(".index-carousel-container", {
            breakpoints: (() => {
                const breakpoints = {
                    0: { // ensure every device have at least 1 slide
                        slidesPerView: 1,
                    },
                };
                // virtual Slides doesn't work with slidesPerView: 'auto'
                // the following loops are meant to implement same functionality by doing mathworks
                // it also helps avoid writing a billion slidesPerView combos for window widths
                // when the screen width <= 560px, every thumbnails have a different width
                // from 169px, when the width is 17px bigger, we display 0.1 more slide
                for (let width = 169, sides = 1; width <= 424; width += 17, sides += 0.1) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                // from 427px, when the width is 46px bigger, we display 0.2 more slide
                // the width support up to 4K resolution
                for (let width = 427, sides = 1.8; width <= 3840; width += 46, sides += 0.2) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                return breakpoints;
            })(),
            breakpointsBase: "container",
            centerInsufficientSlides: false,
            mousewheel: true,
            navigation: {
                nextEl: ".carousel-next",
                prevEl: ".carousel-prev",
            },
            slidesPerView: 7,
            virtual: {
                enabled: true,
                addSlidesAfter: 2,
                addSlidesBefore: 2,
            },
        });

        Index.updateCarousel();
    }
};

Index.updateCarousel = function (e) {
    e?.preventDefault();

    // Don't overwrite the carousel while Multi-Select Mode is active
    if (Index.isMultiSelectMode) {
        return;
    }

    $("#carousel-empty").hide();
    $("#carousel-loading").show();
    $(".swiper-wrapper").hide();

    $("#reload-carousel").addClass("fa-spin");

    // Hit a different API endpoint depending on the requested localStorage carousel type
    let endpoint;
    const filter = IndexTable.currentSearch ? `&filter=${IndexTable.currentSearch}` : "";
    const category = Index.selectedCategory ? `&category=${Index.selectedCategory}` : "";

    switch (localStorage.carouselType) {
        case "random":
            $("#carousel-icon")[0].classList = "fas fa-random";
            $("#carousel-title").text(I18N.CarouselRandom);
            endpoint = `/api/search/random?count=15${filter}${category}`;

            // Special categories that imply additional query params
            if (Index.selectedCategory === "NEW_ONLY") {
                endpoint += "&newonly=true";
            } else if (Index.selectedCategory === "UNTAGGED_ONLY") {
                endpoint += "&untaggedonly=true";
            }

            break;
        case "inbox":
            $("#carousel-icon")[0].classList = "fas fa-envelope-open-text";
            $("#carousel-title").text(I18N.NewArchives);
            endpoint = `/api/search?newonly=true&sortby=date_added&order=desc&start=-1${filter}${category}`;
            break;
        case "untagged":
            $("#carousel-icon")[0].classList = "fas fa-edit";
            $("#carousel-title").text(I18N.UntaggedArchives);
            endpoint = `/api/search?untaggedonly=true&sortby=date_added&order=desc&start=-1${filter}${category}`;
            break;
        case "ondeck":
            $("#carousel-icon")[0].classList = "fas fa-book-reader";
            $("#carousel-title").text(I18N.CarouselOnDeck);
            endpoint = `/api/search?sortby=lastread&hidecompleted=true${filter}`;
            break;
        default:
            $("#carousel-icon")[0].classList = "fas fa-pastafarianism";
            $("#carousel-title").text("What???");
            endpoint = `/api/search?${filter}${category}`.replace(/\?$/, "");
            break;
    }

    if (Index.carouselInitialized) {
        Server.callAPI(endpoint, "GET", null, I18N.CarouselError,
            (results) => {
                Index.swiper.virtual.removeAllSlides();
                const slides = results.data
                    .map((archive) => LRR.buildThumbnailDiv(archive));
                Index.swiper.virtual.appendSlide(slides);
                Index.swiper.virtual.update();

                if (results.data.length === 0) {
                    $("#carousel-empty").show();
                }

                $("#carousel-loading").hide();
                $(".swiper-wrapper").show();
                $("#reload-carousel").removeClass("fa-spin");
            },
        );
    }
};

// #endregion

// #region Multi-Select Mode in Carousel

/**
 * Toggle Multi-Select Mode on/off.
 * In MSM, the carousel empties out and serves as a visual selection panel.
 * Clicking archives adds/removes them from the selection instead of opening the reader.
 */
Index.toggleMultiSelectMode = function () {
    Index.isMultiSelectMode = !Index.isMultiSelectMode;

    if (Index.isMultiSelectMode) {
        Index.enterSelectionCarouselMode();
    } else {

        if (Index.selectedArchives.size > 0) 
            LRR.showPopUp({
                text: I18N.MSMConfirmExit,
                showCancelButton: true,
                focusConfirm: false,
                reverseButtons: true,
            }).then((result) => {
                if (result.isConfirmed) {
                    Index.clearSelection();
                    Index.exitSelectionCarouselMode();
                }
                else 
                    Index.isMultiSelectMode = true; // Revert the toggle if user cancels 
            });
        else 
            Index.exitSelectionCarouselMode();    
    }
};

/**
 * Switch the carousel into Selection Mode: clear slides, hide normal controls,
 * show MSM controls, and update the header.
 */
Index.enterSelectionCarouselMode = function () {
    // Initialize the carousel if it hasn't been opened yet
    if (!Index.carouselInitialized) {
        Index.toggleCarousel(null, false);
    }

    $("#msm-toggle").addClass("toggled");
    // Open the carousel if it isn't already open
    if (!$(".collapsible-title").hasClass("active")) {
        $(".collapsible-title").trigger("click", [false]);
    }

    // Hide normal carousel controls
    $("#reload-carousel").hide();
    $("#carousel-mode-menu").hide();

    // Update carousel header to reflect selection mode
    $("#carousel-icon")[0].className = "fas fa-check-square";
    $("#carousel-title").text(I18N.MSMCarouselTitle);

    // Clear all existing slides
    Index.swiper.virtual.removeAllSlides();
    Index.swiper.virtual.update();

    // Show selection hint as empty state
    $("#carousel-empty-text").text(I18N.MSMSelectionHint);
    $("#carousel-loading").hide();
    $("#carousel-empty").show();
    $(".swiper-wrapper").hide();

    // Show MSM controls
    $("#msm-carousel-controls").show();
    Index.updateSelectionCount();
};

/**
 * Restore the carousel to its normal mode: show normal controls, hide MSM controls,
 * restore empty state text, and reload the carousel content.
 */
Index.exitSelectionCarouselMode = function () {
    // Restore normal carousel controls
    $("#reload-carousel").show();
    $("#carousel-mode-menu").show();

    $("#msm-toggle").removeClass("toggled");
    // Close the carousel again if localStorage doesn't have the pref to keep it open
    if (localStorage.carouselOpen !== "1") {
        $(".collapsible-title").trigger("click", [false]);
    }

    // Restore empty state text
    $("#carousel-empty-text").text(I18N.CarouselEmpty);

    // Hide MSM controls
    $("#msm-carousel-controls").hide();

    // Reload normal carousel content
    Index.updateCarousel();

    // Remove all highlights from archives
    $(".msm-selected").removeClass("msm-selected");
};

/**
 * Toggle an archive in/out of the current MSM selection.
 * Updates the carousel slides and index highlights accordingly.
 * @param {string} id Archive ID
 */
Index.toggleArchiveSelection = function (id) {
    if (Index.selectedArchives.has(id)) {
        Index.selectedArchives.delete(id);
        Index.removeArchiveFromSelection(id);
    } else {
        Index.selectedArchives.add(id);
        // Find archive data from DataTables to build the carousel slide
        const row = IndexTable.dataTable.row(`#${id}`);
        const data = row.data();
        if (data) {
            Index.addArchiveToSelection(data);
        }
    }
    Index.updateSelectionCount();
};

/**
 * Build and add a carousel slide for the given archive.
 * Clicking the slide removes the archive from the selection.
 * @param {object} data Archive data object from DataTables
 */
Index.addArchiveToSelection = function (data) {
    const id = data.arcid || data.id;
    const slide = LRR.buildThumbnailDiv(data);
    Index.swiper.virtual.appendSlide(slide);
    Index.swiper.virtual.update();

    // Add highlight classes to matching divs in compact and thumb mode 
    $(`#thumbs_container #${id}`).addClass("msm-selected");
    $(`tr#${id}.context-menu`).addClass("msm-selected");

    // Bind click on newly added slide to deselect the archive
    // Uses event delegation so it works even with virtual slides
    $(document).off(`click.msm-carousel-${id}`).on(`click.msm-carousel-${id}`, `#${id}.swiper-slide`, 
        function (e) {
        if (!Index.isMultiSelectMode) return;
        e.preventDefault();
        Index.toggleArchiveSelection(id);
    });
};

/**
 * Remove an archive's slide from the MSM carousel.
 * @param {string} id Archive ID to remove
 */
Index.removeArchiveFromSelection = function (id) {
    // Find the slide index in the virtual slides array
    const { slides } = Index.swiper.virtual;
    const idx = slides.findIndex((html) => html.includes(`id="${id}"`));
    if (idx !== -1) {
        Index.swiper.virtual.removeSlide(idx);
        Index.swiper.virtual.update();
    }

    // Remove highlight classes
    $(`#thumbs_container #${id}`).removeClass("msm-selected");
    $(`tr#${id}.context-menu`).removeClass("msm-selected");

    $(document).off(`click.msm-carousel-${id}`);
};

/**
 * Add all archives visible on the current DataTables page to the selection.
 */
Index.selectCurrentPage = function () {
    const pageData = IndexTable.dataTable.rows({ page: "current" }).data();
    pageData.each((data) => {
        const id = data.arcid || data.id;
        if (!Index.selectedArchives.has(id)) {
            Index.selectedArchives.add(id);
            Index.addArchiveToSelection(data);
        }
    });
    Index.updateSelectionCount();
};

/**
 * Clear the entire archive selection, reset the carousel to empty, and remove all highlights.
 */
Index.clearSelection = function () {
    Index.selectedArchives.clear();

    if (Index.carouselInitialized) {
        Index.swiper.virtual.removeAllSlides();
        Index.swiper.virtual.update();
        $("#carousel-empty").show();
        $(".swiper-wrapper").hide();
    }

    $(".msm-selected").removeClass("msm-selected");
    Index.updateSelectionCount();
};

/**
 * Update the count display for the current selection and save a copy to localStorage. 
 * Also show/hide controls if applicable.
 */
Index.updateSelectionCount = function () {
    const count = Index.selectedArchives.size;
    localStorage.setItem("msmSelection", JSON.stringify([...Index.selectedArchives]));
    if (count > 0) {
        // Hide empty state, show slides
        $("#carousel-empty").hide();
        $(".swiper-wrapper").show();

        $("#msm-selection-count").text(I18N.MSMSelectionCount(count));
        if (LRR.isUserLogged())
            $("#msm-batch-ops").show();
        $("#msm-clear").show();
    } else {
        $("#carousel-empty").show();
        $(".swiper-wrapper").hide();

        $("#msm-selection-count").text("");
        $("#msm-batch-ops").hide();
        $("#msm-clear").hide();
    }
};

/**
 * Re-apply msm-selected CSS highlights for all selected archives currently in the DOM.
 * Should be called after each DataTables draw.
 */
Index.applySelectionHighlights = function () {
    if (!Index.isMultiSelectMode) return;
    Index.selectedArchives.forEach((id) => {
        $(`#thumbs_container #${id}`).addClass("msm-selected");
        $(`tr#${id}.context-menu`).addClass("msm-selected");
    });
};

/**
 * Store the current MSM selection in localStorage and open the Batch Operations page
 * in a new tab. The batch page reads the key and pre-checks those archives.
 */
Index.openBatchOnSelection = function () {
    if (Index.selectedArchives.size === 0) return;
    LRR.openInNewTab(new LRR.apiURL("/batch"));
};

// #endregion

// #region Periodic checks (Update notifications, progression migration)

/**
 * Check the GitHub API to see if an update was released.
 * If so, flash another friendly notification inviting the user to check it out
 */
Index.checkVersion = function () {
    const githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";

    fetch(githubAPI)
        .then((response) => {
            if (response.ok) {
                return response.json();
            }
            if (response.status === 403) {
                console.warn("Github API rate limit exceeded: ", response);
                throw new Error(I18N.IndexGithubRateLimitError);
            }
            console.warn("GitHub API returned: ", response);
            throw new Error(I18N.IndexGithubAPIError(response.status));
        })
        .then((data) => {
            const expr = /(\d+)/g;
            const latestVersionArr = Array.from(data.tag_name.match(expr));
            let latestVersion = "";
            const currentVersionArr = Array.from(Index.serverVersion.match(expr));
            let currentVersion = "";

            latestVersionArr.forEach((element, index) => {
                if (index + 1 < latestVersionArr.length) {
                    latestVersion = `${latestVersion}${element}`;
                } else {
                    latestVersion = `${latestVersion}.${element}`;
                }
            });
            currentVersionArr.forEach((element, index) => {
                if (index + 1 < currentVersionArr.length) {
                    currentVersion = `${currentVersion}${element}`;
                } else {
                    currentVersion = `${currentVersion}.${element}`;
                }
            });

            if (latestVersion > currentVersion) {
                LRR.toast({
                    heading: I18N.IndexUpdateNotif(data.tag_name),
                    text: `<a href="${data.html_url}">${I18N.IndexUpdateNotif2}</a>`,
                    icon: "info",
                    closeOnClick: false,
                    draggable: false,
                    hideAfter: 7000,
                });
            }
        })
        .catch((error) => console.log("Error checking latest version.", error));
};

/**
 * Fetch the latest LRR changelog and show it to the user if he just updated
 */
Index.fetchChangelog = function () {
    if (localStorage.lrrVersion !== Index.serverVersion) {
        localStorage.lrrVersion = Index.serverVersion;

        fetch("https://api.github.com/repos/difegue/lanraragi/releases/latest", { method: "GET" })
            .then((response) => {
                if (response.ok) {
                    return response.json();
                }
                if (response.status === 403) {
                    console.warn("Github API rate limit exceeded: ", response);
                    throw new Error(I18N.IndexGithubRateLimitError);
                }
                console.warn("GitHub API returned: ", response);
                throw new Error(I18N.IndexGithubAPIError(response.status));
            })
            .then((data) => {
                if (data.error) throw new Error(data.error);

                if (data.state === "failed") {
                    throw new Error(data.result);
                }

                marked.parse(data.body, {
                    gfm: true,
                    breaks: true,
                    sanitize: true,
                }, (err, html) => {
                    document.getElementById("changelog").innerHTML = html;
                    $("#updateOverlay").scrollTop(0);
                });

                $("#overlay-shade").fadeTo(150, 0.6, () => {
                    $("#updateOverlay").css("display", "block");
                });
            })
            .catch((error) => { LRR.showErrorToast(I18N.IndexUpdateError, error); });
    }
};

/**
 * If server-side progress tracking is enabled, migrate local progression to the server.
 */
Index.migrateProgress = function () {
    // No migration if local progress is enabled, or if progress is authenticated and we're not logged in.
    if (Index.isProgressLocal || (Index.isProgressAuthenticated && !LRR.isUserLogged())) {
        return;
    }

    const localProgressKeys = Object.keys(localStorage).filter((x) => x.endsWith("-reader")).map((x) => x.slice(0, -7));
    if (localProgressKeys.length > 0) {
        LRR.toast({
            heading: I18N.LocalProgression,
            text: I18N.LocalProgressionDesc + " ☕",
            icon: "info",
            hideAfter: 23000,
        });

        const promises = [];
        localProgressKeys.forEach((id) => {
            const progress = localStorage.getItem(`${id}-reader`);

            promises.push(fetch(new LRR.apiURL(`api/archives/${id}/metadata`), { method: "GET" })
                .then((response) => response.json())
                .then((data) => {
                    // Don't migrate if the server progress is already further
                    if (progress !== null
                        && data !== undefined
                        && data !== null
                        && progress > data.progress) {
                        Server.callAPI(`api/archives/${id}/progress/${progress}?force=1`, "PUT", null, I18N.LocalProgressionError, null);
                    }

                    // Clear out localStorage'd progress
                    localStorage.removeItem(`${id}-reader`);
                    localStorage.removeItem(`${id}-totalPages`);
                }));
        });

        Promise.all(promises).then(() => LRR.toast({
            heading: I18N.LocalProgressionComplete + " 🎉",
            text: I18N.LocalProgressionCompleteDesc,
            icon: "success",
            hideAfter: 13000,
        }));
    } else {
        // eslint-disable-next-line no-console
        console.log("No local reading progression to migrate");
    }
};

// #endregion

// #region Archive Context Menu

/**
 * Build category list for contextMenu and checkoff the ones the given ID belongs to.
 * @param {*} catList The list of categories, obtained statically
 * @param {*} id The ID of the archive to check
 * @returns Categories
 */
Index.loadContextMenuCategories = (catList, id) => Server.callAPI(`/api/archives/${id}/categories`, "GET", null, I18N.IndexIdLoadError(id),
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
                        if (catId === localStorage.getItem("bookmarkCategoryId")) {
                            Index.bookmarkIconOn(id);
                        }
                    } else {
                        Server.removeArchiveFromCategory(id, catId);
                        if (catId === localStorage.getItem("bookmarkCategoryId")) {
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

/**
 * Build rating options for contextMenu and select the one for the current ID.
 * @param {*} id The ID of the archive to check
 * @returns Ratings
 */
Index.loadContextMenuRatings = (id) => Server.callAPI(`/api/archives/${id}/metadata`, "GET", null, I18N.IndexIdLoadError(id),
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
        const tags = LRR.splitTagsByNamespace(data.tags);
        const hasRating = Object.keys(tags).some(x => x === "rating");
        const ratingValue = hasRating ? tags["rating"] : [0];

        for (let i = 0; i < ratings.length; i++) {
            items[i] = ratings[i];
            items[i].type = "checkbox";

            if (items[i].name === ratingValue[0]) { items[i].selected = true; }
            items[i].events = {
                click() {
                    if (i === 0) delete tags["rating"];
                    else tags["rating"] = [ratings[i].name];

                    Server.updateTagsFromArchive(id, LRR.buildTagList(tags));

                    // Update the rating info without reload but have to refresh everything.
                    IndexTable.dataTable.ajax.reload(null, false);
                    Index.updateCarousel();
                    $(this).parents("ul.context-menu-list").find("input[type='checkbox']").toArray().filter((x) => x !== this).forEach(x => x.checked = false);
                },
            };
        }

        return items;
    },
);

/**
 * Handle context menu clicks.
 * @param {*} option The clicked option
 * @param {*} id The Archive ID
 * @returns
 */
Index.handleContextMenu = function (option, id) {
    switch (option) {
        case "edit":
            LRR.openInNewTab(new LRR.apiURL(`/edit?id=${id}`));
            break;
        case "delete":
            LRR.showPopUp({
                text: I18N.ConfirmArchiveDeletion,
                icon: "warning",
                showCancelButton: true,
                focusConfirm: false,
                confirmButtonText: I18N.ConfirmYes,
                reverseButtons: true,
                confirmButtonColor: "#d33",
            }).then((result) => {
                if (result.isConfirmed) {
                    Server.deleteArchive(id, () => { document.location.reload(true); });
                }
            });
            break;
        case "read":
            LRR.openInNewTab(new LRR.apiURL(`/reader?id=${id}`));
            break;
        case "download":
            LRR.openInNewTab(new LRR.apiURL(`/api/archives/${id}/download`));
            break;
        case "copy link":
            Index.pseudoCopyBtn.attr("data-clipboard-text", `${window.location.origin}${new LRR.apiURL(`/reader?id=${id}`).toString()}`);
            Index.pseudoCopyBtn.click()
            break;
        case "msm-toggle-archive":
            if (!Index.isMultiSelectMode) Index.toggleMultiSelectMode();
            Index.toggleArchiveSelection(id);
            break;
        default:
            break;
    }
};

// #endregion

// #region Category buttons

/**
 * Toggles a category filter.
 * Sets the internal selectedCategory variable and changes the button's class.
 * @param {*} button Button matching the category.
 */
Index.toggleCategory = function (button) {
    // Add/remove class to button depending on the state
    const categoryId = button.id;
    if (Index.selectedCategory === categoryId) {
        button.classList.remove("toggled");
        Index.selectedCategory = "";
    } else {
        Index.selectedCategory = categoryId;
        button.classList.add("toggled");
    }

    // Trigger search
    IndexTable.doSearch();
};

/**
 * Query the category API to build the filter buttons.
 */
Index.loadCategories = function () {
    return Server.callAPI("/api/categories", "GET", null, I18N.CategoryFetchError,
        (data) => {
            // Sort by pinned + alpha
            // Pinned categories are shown at the beginning
            data.sort((b, a) => b.name.localeCompare(a.name));
            data.sort((a, b) => b.pinned - a.pinned);
            // Queue some hardcoded categories at the beginning - those are special-cased in the DataTables variant of the search endpoint. 
            let html = `<div style='display:inline-block'>
                            <input class='favtag-btn ${(("NEW_ONLY" === Index.selectedCategory) ? "toggled" : "")}' 
                            type='button' id='NEW_ONLY' value='🆕 ${I18N.NewArchives}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.NewArchiveDesc}'/>
                        </div><div style='display:inline-block'>
                            <input class='favtag-btn ${(("UNTAGGED_ONLY" === Index.selectedCategory) ? "toggled" : "")}' 
                            type='button' id='UNTAGGED_ONLY' value='🏷️ ${I18N.UntaggedArchives}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.UntaggedArcDesc}'/>
                        </div>`;

            const iteration = (data.length > 10 ? 10 : data.length);

            for (let i = 0; i < iteration; i++) {
                const category = data[i];
                const pinned = category.pinned === "1";

                let catName = (pinned ? "📌" : "") + category.name;
                catName = LRR.encodeHTML(catName);

                const div = `<div style='display:inline-block'>
                    <input class='favtag-btn ${((category.id === Index.selectedCategory) ? "toggled" : "")}' 
                            type='button' id='${category.id}' value='${catName}' 
                            onclick='Index.toggleCategory(this)' title='${I18N.CategoryDesc}'/>
                </div>`;

                // Take this opportunity to update the bookmark
                if (category.id === localStorage.getItem("bookmarkCategoryId")) {
                    localStorage.setItem("bookmarkedArchives", JSON.stringify(category.archives));
                }

                html += div;
            }

            // If more than 10 categories, the rest goes into a dropdown
            if (data.length > 10) {
                html += `<select id="catdropdown" class="favtag-btn">
                            <option selected disabled>...</option>`;

                for (let i = 10; i < data.length; i++) {
                    const category = data[i];

                    html += `<option id='${category.id}'>
                                ${LRR.encodeHTML(category.name)}
                            </option>`;
                }
                html += "</select>";
            }

            $("#category-container").html(html);

            // Add a listener on dropdown selection
            $("#catdropdown").on("change", () => Index.toggleCategory($("#catdropdown")[0].selectedOptions[0]));
        },
    );
};

// #endregion

// #region Custom Columns (Compact Mode)

/**
 * Show a prompt to update the namespace of a column in compact mode.
 * @param {*} column Index of the column to modify
 */
Index.promptCustomColumn = function (column) {
    LRR.showPopUp({
        title: I18N.CustomColumn,
        text: I18N.CustomColumnDesc + "\n" + I18N.CustomColumnDesc2,
        input: "text",
        inputValue: localStorage.getItem(`customColumn${column}`),
        inputPlaceholder: I18N.TagNamespace,
        inputAttributes: {
            autocapitalize: "off",
        },
        showCancelButton: true,
        reverseButtons: true,
        inputValidator: (value) => {
            if (!value) {
                return I18N.TagNamespaceError;
            }
            return undefined;
        },
    }).then((result) => {
        if (result.isConfirmed) {
            if (!LRR.isNullOrWhitespace(result.value)) {
                const namespace = result.value.trim();
                localStorage.setItem(`customColumn${column}`, namespace);

                IndexTable.dataTable.settings()[0].aoColumns[column].sName = namespace;
                // Update header text in-place to preserve DataTables sort handlers
                $(`#header-${column}`).html(namespace.charAt(0).toUpperCase() + namespace.slice(1));
                IndexTable.doSearch();
            }
        }
    });
};

/**
 * Update table controls to reflect the current status.
 * @param {*} currentSort Current sort column
 * @param {*} currentOrder Current sort order
 * @param {*} totalPages Total pages of the table
 * @param {*} currentPage Current page of the table
 */
Index.updateTableControls = function (currentSort, currentOrder, totalPages, currentPage) {
    $(".table-options").show();

    $("#namespace-sortby").val(currentSort);
    $("#order-sortby")[0].classList.remove("fa-sort-alpha-down", "fa-sort-alpha-up");
    $("#order-sortby")[0].classList.add(currentOrder === "asc" ? "fa-sort-alpha-down" : "fa-sort-alpha-up");

    if (localStorage.indexViewMode === "1") {
        $(".thumbnail-options").show();
        $(".compact-options").hide();
    } else {
        $(".thumbnail-options").hide();
        $(".compact-options").show();
    }

    // Page selector
    const pageSelect = $("#page-select");
    pageSelect.empty();

    for (let j = 1; j <= totalPages; j++) {
        const oOption = document.createElement("option");
        oOption.text = j;
        oOption.value = j;
        pageSelect[0].add(oOption, null);
    }

    pageSelect.val(currentPage);
};

Index.handleCustomSort = function () {
    const namespace = $("#namespace-sortby").val();
    const order = IndexTable.dataTable.order();

    // Special case for title sorting, as that uses column 0
    if (namespace === "title") {
        order[0][0] = 0;
    } else {
        // The order set in the combobox uses is offset from title by 1; 
        // e.g. customColumn1 is offset from title by 1.
        order[0][0] = 1;
        localStorage.customColumn1 = namespace;
        IndexTable.dataTable.settings()[0].aoColumns[1].sName = namespace;
        // Update header text in-place to preserve DataTables sort handlers
        $(`#header-1`).html(namespace.charAt(0).toUpperCase() + namespace.slice(1));
    }

    IndexTable.dataTable.order(order);
    IndexTable.dataTable.draw();
};

Index.handleColumnNum = function () {
    const columnCountSelect = document.getElementById("columnCount");
    const selectedCount = columnCountSelect.value;
    localStorage.setItem("columnCount", selectedCount);
    Index.updateTableHeaders();
    document.location.reload(true);
};

/**
 * Generate the Table Headers based on the custom namespaces set in localStorage.
 */
Index.generateTableHeaders = function (columnCount) {
    const headerRow = $("#header-row");
    headerRow.empty();
    const headerWidth = localStorage.getItem(`resizeColumn0`) || "";
    headerRow.append(`
        <th id="titleheader" width="${headerWidth}">
            <a>${I18N.IndexTitle}</a>
        </th>`);

    for (let i = 1; i <= columnCount; i++) {
        const customColumn = localStorage[`customColumn${i}`] || `Header ${i}`;
        const colWidth = localStorage.getItem(`resizeColumn${i}`) || "";

        const headerHtml = `
            <th id="customheader${i}" width="${colWidth}">
                <i id="edit-header-${i}" class="fas fa-pencil-alt edit-header-btn" title="${I18N.IndexEditColumn}"></i>
                <a id="header-${i}">${customColumn.charAt(0).toUpperCase() + customColumn.slice(1)}</a>
            </th>`;
        headerRow.append(headerHtml);
    }
    headerRow.append(`
        <th id="tagsheader">
            <a>${I18N.IndexTags}</a>
        </th>`);
};


/**
 * Update the Table Headers based on the custom namespaces set in localStorage.
 */
Index.updateTableHeaders = function () {
    let columnCount = Index.getColumnCount();
    Index.generateTableHeaders(columnCount);

    for (let i = 1; i <= columnCount; i++) {
        const customColumn = localStorage[`customColumn${i}`] || `${I18N.IndexHeader} ${i}`;
        $(`#customcol${i}`).val(customColumn);

        $(`#header-${i}`).html(customColumn.charAt(0).toUpperCase() + customColumn.slice(1) || `${I18N.IndexHeader} ${i}`);
    }
};

/**
 * Restore and update column width, data store in localstorge.
 */
Index.resizableColumns = function () {
    let currentHeader;
    let currentIndex;
    let startX;
    let startWidth;
    let didDrag = false;

    const headers = document.querySelectorAll("#header-row th");
    headers.forEach(header => {
        // init
        header.addEventListener("mousedown", function (event) {
            if (event.offsetX > header.offsetWidth - 10) {
                currentHeader = header;
                currentIndex = Array.from(headers).indexOf(currentHeader);
                startX = event.clientX;

                startWidth = localStorage.getItem(`resizeColumn${currentIndex}`) || header.width || header.offsetWidth;
                if (!Number.isInteger(startWidth))
                    startWidth = parseInt(startWidth.replace("px", ""));

                didDrag = false;

                document.addEventListener("mousemove", resizeColumn);
                document.addEventListener("mouseup", stopResize);

                document.body.style.cursor = "col-resize";
            }
        });
        header.addEventListener("click", function (e) {
            if (didDrag) {
                // If releasing from a drag, block click.DT handler from triggering a draw.
                e.stopImmediatePropagation();
                didDrag = false;
            }
        }, true);
        header.addEventListener("mousemove", function (event) {
            if (event.offsetX > header.offsetWidth - 10) {
                header.style.cursor = "col-resize";
            } else {
                header.style.cursor = "default";
            }
        });
    });

    function resizeColumn(event) {
        didDrag = true;
        if (currentHeader) {
            currentHeader.style.cursor = "col-resize";
            let newWidth = startWidth + (event.clientX - startX);
            const minWidth = parseInt(window.getComputedStyle(currentHeader).minWidth.replace("px", ""));
            const maxWidth = parseInt(window.getComputedStyle(currentHeader).maxWidth.replace("px", ""));

            if (newWidth > maxWidth)
                newWidth = maxWidth;

            if (newWidth < minWidth)
                newWidth = minWidth;

            if (newWidth > 0) {
                currentHeader.style.width = newWidth + "px";
                localStorage.setItem(`resizeColumn${currentIndex}`, newWidth + "px");
            }
        }
    }

    function stopResize() {
        if (currentHeader) {
            currentHeader = null;
        }
        document.removeEventListener("mousemove", resizeColumn);
        document.removeEventListener("mouseup", stopResize);

        document.body.style.cursor = "default";
    }
};

/**
 * @returns number of custom columns in compact mode
 */
Index.getColumnCount = function () {
    return localStorage.getItem("columnCount") ? parseInt(localStorage.getItem("columnCount")) : 2;
}

// #endregion

jQuery(() => {
    Index.initializeAll();
});
