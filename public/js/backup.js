/**
 * Backup Operations
 * @global
 */
const Backup = {};

Backup.currentJob = null;

Backup.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.apiURL("/"); });
    $(document).on("click.do-backup", "#do-backup", Backup.startBackup);

    // Handler for file uploading - using API endpoint with formdata
    $("#fileupload").fileupload({
        url: "./api/database/restore",
        dataType: "json",
        done(e, data) {
            if (data.result.success === 1) {
                Backup.currentJob = data.result.job;
                $("#processing").attr("style", "");
                $("#processing-status").html(I18N.BackupRestoring);
                $("#result").html("");
                
                // Poll the job status
                Backup.pollJob(data.result.job, false);
            } else {
                $("#result").html(data.result.error);
            }
        },

        fail() {
            $("#processing").attr("style", "display:none");
            $("#result").html(I18N.BackupFailed);
        },

        progressall() {
            $("#result").html("");
            $("#processing").attr("style", "");
            $("#processing-status").html(I18N.BackupUploading);
        },

    });
};

Backup.startBackup = function () {
    $("#processing").attr("style", "");
    $("#processing-status").html(I18N.BackupGenerating);
    $("#result").html("");
    $("#progress-info").html("");
    
    // Disable button to prevent double-clicks
    $("#do-backup").prop("disabled", true);

    // Call the API endpoint to queue the backup job
    Server.callAPI("./api/database/backup", "POST", null, I18N.GenericReponseError,
        (data) => {
            if (data.success === 1) {
                Backup.currentJob = data.job;
                Backup.pollJob(data.job, true);
            } else {
                $("#processing").attr("style", "display:none");
                $("#result").html(I18N.BackupFailed);
                $("#do-backup").prop("disabled", false);
            }
        },
    );
};

Backup.pollJob = function (jobId, isBackup) {
    // Check minion job state periodically
    Server.checkJobStatus(
        jobId,
        true,
        (data) => {
            // Job completed successfully
            $("#processing").attr("style", "display:none");
            $("#do-backup").prop("disabled", false);
            
            if (isBackup) {
                // Download the backup file using API endpoint
                window.open(`./api/database/backup/${jobId}?format=file`, "_blank");
                $("#result").html(I18N.BackupComplete);
            } else {
                $("#result").html(I18N.BackupRestored);
                Server.invalidateCache();
            }
        },
        (error) => {
            // Job failed
            $("#processing").attr("style", "display:none");
            $("#do-backup").prop("disabled", false);
            $("#result").html(I18N.BackupFailed + "<br/>" + error);
        },
        (notes) => {
            // Progress update
            Backup.updateProgress(notes);
        },
    );
};

Backup.updateProgress = function (notes) {
    if (!notes || !notes.status) return;
    
    let progressText = notes.status + "<br/>";
    
    if (notes.categories_processed !== undefined && notes.total_categories !== undefined) {
        progressText += `Categories: ${notes.categories_processed}/${notes.total_categories}<br/>`;
    }
    
    if (notes.tankoubons_processed !== undefined && notes.total_tankoubons !== undefined) {
        progressText += `Tankoubons: ${notes.tankoubons_processed}/${notes.total_tankoubons}<br/>`;
    }
    
    if (notes.archives_processed !== undefined && notes.total_archives !== undefined) {
        progressText += `Archives: ${notes.archives_processed}/${notes.total_archives}`;
    }
    
    $("#progress-info").html(progressText);
};

jQuery(() => {
    Backup.initializeAll();
});
