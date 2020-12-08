// Scripting for the Upload page.

var processingArchives = 0;
var completedArchives = 0;
var failedArchives = 0;
var totalUploads = 0;

// Handle updating the upload counters.
function updateUploadCounters() {

    $("#progressCount").html(`🤔 Processing: ${processingArchives} 🙌 Completed: ${completedArchives} 👹 Failed: ${failedArchives}`);

    var icon = (completedArchives == totalUploads) ? "fas fa-check-circle" :
        failedArchives > 0 ? "fas fa-exclamation-circle" :
            "fa fa-spinner fa-spin";

    $("#progressTotal").html(`<i class="${icon}"></i> Total:${completedArchives + failedArchives}/${totalUploads}`);

    // At the end of the upload job, dump the search cache!
    if (processingArchives === 0)
        invalidateCache();
}

// Handle a completed job from minion. Update the line in upload results with the title, ID, message.
function handleCompletedUpload(jobID, d) {

    $(`#${jobID}-name`).html(d.result.title);

    if (d.result.id) {
        $(`#${jobID}-name`).attr("href", `reader?id=${d.result.id}`);
        $(`#${jobID}-link`).attr("href", `edit?id=${d.result.id}`);
    }

    if (d.result.success) {
        $(`#${jobID}-link`).html("Click here to edit metadata.<br>(" + d.result.message + ")")
        $(`#${jobID}-icon`).attr("class", "fa fa-check-circle");
        completedArchives++;
    } else {
        $(`#${jobID}-link`).html("Error while processing archive.<br>(" + d.result.message + ")");
        $(`#${jobID}-icon`).attr("class", "fa fa-exclamation-circle");
        failedArchives++;
    }

    processingArchives--;
    updateUploadCounters();

    const categoryID = document.getElementById("category").value;
    if (categoryID !== "") {
        console.log(`Adding ${d.result.id} to category ${categoryID}`)
        addArchiveToCategory(d.result.id, categoryID);
    }
}

function handleFailedUpload(jobID, d) {

    $(`#${jobID}-link`).html("Error while processing file.<br>(" + d + ")");
    $(`#${jobID}-icon`).attr("class", "fa fa-exclamation-circle");

    failedArchives++;
    processingArchives--;
    updateUploadCounters();
}

// Send URLs to the Download API and add a checkJobStatus to track its progress.
function downloadUrl() {

    // One fetch job per non-empty line of the form
    $('#urlForm').val().split(/\r|\n/).forEach(url => {

        if (url === "") return;

        let formData = new FormData();
        formData.append('url', url);

        fetch("/api/download_url", {
            method: "POST",
            body: formData
        })
            .then(response => response.json())
            .then((data) => {
                if (data.success) {
                    result = `<tr><td style="max-width:200px; overflow:hidden; text-overflow:ellipsis;">
                                    <a href="#" id="${data.job}-name" title="${data.url}">${data.url}</a>
                                </td>
                                <td><i id="${data.job}-icon" class='fa fa-spinner fa-spin' style='margin-left:20px; margin-right: 10px;'></i>
                                <a href="#" id="${data.job}-link">Downloading file... (Job #${data.job})</a>
                                </td>
                            </tr>`;

                    $('#files').append(result);

                    totalUploads++;
                    processingArchives++;
                    updateUploadCounters();

                    // Check minion job state periodically to update the result 
                    checkJobStatus(data.job,
                        (d) => handleCompletedUpload(data.job, d),
                        (error) => handleFailedUpload(data.job, error));
                } else {
                    throw new Error(data.message);
                }
            })
            .catch(error => showErrorToast("Error while adding download job", error));

    });
}

// Set up jqueryfileupload.
function initUpload() {

    $('#fileupload').fileupload({
        dataType: 'json',
        done: function (e, data) {

            const categoryID = document.getElementById("category").value;

            if (data.result.success == 0)
                result = `<tr><td>${data.result.name}</td>
                              <td><i class='fa fa-exclamation-circle' style='margin-left:20px; margin-right: 10px; color: red'></i>${data.result.error}</td>
                          </tr>`;
            else
                result = `<tr><td style="max-width:200px; overflow:hidden; text-overflow:ellipsis;">
                                <a href="#" id="${data.result.job}-name" title="${data.result.name}">${data.result.name}</a>
                              </td>
                              <td><i id="${data.result.job}-icon" class='fa fa-spinner fa-spin' style='margin-left:20px; margin-right: 10px;'></i>
                                <a href="#" id="${data.result.job}-link">Processing file... (Job #${data.result.job})</a>
                              </td>
                          </tr>`;

            $('#progress .bar').css('width', '0%');
            $('#files').append(result);

            totalUploads++;
            processingArchives++;
            updateUploadCounters();

            // Check minion job state periodically to update the result 
            checkJobStatus(data.result.job,
                (d) => handleCompletedUpload(data.result.job, d),
                (error) => handleFailedUpload(data.result.job, error));
        },

        fail: function (e, data) {
            result = `<tr><td>${data.result.name}</td>
                              <td><i class='fa fa-exclamation-circle' style='margin-left:20px; margin-right: 10px; color: red'></i>${data.errorThrown}</td>
                          </tr>`;
            $('#progress .bar').css('width', '0%');
            $('#files').append(result);

            totalUploads++;
            failedArchives++;
            updateUploadCounters();
        },

        progressall: function (e, data) {
            var progress = parseInt(data.loaded / data.total * 100, 10);
            $('#progress .bar').css('width', progress + '%');
        }

    });

}