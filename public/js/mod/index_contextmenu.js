
// #region Archive Context Menu

import * as LRR from "./common.js";
import * as Server from "./server.js";
import * as Index from "./index.js";
import * as IndexTable from "./index_datatables.js";
import I18N from "i18n";

let pseudoCopyBtn = undefined;

function handleDelete(id) {
    const isTank = id.startsWith("TANK_");
    LRR.showPopUp({
        text: isTank ? I18N.ConfirmTankoubonDeletion : I18N.ConfirmArchiveDeletion,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    })
        .then((result) => {
            if (result.isConfirmed) {
                if (isTank) Server.deleteTankoubon(id, () => {
                    document.location.reload();
                });
                else Server.deleteArchive(id, () => {
                    document.location.reload();
                });
            }
        });
}

/**
 * Handle context menu clicks.
 * @param {*} option The clicked option
 * @param {*} id The Archive ID
 * @returns
 */
function handleContextMenu(option, id) {
    switch (option) {
        case "edit":
            LRR.openInNewTab(new LRR.ApiURL(`/edit?id=${id}`));
            break;
        case "delete":
            handleDelete(id);
            break;
        case "read":
            sessionStorage.setItem("navigationState", window.contextMenuSource === "carousel" ? "carousel" : "datatables");
            LRR.openInNewTab(new LRR.ApiURL(`/reader?id=${id}`));
            break;
        case "download":
            LRR.openInNewTab(new LRR.ApiURL(`/api/archives/${id}/download`));
            break;
        case "copy link":
            pseudoCopyBtn.attr("data-clipboard-text", `${window.location.origin}${new LRR.ApiURL(`/reader?id=${id}`).toString()}`);
            pseudoCopyBtn.click();
            break;
        case "msm-toggle-archive":
            if (!Index.isMultiSelectMode) Index.toggleMultiSelectMode();
            Index.toggleArchiveSelection(id);
            break;
        default:
            break;
    }
}

// #endregion

// #region Context Menu Functions

/**
 * Build category list for contextMenu and checkoff the ones the given ID belongs to.
 * @param {*} catList The list of categories, obtained statically
 * @param {*} id The ID of the archive or tankoubon to check
 * @returns Categories
 */
function loadContextMenuCategories(catList, id){
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
}

/**
 * Build rating options for contextMenu and select the one for the current ID.
 * @param {*} id The ID of the archive or tankoubon to check
 * @param {*} refreshCallback Optional callback to refresh the view after rating change
 * @returns Ratings
 */
function loadContextMenuRatings(id, refreshCallback) {
    const isTankoubon = id.startsWith("TANK_");
    const endpoint = isTankoubon ? `/api/tankoubons/${id}` : `/api/archives/${id}/metadata`;

    return Server.callAPI(endpoint, "GET", null, I18N.IndexIdLoadError(id),
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
                        if(i === 0) delete tags["rating"];
                        else tags["rating"] = [ratings[i].name];

                        if (isTankoubon) 
                            Server.updateTagsFromTankoubon(id, LRR.buildTagList(tags));
                        else 
                            Server.updateTagsFromArchive(id, LRR.buildTagList(tags));

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

export function initialize(catListData) {
    const catList = catListData || [];
    pseudoCopyBtn = $("#pseudo-copy-btn");
    const clipboard = new window.ClipboardJS("#pseudo-copy-btn");

    clipboard.on("success", function (e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkSuccess,
            icon: "info",
            hideAfter: 3000,
        });
        e.clearSelection();
    });

    clipboard.on("error", function (_e) {
        LRR.toast({
            heading: I18N.IndexCopyLinkFail,
            icon: "error",
            hideAfter: false,
        });
    });

    // Initialize context menu
    $.contextMenu({
        selector: ".context-menu",
        events: {
            // Record whether this context menu was opened from the carousel or datatables,
            // so Reader can later decide whether to enable cross-archive navigation.
            show: function (_options) {
                window.contextMenuSource = $(this).closest(".swiper-wrapper").length > 0
                    ? "carousel"
                    : "datatables";
            }
        },
        build: ($trigger, _e) => {
            const id = $trigger.attr("id");
            const isTankoubon = id && id.startsWith("TANK_");

            let items = {
                "read": {
                    name: I18N.Read,
                    icon: "fas fa-book"
                },
                ...(!isTankoubon ? {
                    "download": {
                        name: I18N.Download,
                        icon: "fas fa-save"
                    }
                } : {}),
                "copy link": {
                    name: I18N.CopyLink,
                    icon: "fas fa-link"
                },
                "msm-toggle-archive": {
                    name: Index.selectedArchives.has(id)
                        ? I18N.MSMRemoveFromSelection
                        : I18N.MSMAddToSelection,
                    icon: "fas fa-check-square"
                }
            };

            if (LRR.isUserLogged()) {
                let moreItems = {
                    "sep1": "---------",
                    "edit": {
                        name: I18N.EditMetadata,
                        icon: "fas fa-pencil-alt"
                    },
                    "delete": {
                        name: I18N.Delete,
                        icon: "fas fa-trash-alt"
                    },
                    "rating": {
                        "name": I18N.AddRating,
                        "icon": "fas fa-star",
                        "items": loadContextMenuRatings(id)
                    },
                    "collections": {
                        "name": I18N.AddToCategory,
                        "icon": "fas fa-search-plus",
                        "items": loadContextMenuCategories(catList, id)
                    }
                };
                Object.assign(items, moreItems);
            }

            return {
                callback: function (key, _options) {
                    handleContextMenu(key, $(this)
                        .attr("id"));
                },
                items: items,
            };
        }
    });
}
