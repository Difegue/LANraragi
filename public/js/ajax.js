//Scripting for Generic API calls.

// Show a generic error toast with a given header and message.
function showErrorToast(header, error) {
	$.toast({
		showHideTransition: 'slide',
		position: 'top-left',
		loader: false,
		heading: header,
		text: error,
		hideAfter: false,
		icon: 'error'
	});
}

//Call that shows a popup to the user on success/failure. 
// Endpoint: URL endpoint
// Method: GET/PUT/DELETE/POST
// successMessage: Message written in the toast if request succeeded (success = 1)
// errorMessage: Header of the error message if request fails (success = 0)
// callback: Func called if request succeeded
function genericAPICall(endpoint, method, successMessage, errorMessage, callback) {

	fetch(endpoint, { method: method })
		.then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
		.then((data) => {

			if (data.success) {
				if (successMessage !== null)
					$.toast({
						showHideTransition: 'slide',
						position: 'top-left',
						loader: false,
						heading: successMessage,
						icon: 'success'
					});

				if (callback !== null)
					callback(data);

			} else {
				throw new Error(data.error);
			}
		})
		.catch(error => showErrorToast(errorMessage, error));
}

let isScriptRunning = false;
function triggerScript(namespace) {

	const scriptArg = $("#" + namespace + "_ARG").val();

	if (isScriptRunning) {
		showErrorToast("A script is already running.", "Please wait for it to terminate.");
		return;
	}
	isScriptRunning = true;

	// Save data before triggering script
	$.ajax(
		{
			url: $('#editPluginForm').attr("action"),
			type: "POST",
			data: $('#editPluginForm').serializeArray(),
			success: function (data, textStatus, jqXHR) {
				if (data.success)
					genericAPICall(`../api/plugin/use?plugin=${namespace}&arg=${scriptArg}`, "POST", null, "Error while executing Script :",
						function (r) {
							$.toast({
								showHideTransition: 'slide',
								position: 'top-left',
								loader: false,
								heading: "Script result",
								text: "<pre>" + JSON.stringify(r.data, null, 4) + "</pre>",
								hideAfter: false,
								icon: 'info'
							});
							isScriptRunning = false;
						});
				else {
					showErrorToast("Saving unsuccessful", data.message);
					isScriptRunning = false;
				}
			},
			error: function (jqXHR, textStatus, errorThrown) {
				showErrorToast("Error while saving", errorThrown);
				isScriptRunning = false;
			}
		});
}

function cleanTempFldr() {
	genericAPICall("api/tempfolder", "DELETE", "Temporary Folder Cleaned!", "Error while cleaning Temporary Folder :",
		function (data) {
			$("#tempsize").html(data.newsize);
		});
}

function invalidateCache() {
	genericAPICall("api/search/cache", "DELETE", "Threw away the Search Cache!", "Error while deleting cache! Check Logs.", null);
}

function clearNew(id) {
	genericAPICall("api/clear_new?id=" + id, "GET", null, "Error clearing new flag! Check Logs.", null);
}

function clearAllNew() {
	genericAPICall("api/database/isnew", "DELETE", "All archives are no longer new!", "Error while clearing flags! Check Logs.", null);
}

function dropDatabase() {
	if (confirm('Danger! Are you *sure* you want to do this?')) {
		genericAPICall("api/database/drop", "POST", "Sayonara! Redirecting you...", "Error while resetting the database? Check Logs.",
			function (data) {
				setTimeout("location.href = './';", 1500);
			});
	}
}

function cleanDatabase() {
	genericAPICall("api/database/clean", "POST", null, "Error while cleaning the database! Check Logs.",
		function (data) {
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left',
				loader: false,
				heading: "Successfully cleaned the database and removed " + data.deleted + " entries!",
				icon: 'success'
			});

			if (data.unlinked > 0) {
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: data.unlinked + " other entries have been unlinked from the database and will be deleted on the next cleanup! <br>Do a backup now if some files disappeared from your archive index.",
					hideAfter: false,
					icon: 'warning'
				});
			}
		});
}

function rebootShinobu() {
	$("#restart-button").prop("disabled", true);
	genericAPICall("api/shinobu/restart", "POST", "Background Worker restarted!", "Error while restarting Worker:",
		function (data) {
			$("#restart-button").prop("disabled", false);
			shinobuStatus();
		});
}

//Update the status of the background worker.
function shinobuStatus() {

	genericAPICall("api/shinobu", "GET", null, "Error while querying Shinobu status:",
		function (data) {
			if (data.is_alive) {
				$("#shinobu-ok").show();
				$("#shinobu-ko").hide();
			} else {
				$("#shinobu-ko").show();
				$("#shinobu-ok").hide();
			}
			$("#pid").html(data.pid);

		});
}

//saveFormData()
//POSTs the data of the specified form to the page.
//This is used for Edit, Config and Plugins.
function saveFormData(formSelector) {

	var postData = $(formSelector).serializeArray()
	var formURL = $(formSelector).attr("action")

	$.ajax(
		{
			url: formURL,
			type: "POST",
			data: postData,
			success: function (data, textStatus, jqXHR) {
				if (data.success)
					$.toast({
						showHideTransition: 'slide',
						position: 'top-left',
						loader: false,
						heading: 'Saved Successfully!',
						icon: 'success'
					})
				else
					showErrorToast("Saving unsuccessful", data.message);
			},
			error: function (jqXHR, textStatus, errorThrown) {
				showErrorToast("Error while saving", errorThrown);
			}
		});
}

//deleteArchive(id)
//Sends a DELETE request for that archive ID, deleting the Redis key and attempting to delete the archive file.
function deleteArchive(arcId) {

	fetch("edit?id=" + arcId, { method: "DELETE" })
		.then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
		.then((data) => {

			if (data.success == "0") {
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: "Couldn't delete archive file. <br> (Maybe it has already been deleted beforehand?)",
					text: 'Archive metadata has been deleted properly. <br> Please delete the file manually before returning to Library View.',
					hideAfter: false,
					icon: 'warning'
				});
				$(".stdbtn").hide();
				$("#goback").show();
			}
			else {
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: 'Archive successfully deleted. Redirecting you ...',
					text: 'File name : ' + data.success,
					icon: 'success'
				});
				setTimeout("location.href = './';", 1500);
			}
		})
		.catch(error => showErrorToast("Error while deleting archive", error));

}
