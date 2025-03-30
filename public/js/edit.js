/**
 * JS functions meant for use in the Edit page.
 * Mostly dealing with plugins.
 */
const Edit = {};

Edit.tagInput = null;
Edit.suggestions = [];

Edit.initializeAll = function () {
    // bind events to DOM
    $(document).on("change.plugin", "#plugin", Edit.updateOneShotArg);
    $(document).on("click.show-help", "#show-help", Edit.showHelp);
    $(document).on("click.run-plugin", "#run-plugin", Edit.runPlugin);
    $(document).on("click.save-metadata", "#save-metadata", Edit.saveMetadata);
    $(document).on("click.delete-archive", "#delete-archive", Edit.deleteArchive);
    $(document).on("click.tagger", ".tagger", Edit.focusTagInput);
    $(document).on("click.goback", "#goback", () => { window.location.href = new LRR.apiURL("/"); });
    $(document).on("paste.tagger", ".tagger-new", Edit.handlePaste);

    Edit.updateOneShotArg();

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
                    link: (name) => new LRR.apiURL(`/?q=${name}`),
                });
            }
        });
};

// this checks whether the rich-text tag editor is in use (initialized
// on tagInput); if so, call its method to add the tag; if not, edit
// the string directly
Edit.addTag = function (tag) {
    tag = tag.trim();
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

    // Get pasted data via clipboard API
    const pastedData = event.originalEvent.clipboardData.getData("Text");

    if (pastedData !== "") {
        pastedData.split(/,\s?/).forEach((tag) => {
            Edit.addTag(tag);
        });
    }
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

    const formData = new FormData();
    formData.append("tags", $("#tagText").val());
    formData.append("title", $("#title").val());
    formData.append("summary", $("#summary").val());

    return fetch(new LRR.apiURL(`/api/archives/${id}/metadata`), { method: "PUT", body: formData })
        .then((response) => (response.ok ? response.json() : { success: 0, error: "Response was not OK" }))
        .then((data) => {
            if (data.success) {
                LRR.toast({
                    heading: I18N.EditMetadataSaved,
                    icon: "success",
                });
            } else {
                throw new Error(data.message);
            }
        })
        .catch((error) => LRR.showErrorToast(I18N.EditMetadataError, error))
        .finally(() => {
            Edit.showTags();
        });
};

Edit.deleteArchive = function () {
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
            Server.deleteArchive($("#archiveID").val(), () => { document.location.href = "./"; });
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

            if (result.data.summary && result.data.summary !=="") {
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
