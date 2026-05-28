/**
 * Functions for Generic API calls.
 */
import * as LRR from "mod/common";
import I18N from "i18n";

let isScriptRunning = false;

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
export function callAPI(endpoint, method, successMessage, errorMessage, successCallback) {
    let endpointUrl = new LRR.ApiURL(endpoint);
    return fetch(endpointUrl, { method })
        .then((response) => response.json())
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
}

/**
 *
 * @param {*} endpoint URL endpoint
 * @param {*} method GET/PUT/DELETE/POST
 * @param {*} body Request body
 * @param {*} successMessage Message written in the toast if request succeeded (success = 1)
 * @param {*} errorMessage Header of the error message if request fails (success = 0)
 * @param {*} successCallback called if request succeeded
 * @param {*} contentType content type
 * @returns The result of the callback, or NULL.
 */
export function callAPIBody(endpoint, method, body, successMessage, errorMessage, successCallback, contentType = null) {
    let endpointUrl = new LRR.ApiURL(endpoint);
    const headers = contentType ? { "Content-Type": contentType } : undefined;
    return fetch(endpointUrl, { method, body, headers })
        .then((response) => response.json())
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
}

/**
 * Check the status of a Minion job until it's completed.
 * @param {*} jobId Job ID to check
 * @param {*} useDetail Whether to get full details or the job or not.
 *            This requires the user to be logged in.
 * @param {*} callback Execute a callback on successful job completion.
 * @param {*} failureCallback Execute a callback on unsuccessful job completion.
 * @param {*} progressCallback Execute a callback if the job reports progress. (aka, if there's anything in notes)
 */
export function checkJobStatus(jobId, useDetail, callback, failureCallback, progressCallback = null) {
    let endpoint = new LRR.ApiURL(useDetail ? `/api/minion/${jobId}/detail` : `/api/minion/${jobId}`);
    fetch(endpoint, { method: "GET" })
        .then((response) => response.json())
        .then((data) => {
            if (data.error) throw new Error(data.error);

            if (data.state === "failed") {
                throw new Error(data.result);
            }

            if (data.state === "inactive") {
                // Job isn't even running yet, wait longer
                setTimeout(() => {
                    checkJobStatus(jobId, useDetail, callback, failureCallback, progressCallback);
                }, 5000);
                return;
            }

            if (data.state === "active") {

                if (progressCallback !== null) {
                    progressCallback(data.notes);
                }

                // Job is in progress, check again in a bit
                setTimeout(() => {
                    checkJobStatus(jobId, useDetail, callback, failureCallback, progressCallback);
                }, 1000);
            }

            if (data.state === "finished") {
                // Update UI with info
                callback(data);
            }
        })
        .catch((error) => { LRR.showErrorToast(I18N.MinionCheckError, error); failureCallback(error); });
}

/**
 * POSTs the data of the specified form to the page.
 * This is used for Edit, Config and Plugins.
 * @param {*} formSelector The form to POST
 * @returns the promise object so you can chain more callbacks.
 */
export function saveFormData(formSelector) {
    const postData = new FormData($(formSelector)[0]);

    return fetch(window.location.href, { method: "POST", body: postData })
        .then((response) => response.json())
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
}

export function triggerScript(namespace) {
    const scriptArg = $(`#${namespace}_ARG`).val();

    if (isScriptRunning) {
        LRR.showErrorToast(I18N.ScriptRunning, I18N.ScriptRunningDesc);
        return;
    }

    isScriptRunning = true;
    $(".script-running").show();
    $(".stdbtn").hide();

    // Save data before triggering script
    saveFormData("#editPluginForm")
        .then(callAPI(`/api/plugins/queue?plugin=${namespace}&arg=${scriptArg}`, "POST", null, I18N.ScriptError,
            (data) => {
                // Check minion job state periodically while we're on this page
                checkJobStatus(
                    data.job,
                    true,
                    (d) => {
                        isScriptRunning = false;
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
                        isScriptRunning = false;
                        $(".script-running").hide();
                        $(".stdbtn").show();
                    },
                );
            },
        ));
}

export function cleanTemporaryFolder() {
    return callAPI("/api/tempfolder", "DELETE", I18N.ClearCache, I18N.ClearCacheError, null);
}

export function invalidateCache() {
    return callAPI("/api/search/cache", "DELETE", I18N.CleanedCacheFolder, I18N.ErrorDeletingCache, null);
}

export function clearAllNewFlags() {
    return callAPI("/api/database/isnew", "DELETE", I18N.CleanedNewStats, I18N.CleanedError, null);
}

export function dropDatabase() {
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
            callAPI("/api/database/drop", "POST", I18N.DropDatabaseConfirm, I18N.GenericReponseError,
                () => {
                    setTimeout(() => { document.location.href = "./"; }, 1500);
                },
            );
        }
    });
}

export function cleanDatabase() {
    return callAPI("/api/database/clean", "POST", null, I18N.CleanedError,
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
}

/**
 * @param {boolean} force
 * @returns {Promise<any>}
 */
export function regenerateThumbnails(force) {
    const forceparam = force ? 1 : 0;
    return callAPI(`/api/regen_thumbs?force=${forceparam}`, "POST",
        I18N.RegenThumbnailStarted,
        I18N.GenericReponseError,
        (data) => {
            // Disable the buttons to avoid accidental double-clicks.
            $("#genthumb-button").prop("disabled", true);
            $("#forcethumb-button").prop("disabled", true);

            // Check minion job state periodically while we're on this page
            checkJobStatus(
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
}

// Adds an archive to a category. Basic implementation to use everywhere.
export function addArchiveToCategory(arcId, catId) {
    return callAPI(`/api/categories/${catId}/${arcId}`, "PUT", I18N.AddedToCategory(arcId, catId), I18N.CategoryEditError, null);
}

// Ditto, but for removing.
export function removeArchiveFromCategory(arcId, catId) {
    return callAPI(`/api/categories/${catId}/${arcId}`, "DELETE", I18N.RemovedFromCategory(arcId, catId), I18N.CategoryEditError, null);
}

/**
 * Sends a DELETE request for that archive ID,
 * deleting the Redis key and attempting to delete the archive file.
 * @param {string} arcId Archive ID
 * @param {*} callback Callback to execute once the archive is deleted (usually a redirection)
 */
export function deleteArchive(arcId, callback) {
    let endpoint = new LRR.ApiURL(`/api/archives/${arcId}`);
    return fetch(endpoint, { method: "DELETE" })
        .then((response) => response.json())
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
}

/**
 * Deletes a Tankoubon by ID. The archives remain in the library.
 * @param {string} id Tankoubon ID
 * @param {Function} callback Called after successful deletion
 */
export function deleteTankoubon(id, callback) {
    return callAPI(`/api/tankoubons/${id}`, "DELETE", I18N.TankoubonDeleted, I18N.TankoubonDeleteError,
        () => { setTimeout(callback, 1500); }
    );
}

/**
 * Sends a UPDATE request for the metadata of the archive ID
 * @param {string} arcId Archive ID
 */
export function updateTagsFromArchive(arcId, tags) {
    const formData = new FormData();
    formData.append("tags", tags);

    return callAPIBody(`/api/archives/${arcId}/metadata`, "PUT", formData, I18N.EditMetadataSaved, I18N.EditMetadataError, null);
}

/**
 * Updates local storage with the category ID corresponding to the bookmark icon.
 * @returns a promise containing the category ID if exists or an empty string.
 */
export function loadBookmarkCategoryId() {
    return callAPI("/api/categories/bookmark_link", "GET", null, I18N.GetBookmarkError, (data) => {
        localStorage.setItem("bookmarkCategoryId", data.category_id);
        return data.category_id;
    });
}

/**
 * Update server-side read progression.
 *
 * @param {*} id Archive ID
 * @param {number} currentPage Page the user navigated to
 */
export function updateServerSideProgress(id, currentPage) {

    let endpointUrl = id.startsWith("TANK_") ? 
        new LRR.ApiURL(`/api/tankoubons/${id}/progress/${currentPage}`) : 
        new LRR.ApiURL(`/api/archives/${id}/progress/${currentPage}`);

    return fetch(endpointUrl, { method: "PUT" })
        .then((response) => (response.ok ? {code: response.status, data: response.json()} : { code: response.status, data: {success: 0, error: I18N.GenericReponseError} }))
        .then((response) => {
            const { code, data } = response;
            if (code === 423) {
                // Rapid calls to the API endpoint can return a 423 due to a redis lock
                return;
            }
            if (Object.prototype.hasOwnProperty.call(data, "success") && !data.success) {
                throw new Error(data.error);
            } else {
                let message = null;
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

                return null;
            }
        })
        .catch((error) => LRR.showErrorToast(I18N.ReaderErrorProgress, error));
}
