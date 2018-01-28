/*
////// REGULAR INDEX PAGE FUNCTIONS
*/

//Switch view on index and saves the value in the user's localStorage. The DataTables callbacks adapt automatically.
//0 = List view
//1 = Thumbnail view
function switch_index_view() {

  if (localStorage.indexViewMode == 1)
  {
    localStorage.indexViewMode = 0;
    $("#viewbtn").val("Switch to Thumbnail View");
  }
  else
  {
    localStorage.indexViewMode = 1;
    $("#viewbtn").val("Switch to List View");
  }

  //Redraw the table yo
  arcTable.draw();

}

function checkVersion(currentVersion) {
	//Check the github API to see if an update was released. If so, flash another friendly notification inviting the user to check it out
	var githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";
	var currentVersion = "[% version %]" ;
	var latestVersion;

	$.getJSON( githubAPI).done(function( data ) {
			latestVersion = data.tag_name;
			//update nag is disabled if the current version contains the DEV string 
			if (latestVersion != currentVersion && currentVersion.indexOf("DEV") == -1) {

				$.toast({
				heading: 'A new version of LANraragi ('+ latestVersion +') is available !',
			    text: '<a href="'+data.html_url+'">Hit it !</a> It\'s probably good. 👌',
			    hideAfter: false,
			    position: 'top-left', 
			    icon: 'info'
				});

			}
	});
}

/*
////// NEW ARCHIVE PAGE FUNCTIONS
*/

//Executed on load of the archive index in new archive mode to organize and fire the ajax calls while informing the user.
function initNewArchiveRequests(newArchiveJSON)
{
	//end init thumbnails
	hidetrail();
	document.onmouseover=followmouse;

	//launch hourglass animation
	hourglassAnimationCycle();

	archives = newArchiveJSON.length;
	completedArchives = 0;

	//parse new archive json and fire ajax calls
	for (var i = 0; i < archives; i++) {

		archiveToAdd = newArchiveJSON[i];

		//Ajax call for getting and setting the tags
		$.ajax(
			{
				url : "api/add_archive",
				type: "POST",
				data: { id: archiveToAdd.arcid, arc_path: archiveToAdd.file },
				success:function(data, textStatus, jqXHR) 
				{
					if (data.status === 1)
					{ 
						completedArchives++;

						//$("#status").html("Added "+archiveToAdd.file+ " successfully.");
						$("#counter").html(completedArchives + " / " + archives);

						if (completedArchives === archives) {
							location.reload(); 
						}
					}
					else
					{
						$.toast({
						showHideTransition: 'slide',
						position: 'top-left', 
						loader: false, 
						hideAfter: false,
					    heading: 'Error while adding archive '+archiveToAdd.file+' to the database :',
					    text: data.error,
					    icon: 'error'
						});
					}
					

				},
				error: function(jqXHR, textStatus, errorThrown) 
				{
					$.toast({
						showHideTransition: 'slide',
						position: 'top-left', 
						loader: false, 
						hideAfter: false,
					    heading: 'Error while adding archive '+archiveToAdd.file+' to the database :',
					    text: errorThrown,
					    icon: 'error'
					});
				}
			});
	}

}

//Animates the hourglass on the new archive treatment page.
function hourglassAnimationCycle() 
{
	var icon = $('#icon');
	setTimeout(function(){ 
		icon.attr("class",'fa fa-4x fa-hourglass-half');
		setTimeout(function(){ 
			icon.attr("class",'fa fa-4x fa-hourglass-end');
			setTimeout(function(){ 
				icon.attr("class",'fa fa-4x fa-hourglass-end spin');
				setTimeout(function(){ 
					icon.attr("class",'fa fa-4x fa-hourglass-start');
					hourglassAnimationCycle();
					}, 1500);
				}, 500);
			}, 500);
		}, 500);
}
