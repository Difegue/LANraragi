//functions to navigate in reader.pl with the keyboard.
//also handles the thumbnail archive explorer.

function moveSomething(e) {

switch (e.keyCode) {
	case 37:
	// left key pressed
	goLeft();
	break;
	case 32:
	// spacebar pressed
	goToPage(currentPage+1);
	break;
	case 39:
	// right key pressed
	goRight();
	break;
	}	
}

document.addEventListener("keyup", moveSomething, false);

function toastHelpReader(){

	$.toast().reset('all');

	$.toast({
	heading: 'Navigation Help',
    text: 'You can navigate between pages using : <ul><li> The arrow icons</li> <li>Your keyboard arrows</li> <li> Touching the left/right side of the image.</li></ul><br> To return to the archive index, touch the arrow pointing down.',
    hideAfter: false,
    position: 'top-left', 
    icon: 'info'
	});
}

function initArchivePageOverlay(){

	

}

function showArchivePages(){


}

function updateMetadata(){

	//remove overlay
	loaded = true;
	$("#i3").removeClass("loading");

	filename = $("#img").get(0).src.replace(/^.*[\\\/]/, '');
	w = $("#img").get(0).naturalWidth;
	h = $("#img").get(0).naturalHeight;
	size = "UNKNOWN"

	//HEAD request to get filesize
	xhr = $.ajax({
		url : pages.pages[currentPage],
		type : 'HEAD',
		success : function(){
		    size = parseInt(xhr.getResponseHeader('Content-Length') / 1024, 10);
		}
	}).done(function( data ) {

		metadataString = filename + " :: " + w + " x " + h + " :: " + size + " KB";
		
		$('.file-info').each(function(){
			$(this).html(metadataString);
		});

		updateImageMap();
	});

}

function updateImageMap(){

	//update imagemap with the w/h parameters we obtained
	mapWidth = $("#img").get(0).width/2;
	mapHeight = $("#img").get(0).height;
	$("#leftmap").attr("coords","0,0,"+mapWidth+","+mapHeight);
	$("#rightmap").attr("coords",(mapWidth+1)+",0,"+w+","+mapHeight);
}

function goToPage(page){

	if (page < 0)
		currentPage = 0;
	else if (page >= pageNumber)
		currentPage = pageNumber-1;
	else currentPage = page;

	//update image
	$("#img").attr("src",pages.pages[currentPage]);

	//update numbers
	$('.current-page').each(function(){
		$(this).html(parseInt(currentPage)+1);
	});

	$('.max-page').each(function(){
		$(this).html(pageNumber);
	});

	loaded = false;

	//display overlay if it takes too long to load a page
	setTimeout(function(){
		if (!loaded)
			$("#i3").addClass("loading");
	},500);

	//update full image link
	$("#imgLink").attr("href",pages.pages[currentPage]);

	//store page number in localStorage
	localStorage.setItem(id+"-reader", currentPage);

}