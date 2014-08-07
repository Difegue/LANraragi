//functions to navigate in reader.pl with the keyboard.

function moveSomething(e) {

switch (e.keyCode) {
	case 37:
	// left key pressed
	window.location.href = document.getElementById("prev").getAttribute("href");
	break;
	case 32:
	// spacebar pressed
	window.location.href = document.getElementById("next").getAttribute("href");
	break;
	case 39:
	// right key pressed
	window.location.href = document.getElementById("next").getAttribute("href");
	break;
	}	
}

document.addEventListener("keyup", moveSomething, false);