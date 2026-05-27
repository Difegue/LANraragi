/**
 * JS functions meant for use in the Edit page.
 * Mostly dealing with plugins.
 */
import * as Server from "mod/server";
import * as LRR from "mod/common";
import I18N from "i18n";

const Edit = {};

Edit.tagInput = null;
Edit.suggestions = [];
Edit.isTank = false;

Edit.initializeAll = function () {
    Edit.isTank = $("body").data("is-tank") === 1;

    // bind events to DOM
    $(document).on("change.plugin", "#plugin", Edit.updateOneShotArg);
    $(document).on("click.show-help", "#show-help", Edit.showHelp);
    $(document).on("click.run-plugin", "#run-plugin", Edit.runPlugin);
    $(document).on("click.save-metadata", "#save-metadata", Edit.saveMetadata);
    $(document).on("click.delete-archive", "#delete-archive", Edit.deleteArchive);
    $(document).on("click.read-archive", "#read-archive", () => { window.location.href = new LRR.ApiURL(`/reader?id=${$("#archiveID").val()}`); });
    $(document).on("click.tagger", ".tagger", Edit.focusTagInput);
    $(document).on("click.goback", "#goback", () => { window.location.href = new LRR.ApiURL("/"); });
    $(document).on("paste.tagger", ".tagger-new", Edit.handlePaste);
    $(document).on("keydown.run-plugin-enter", "#arg", Edit.runPluginByEnter);

    if (Edit.isTank) {
        $(document).on("click.add-archive", "#add-archive-btn", Edit.addArchiveToTank);
        $(document).on("click.remove-archive", ".remove-archive", Edit.removeArchiveFromTank);
        $(document).on("click.tank-help", "#tank-help", Edit.showTankHelp);
        Edit.initSortable();
    } else {
        Edit.updateOneShotArg();
    }

    // Hide tag input while statistics load
    Edit.hideTags();

    Server.callAPI("/api/database/stats?minweight=2", "GET", null, I18N.TagStatsLoadFailure,
        (data) => {
            Edit.suggestions = data.reduce((res, tag) => {
                let label = tag.text;
                if (tag.namespace !== "") { label = `${tag.namespace}:${tag.text}`; }
                res.push(label);
                return res;
            }, []);
        },
    )
        .finally(() => {
            const input = $("#tagText")[0];

            Edit.showTags();

            // Initialize tagger unless we're on a mobile OS (#531)
            if (!LRR.isMobile()) {
                Edit.tagInput = tagger(input, {
                    allow_duplicates: false,
                    allow_spaces: true,
                    wrap: true,
                    completion: {
                        list: Edit.suggestions,
                    },
                    link: (name) => new LRR.ApiURL(`/?q=${name}`),
                });
            }
        });
};

Edit.initSortable = function () {
    const list = document.getElementById("tank-archive-list");
    if (!list || typeof Sortable === "undefined") return;

    Sortable.create(list, {
        handle: ".drag-handle",
        animation: 150,
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        //onEnd: Edit.saveArchiveOrder,
    });
};

Edit.addArchiveToTank = function () {
    const tankId = $("#archiveID").val();
    const arcId = $("#add-archive-id").val().trim();
    if (!arcId) return;

    // Get the Archive metadata to feature the name, but don't actually save the Tank.
    // That's handled by the Save button.
    Server.callAPI(`/api/archives/${arcId}`, "GET", 
        null,
        I18N.TankoubonAddArchiveError,
        (data) => {
            const li = $(`<li data-id="${arcId}">
                <i class="fas fa-grip-vertical drag-handle"></i>
                <span class="arc-title" onmouseover="IndexTable.buildImageTooltip(this)">${data.title}</span>
                <div class="caption" style="display: none;">
                    <img style="height:300px" src='${new LRR.ApiURL("/api/archives/"+arcId+"/thumbnail")}'
                        onerror="this.src='${new LRR.ApiURL("/img/noThumb.png")}'">
                </div>
                <a class="remove-archive" title="${I18N.TankoubonRemoveFromMenu}">	
                    <i class="fas fa-close" style="text-align:right"></i>
                </a>
            </li>`);
            $("#tank-archive-list").append(li);
            $("#add-archive-id").val("");
        },
    );

};

Edit.removeArchiveFromTank = function () {
    $(this).closest("li").remove();
};

// this checks whether the rich-text tag editor is in use (initialized
// on tagInput); if so, call its method to add the tag; if not, edit
// the string directly
Edit.addTag = function (tagInput) {
    let tag = tagInput.trim();
    if (Edit.tagInput) {
        Edit.tagInput.add_tag(tag);
    } else {
        let val = $("#tagText").val().trim();
        if (val == "") {
            $("#tagText").val(tag);
        } else {
            $("#tagText").val(`${val}, ${tag}`);
        }
    }
};

Edit.handlePaste = function (event) {
    // Stop data actually being pasted into div
    event.stopPropagation();
    event.preventDefault();

    // Get the pending text already typed in the input field
    const inputElement = $(".tagger-new").children()[0];
    const pendingText = inputElement ? inputElement.value : "";

    // Get pasted data via clipboard API
    const pastedData = event.originalEvent.clipboardData.getData("Text");

    if (pastedData !== "") {
        // Split by comma to handle multiple pasted tags
        const tags = pastedData.split(/,\s?/);

        // Prepend pending text to the first tag
        if (pendingText && tags.length > 0) {
            tags[0] = pendingText + tags[0];

            // Clear the pending text from the input since we're incorporating it
            if (inputElement) {
                inputElement.value = "";
            }
        }

        tags.forEach((tag) => {
            Edit.addTag(tag);
        });
    }
};

/**
 * Invoke plugin when Enter is pressed in the plugin argument input field.
 * @param {KeyboardEvent} e - The keyboard event
 */
Edit.runPluginByEnter = function (e) {
    if (e.key !== "Enter") return;
    e.preventDefault();
    Edit.runPlugin();
};

Edit.hideTags = function () {
    $("#tag-spinner").css("display", "block");
    $("#tagText").css("opacity", "0.5");
    $("#tagText").prop("disabled", true);
    $("#plugin-table").hide();
};

Edit.showTags = function () {
    $("#tag-spinner").css("display", "none");
    $("#tagText").prop("disabled", false);
    $("#tagText").css("opacity", "1");
    $("#plugin-table").show();
};

Edit.focusTagInput = function () {
    // Focus child of tagger-new
    $(".tagger-new").children()[0].focus();
};

Edit.showHelp = function () {
    LRR.toast({
        toastId: "pluginHelp",
        heading: I18N.EditHelpTitle,
        text: I18N.EditHelp,
        icon: "info",
        hideAfter: 33000,
    });
};

Edit.showTankHelp = function () {
    LRR.toast({
        toastId: "tankHelp",
        heading: I18N.TankoubonHelpTitle,
        text: I18N.TankoubonHelp,
        icon: "info",
        hideAfter: 33000,
    });
};

Edit.updateOneShotArg = function () {
    // show input
    $("#arg_label").show();
    $("#arg").show();

    const arg = `${$("#plugin").find(":selected").get(0).getAttribute("arg")} : `;

    // hide input for plugins without a oneshot argument field
    if (arg === " : ") {
        $("#arg_label").hide();
        $("#arg").hide();
    }

    $("#arg_label").html(arg);
};

Edit.saveMetadata = function () {
    Edit.hideTags();
    const id = $("#archiveID").val();

    let fetchPromise;

    if (Edit.isTank) {
        const metadata = {
            name: $("#title").val(),
            summary: $("#summary").val(),
            tags: $("#tagText").val(),
        };
        const archives = $("#tank-archive-list li").map((_, el) => $(el).data("id")).get();
        Server.callAPIBody(`api/tankoubons/${id}`, "PUT", JSON.stringify({ metadata, archives }),
            I18N.EditMetadataSaved,
            I18N.TankoubonEditError, null)
        .finally(() => {
            Edit.showTags();
        });

    } else {
        const formData = new FormData();
        formData.append("tags", $("#tagText").val());
        formData.append("title", $("#title").val());
        formData.append("summary", $("#summary").val());
        Server.callAPIBody(`api/archives/${id}/metadata`, "PUT", formData,
            I18N.EditMetadataSaved,
            I18N.EditMetadataError, null)
        .finally(() => {
            Edit.showTags();
        });
    }
};

Edit.deleteArchive = function () {
    const confirmText = Edit.isTank ? I18N.ConfirmTankoubonDeletion : I18N.ConfirmArchiveDeletion;
    LRR.showPopUp({
        text: confirmText,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            const id = $("#archiveID").val();
            if (Edit.isTank) {
                Server.deleteTankoubon(id, () => { document.location.href = "./"; });
            } else {
                Server.deleteArchive(id, () => { document.location.href = "./"; });
            }
        }
    });
};

Edit.getTags = function () {
    Edit.hideTags();

    const pluginID = $("select#plugin option:checked").val();
    const archivID = $("#archiveID").val();
    const pluginArg = $("#arg").val();
    Server.callAPI(`/api/plugins/use?plugin=${pluginID}&id=${archivID}&arg=${pluginArg}`, "POST", null, I18N.EditFetchTagError,
        (result) => {
            if (result.data.title && result.data.title !== "") {
                $("#title").val(result.data.title);
                LRR.toast({
                    heading: I18N.EditTitleChangedTo,
                    text: result.data.title,
                    icon: "info",
                });
            }

            if (result.data.summary && result.data.summary !== "") {
                $("#summary").val(result.data.summary);
                LRR.toast({
                    heading: I18N.EditSummaryUpdated,
                    icon: "info",
                });
            }

            if (result.data.new_tags !== "") {
                result.data.new_tags.split(/,\s?/).forEach((tag) => {
                    Edit.addTag(tag);
                });

                LRR.toast({
                    heading: I18N.EditTagsAdded,
                    text: result.data.new_tags,
                    icon: "info",
                    hideAfter: 7000,
                });
            } else {
                LRR.toast({
                    heading: I18N.EditNoNewTags,
                    text: result.data.new_tags,
                    icon: "info",
                });
            }
        },
    ).finally(() => {
        Edit.showTags();
    });
};

Edit.runPlugin = function () {
    Edit.saveMetadata().then(() => Edit.getTags());
};

jQuery(() => {
    Edit.initializeAll();
});
