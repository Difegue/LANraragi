/**
 * Functions for Generic API calls.
 */
const Server = {};

Server.isScriptRunning = false;

/**
 * Call that shows a popup to the user on success/failure.
 * Returns the promise so you can add final callbacks if needed.
 * @param {*} endpoint URL endpoint
 * @param {*} method GET/PUT/DELETE/POST
 * @param {*} successMessage Message written in the toast if request succeeded (success = 1)
 * @param {*} errorMessage Header of the error message if request fails (success = 0)
 * @param {*} successCallback called if request succeeded
 * @returns The result of the callback, or NULL.
 */
Server.callAPI = function (endpoint, method, successMessage, errorMessage, successCallback) {
    endpoint = new LRR.apiURL(endpoint);
    return fetch(endpoint, { method })
        .then((response) => (response.ok ? response.json() : { success: 0, error: I18N.GenericReponseError }))
        .then((data) => {
            if (Object.prototype.hasOwnProperty.call(data, "success") && !data.success) {
                throw new Error(data.error);
            } else {
                let message = successMessage;
                if ("successMessage" in data && data.successMessage) {
                    message = data.successMessage;
                }
                if (message !== null) {
                    LRR.toast({
                        heading: message,
                        icon: "success",
                        hideAfter: 7000,
                    });
                }

                if (successCallback !== null) return successCallback(data);

                return null;
            }
        })
        .catch((error) => LRR.showErrorToast(errorMessage, error));
};

Server.callAPIBody = function (endpoint, method, body, successMessage, errorMessage, successCallback) {
    endpoint = new LRR.apiURL(endpoint);
    return fetch(endpoint, { method, body })
        .then((response) => (response.ok ? response.json() : { success: 0, error: I18N.GenericReponseError }))
        .then((data) => {
            if (Object.prototype.hasOwnProperty.call(data, "success") && !data.success) {
                throw new Error(data.error);
            } else {
                let message = successMessage;
                if ("successMessage" in data && data.successMessage) {
                    message = data.successMessage;
                }
                if (message !== null) {
                    LRR.toast({
                        heading: message,
                        icon: "success",
                        hideAfter: 7000,
                    });
                }

                if (successCallback !== null) return successCallback(data);

                return null;
            }
        })
        .catch((error) => LRR.showErrorToast(errorMessage, error));
};

/**
 * Check the status of a Minion job until it's completed.
 * @param {*} jobId Job ID to check
 * @param {*} useDetail Whether to get full details or the job or not.
 *            This requires the user to be logged in.
 * @param {*} callback Execute a callback on successful job completion.
 * @param {*} failureCallback Execute a callback on unsuccessful job completion.
 * @param {*} progressCallback Execute a callback if the job reports progress. (aka, if there's anything in notes)
 */
Server.checkJobStatus = function (jobId, useDetail, callback, failureCallback, progressCallback = null) {
    let endpoint = new LRR.apiURL(useDetail ? `/api/minion/${jobId}/detail` : `/api/minion/${jobId}`);
    fetch(endpoint, { 
        method: "GET",
        mode: 'same-origin',
        credentials: 'same-origin'
    })
        .then((response) => (response.ok ? response.json() : { success: 0, error: I18N.GenericReponseError }))
        .then((data) => {
            if (data.error) throw new Error(data.error);

            if (data.state === "failed") {
                throw new Error(data.result);
            }

            if (data.state === "inactive") {
                // Job isn't even running yet, wait longer
                setTimeout(() => {
                    Server.checkJobStatus(jobId, useDetail, callback, failureCallback, progressCallback);
                }, 5000);
                return;
            }

            if (data.state === "active") {

                if (progressCallback !== null) {
                    progressCallback(data.notes);
                }

                // Job is in progress, check again in a bit
                setTimeout(() => {
                    Server.checkJobStatus(jobId, useDetail, callback, failureCallback, progressCallback);
                }, 1000);
            }

            if (data.state === "finished") {
                // Update UI with info
                callback(data);
            }
        })
        .catch((error) => { LRR.showErrorToast(I18N.MinionCheckError, error); failureCallback(error); });
};

/**
 * POSTs the data of the specified form to the page.
 * This is used for Edit, Config and Plugins.
 * @param {*} formSelector The form to POST
 * @returns the promise object so you can chain more callbacks.
 */
Server.saveFormData = function (formSelector) {
    const postData = new FormData($(formSelector)[0]);

    return fetch(window.location.href, { method: "POST", body: postData })
        .then((response) => (response.ok ? response.json() : { success: 0, error: I18N.GenericReponseError }))
        .then((data) => {
            if (data.success) {
                LRR.toast({
                    heading: I18N.SaveSuccess,
                    icon: "success",
                });
            } else {
                throw new Error(data.message);
            }
        })
        .catch((error) => LRR.showErrorToast(I18N.SaveError, error));
};

Server.triggerScript = function (namespace) {
    const scriptArg = $(`#${namespace}_ARG`).val();

    if (Server.isScriptRunning) {
        LRR.showErrorToast(I18N.ScriptRunning, I18N.ScriptRunningDesc);
        return;
    }

    Server.isScriptRunning = true;
    $(".script-running").show();
    $(".stdbtn").hide();

    // Save data before triggering script
    Server.saveFormData("#editPluginForm")
        .then(Server.callAPI(`/api/plugins/queue?plugin=${namespace}&arg=${scriptArg}`, "POST", null, I18N.ScriptError,
            (data) => {
                // Check minion job state periodically while we're on this page
                Server.checkJobStatus(
                    data.job,
                    true,
                    (d) => {
                        Server.isScriptRunning = false;
                        $(".script-running").hide();
                        $(".stdbtn").show();

                        if (d.result.success === 1) {
                            LRR.toast({
                                heading: I18N.ScriptResult,
                                text: `<pre>${JSON.stringify(d.result.data, null, 4)}</pre>`,
                                icon: "info",
                                hideAfter: 10000,
                                closeOnClick: false,
                                draggable: false,
                            });
                        } else LRR.showErrorToast(I18N.ScriptResultFail(d.result.error));
                    },
                    () => {
                        Server.isScriptRunning = false;
                        $(".script-running").hide();
                        $(".stdbtn").show();
                    },
                );
            },
        ));
};

Server.cleanTemporaryFolder = function () {
    Server.callAPI("/api/tempfolder", "DELETE", I18N.ClearCache, I18N.ClearCacheError, null);
};

Server.invalidateCache = function () {
    Server.callAPI("/api/search/cache", "DELETE", I18N.CleanedCacheFolder, I18N.ErrorDeletingCache, null);
};

Server.clearAllNewFlags = function () {
    Server.callAPI("/api/database/isnew", "DELETE", I18N.CleanedNewStats, I18N.CleanedError, null);
};

Server.dropDatabase = function () {
    LRR.showPopUp({
        title: I18N.ConfirmVeryDestructive,
        text: I18N.DropDatabaseMsg,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            Server.callAPI("/api/database/drop", "POST", I18N.DropDatabaseConfirm, I18N.GenericReponseError,
                () => {
                    setTimeout(() => { document.location.href = "./"; }, 1500);
                },
            );
        }
    });
};

Server.cleanDatabase = function () {
    Server.callAPI("/api/database/clean", "POST", null, I18N.CleanedError,
        (data) => {
            LRR.toast({
                heading: I18N.CleanDatabaseMsg(data.deleted),
                icon: "success",
                hideAfter: 7000,
            });

            if (data.unlinked > 0) {
                LRR.toast({
                    heading: I18N.DatabaseUnlinkedWarning(data.unlinked),
                    text: I18N.DatabaseUnlinkedDesc,
                    icon: "warning",
                    hideAfter: 16000,
                });
            }
        },
    );
};

Server.regenerateThumbnails = function (force) {
    const forceparam = force ? 1 : 0;
    Server.callAPI(`/api/regen_thumbs?force=${forceparam}`, "POST",
        I18N.RegenThumbnailStarted,
        I18N.GenericReponseError,
        (data) => {
            // Disable the buttons to avoid accidental double-clicks.
            $("#genthumb-button").prop("disabled", true);
            $("#forcethumb-button").prop("disabled", true);

            // Check minion job state periodically while we're on this page
            Server.checkJobStatus(
                data.job,
                true,
                (d) => {
                    $("#genthumb-button").prop("disabled", false);
                    $("#forcethumb-button").prop("disabled", false);
                    LRR.toast({
                        heading: I18N.RegenThumbnailSuccess,
                        text: d.result.errors,
                        icon: "success",
                        hideAfter: 15000,
                        closeOnClick: false,
                        draggable: false,
                    });
                },
                (error) => {
                    $("#genthumb-button").prop("disabled", false);
                    $("#forcethumb-button").prop("disabled", false);
                    LRR.showErrorToast(I18N.MinionCheckError, error);
                },
            );
        },
    );
};

// Adds an archive to a category. Basic implementation to use everywhere.
Server.addArchiveToCategory = function (arcId, catId) {
    Server.callAPI(`/api/categories/${catId}/${arcId}`, "PUT", I18N.AddedToCategory(arcId,catId), I18N.CategoryEditError, null);
};

// Ditto, but for removing.
Server.removeArchiveFromCategory = function (arcId, catId) {
    Server.callAPI(`/api/categories/${catId}/${arcId}`, "DELETE", I18N.RemovedFromCategory(arcId,catId), I18N.CategoryEditError, null);
};

/**
 * Sends a DELETE request for that archive ID,
 * deleting the Redis key and attempting to delete the archive file.
 * @param {*} arcId Archive ID
 * @param {*} callback Callback to execute once the archive is deleted (usually a redirection)
 */
Server.deleteArchive = function (arcId, callback) {
    let endpoint = new LRR.apiURL(`/api/archives/${arcId}`);
    fetch(endpoint, { method: "DELETE" })
        .then((response) => (response.ok ? response.json() : { success: 0, error: I18N.GenericReponseError }))
        .then((data) => {
            if (!data.success) {
                LRR.toast({
                    heading: I18N.MissingFileDeletion,
                    text: I18N.MissingFileDeletionError,
                    icon: "warning",
                    hideAfter: 20000,
                });
                $(".stdbtn").hide();
                $("#goback").show();
            } else {
                LRR.toast({
                    heading: I18N.ArchiveDeleted,
                    text: data.filename,
                    icon: "success",
                    hideAfter: 7000,
                });
                setTimeout(callback, 1500);
            }
        })
        .catch((error) => LRR.showErrorToast(I18N.ArchiveDeletedError, error));
};

/**
 * Sends a UPDATE request for the metadata of the archive ID
 * @param {*} arcId Archive ID
 */
Server.updateTagsFromArchive = function (arcId, tags) {
    const formData = new FormData();
    formData.append("tags", tags);

    Server.callAPIBody(`/api/archives/${arcId}/metadata`, "PUT", formData, I18N.EditMetadataSaved, I18N.EditMetadataError, null);
};

/**
 * Updates local storage with the category ID corresponding to the bookmark icon.
 * @returns a promise containing the category ID if exists or an empty string.
 */
Server.loadBookmarkCategoryId = function () {
    return Server.callAPI("/api/categories/bookmark_link", "GET", null, I18N.GetBookmarkError, (data) => {
        localStorage.setItem("bookmarkCategoryId", data.category_id);
        return data.category_id;
    });
}
