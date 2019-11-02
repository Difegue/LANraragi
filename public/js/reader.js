//functions to navigate in reader with the keyboard.
//also handles the thumbnail archive explorer.

function moveSomething(e) {

	switch (e.keyCode) {
		case 37:
			// left key pressed
			advancePage(-1);
			break;
		case 32:
			// spacebar pressed
			if ((window.innerHeight + window.scrollY) >= document.body.offsetHeight) {
				advancePage(1);
			}
			break;
		case 39:
			// right key pressed
			advancePage(1);
			break;
		case 17:
			// Ctrl key pressed
			openOverlay();
			break;
	}
}

document.addEventListener("keyup", moveSomething, false);

function toastHelpReader() {

	$.toast().reset('all');

	$.toast({
		heading: '阅读器帮助',
		text: '你可以使用 : <ul><li> 箭头图标</li> <li>键盘上的方向键（和空格键）</li> <li> 触摸屏幕的左右两侧</li></ul>来进行翻页, 点击"向下箭头"图标来返回主页<br> 按下"CTRL"显示画册缩略图',
		hideAfter: false,
		position: 'top-left',
		icon: 'info'
	});
}

function updateMetadata() {

	//remove overlay
	loaded = true;
	$("#i3").removeClass("loading");

	filename = $("#img").get(0).src.replace(/^.*[\\\/]/, '');
	w = $("#img").get(0).naturalWidth;
	h = $("#img").get(0).naturalHeight;
	size = "UNKNOWN"

	if (showingSinglePage) {

		//HEAD request to get filesize
		xhr = $.ajax({
			url: pages.pages[currentPage],
			type: 'HEAD',
			success: function () {
				size = parseInt(xhr.getResponseHeader('Content-Length') / 1024, 10);
			}
		}).done(function (data) {

			metadataString = filename + " :: " + w + " x " + h + " :: " + size + " KB";

			$('.file-info').each(function () {
				$(this).html(metadataString);
			});

			updateImageMap();
		});

	} else {

		metadataString = "Double-Page View :: " + w + " x " + h;

		$('.file-info').each(function () {
			$(this).html(metadataString);
		});

		updateImageMap();

	}

}

function updateImageMap() {

	//update imagemap with the w/h parameters we obtained
	mapWidth = $("#img").get(0).width / 2;
	mapHeight = $("#img").get(0).height;
	$("#leftmap").attr("coords", "0,0," + mapWidth + "," + mapHeight);
	$("#rightmap").attr("coords", (mapWidth + 1) + ",0," + w + "," + mapHeight);
}

function goToPage(page) {

	previousPage = currentPage;

	if (page < 0)
		currentPage = 0;
	else if (page >= pageNumber)
		currentPage = pageNumber - 1;
	else currentPage = page;

	//if double-page view is enabled(and the current page isn't the first or the last)
	if (localStorage.doublepage === 'true' && currentPage > 0 && currentPage < pageNumber - 1) {
		//composite an image and use that as the source
		img1 = loadImage(pages.pages[currentPage], canvasCallback);
		img2 = loadImage(pages.pages[currentPage + 1], canvasCallback);
		//We can also free the maxwidth since we usually have twice the pages
		$(".sni").attr("style", "max-width: 90%");
	}
	else {
		//in single view, just use the source URLs as is
		$("#img").attr("src", pages.pages[currentPage]);
		showingSinglePage = true;
		$(".sni").attr("style", "");
	}

	//scale to view simply forces image height at 90vh (90% of viewport height)
	if (localStorage.scaletoview === 'true')
		$("#img").attr("style", "max-height: 90vh;");
	else
		$("#img").attr("style", "");

	//hide/show toplevel nav depending on the pref
	if (localStorage.hidetop === 'true') {
		$("#i2").attr("style", "display:none");
		$("div.sni h1").attr("style", "display:none");

		//Since the topnav is gone, we can afford to make the image a bit bigger.
		if (localStorage.scaletoview === 'true')
			$("#img").attr("style", "max-height: 98vh;");
	}
	else {
		$("#i2").attr("style", "");
		$("div.sni h1").attr("style", "");
	}

	//update numbers
	$('.current-page').each(function () {
		$(this).html(parseInt(currentPage) + 1);
	});

	$('.max-page').each(function () {
		$(this).html(pageNumber);
	});

	loaded = false;

	//display overlay if it takes too long to load a page
	setTimeout(function () {
		if (!loaded)
			$("#i3").addClass("loading");
	}, 500);

	//update full image link
	$("#imgLink").attr("href", pages.pages[currentPage]);

	//store page number and total pages in localStorage
	localStorage.setItem(id + "-reader", currentPage);
	localStorage.setItem(id + "-totalPages", pageNumber);

	//scroll to top
	window.scrollTo(0, 0);
}

function initArchivePageOverlay() {

	//For each link in the pages array, craft a div and jam it in the overlay.
	for (index = 0; index < pages.pages.length; ++index) {

		thumbnail = "<div class='id3' style='display: inline-block; cursor: pointer'>" +
			"<a onclick='goToPage(" + index + "); closeOverlay()'>" +
			"<span class='page-number'>Page " + (index + 1) + "</span>" +
			"<img src='" + pages.pages[index] + "' /></a>" +
			"</div>";

		$("#archivePagesOverlay").append(thumbnail);
	}
	$("#archivePagesOverlay").attr("loaded", "true");
}

function initSettingsOverlay() {

	if (localStorage.readorder === 'true')
		$("#readorder").prop("checked", true);

	if (localStorage.doublepage === 'true')
		$("#doublepage").prop("checked", true);

	if (localStorage.scaletoview === 'true')
		$("#scaletoview").prop("checked", true);

	if (localStorage.hidetop === 'true')
		$("#hidetop").prop("checked", true);

	if (localStorage.nobookmark === 'true')
		$("#nobookmark").prop("checked", true);	

}

function saveSettings() {
	localStorage.readorder = $("#readorder").prop("checked");
	localStorage.doublepage = $("#doublepage").prop("checked");
	localStorage.scaletoview = $("#scaletoview").prop("checked");
	localStorage.hidetop = $("#hidetop").prop("checked");
	localStorage.nobookmark = $("#nobookmark").prop("checked");

	closeOverlay();
	goToPage(currentPage);
}

function openOverlay() {
	if ($("#archivePagesOverlay").attr("loaded") === "false")
		initArchivePageOverlay();

	$('#overlay-shade').fadeTo(150, 0.6, function () {
		$('#archivePagesOverlay').css('display', 'block');
	});
}

function openSettings() {
	$('#overlay-shade').fadeTo(150, 0.6, function () {
		$('#settingsOverlay').css('display', 'block');
	});
}

function closeOverlay() {
	$('#overlay-shade').fadeOut(300);
	$('.base-overlay').css('display', 'none');
}

function confirmThumbnailReset(id) {

	if (confirm("Are you sure you want to regenerate the thumbnail for this archive?")) {

		$.get("./reader?id=" + id + "&reload_thumbnail=1").done(function () {
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left',
				loader: false,
				heading: 'Thumbnail Regenerated.',
				icon: 'success'
			});
		});
	}
}

function canvasCallback() {
	imagesLoaded += 1;

	if (imagesLoaded == 2) {

		//If w > h on one of the images, set canvasdata to the first image only
		if (img1.naturalWidth > img1.naturalHeight || img2.naturalWidth > img2.naturalHeight) {

			//Depending on whether we were going forward or backward, display img1 or img2
			if (previousPage > currentPage)
				$("#img").attr("src", img2.src);
			else
				$("#img").attr("src", img1.src);

			showingSinglePage = true;
			imagesLoaded = 0;
			return;
		}

		//Double page confirmed
		showingSinglePage = false;

		//Create an adequately-sized canvas
		var canvas = $("#dpcanvas")[0];
		canvas.width = img1.naturalWidth + img2.naturalWidth;
		canvas.height = Math.max(img1.naturalHeight, img2.naturalHeight);

		//Draw both images on it
		ctx = canvas.getContext("2d");
		if (localStorage.readorder === 'true') {
			ctx.drawImage(img2, 0, 0);
			ctx.drawImage(img1, img2.naturalWidth + 1, 0);
		} else {
			ctx.drawImage(img1, 0, 0);
			ctx.drawImage(img2, img1.naturalWidth + 1, 0);
		}

		imagesLoaded = 0;
		$("#img").attr("src", canvas.toDataURL('image/jpeg'));

	}
}

function loadImage(src, onload) {
	var img = new Image();

	img.onload = onload;
	img.src = src;

	return img;
}

// Go forward or backward in pages. Pass -1 for left, +1 for right.
function advancePage(pageModifier) {

	if (localStorage.doublepage === 'true' && showingSinglePage == false)
		pageModifier = pageModifier * 2;

	if (localStorage.readorder === 'true')
		pageModifier = -pageModifier;

	goToPage(currentPage + pageModifier);
}

function goFirst() {
	if (localStorage.readorder === 'true')
		goToPage(pageNumber - 1);
	else
		goToPage(0);
}

function goLast() {
	if (localStorage.readorder === 'true')
		goToPage(0);
	else
		goToPage(pageNumber - 1);
}
