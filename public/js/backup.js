/**
 * Backup Operations.
 */
const Backup = {};

Backup.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.return", "#return", () => { window.location.replace("./"); });
    $(document).on("click.do-backup", "#do-backup", () => { window.open("./backup?dobackup=1", "_blank"); });

    // Handler for file uploading.
    $("#fileupload").fileupload({
        dataType: "json",
        done(e, data) {
            $("#processing").attr("style", "display:none");

            if (data.result.success === 1) $("#result").html("Backup restored!");
            else $("#result").html(data.result.error);
        },

        fail() {
            $("#processing").attr("style", "display:none");
            $("#result").html("An error occured server-side. woops.<br/> Maybe your JSON is badly formatted ?");
        },

        progressall() {
            $("#result").html("");
            $("#processing").attr("style", "");
        },

    });
};

jQuery(() => {
    Backup.initializeAll();
});

window.Backup = Backup;
