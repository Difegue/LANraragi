//functions to navigate in reader.pl with the keyboard.

function moveSomething(e) {

switch (e.keyCode) {
	case 37:
	// left key pressed
	window.location.href = document.getElementById("left").getAttribute("href");
	break;
	case 32:
	// spacebar pressed
	window.location.href = document.getElementById("next").getAttribute("href");
	break;
	case 39:
	// right key pressed
	window.location.href = document.getElementById("right").getAttribute("href");
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