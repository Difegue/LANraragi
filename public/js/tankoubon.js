/**
 * Non-DataTables Index functions.
 * (The split is there to permit easier switch if we ever yeet datatables from the main UI)
 */
const Index = {};
Index.selectedCategory = "";
Index.awesomplete = {};
Index.carouselInitialized = false;
Index.swiper = {};
Index.serverVersion = "";
Index.debugMode = false;
Index.isProgressLocal = true;
Index.pageSize = 100;
Index.carouselMap = new Map();
Index.baserg;

/**
 * Initialize the Archive Index.
 */
Index.initializeAll = function () {
    $(document).on("click.open-carousel", ".collapsible-title", Index.toggleCarousel);
    $(document).on("click.submit-list", "#submit-list", Index.createList);
    $(document).on("click.add-list", "#add-list", Index.initializeModal);
    //$(document).on("click.reload-carousel", "#reload-carousel", Index.updateCarousel);

    //Index.updateCarousel();

    // Initialize carousel mode menu
    $.contextMenu({
        selector: "#carousel-mode-menu",
        trigger: "left",
        build: () => ({
            callback(key) {
                console.log(key);
                var originalElement = $('.context-menu-active');
                var id = originalElement.parent().parent().parent()[0].id
                switch (key) {
                case "edit":
                    Index.editList(id);
                    break;
                case "delete":
                    Index.removeList(id);
                    break;
                }
            },
            items: {
                edit: { name: "Edit", icon: "fas fa-random" },
                delete: { name: "Delete", icon: "fas fa-envelope-open-text" },
            },
        }),
    });

    Index.initializeGroups();
    //Index.initializeModal();
};

Index.initializeModal = function () {
    // Get the modal
    var modal = document.getElementById("addl-modal");

    document.getElementById("create-list_form").reset();
    modal.style.display = "block";

    // When the user clicks anywhere outside of the modal, close it
    window.onclick = function(event) {
      if (event.target == modal) {
        modal.style.display = "none";
      }
    }
}

Index.initializeGroups = function () {
    //$("#rg_1").remove();
    Index.baserg = $("#rg_1");
    let endpoint;
    endpoint = `/api/tankoubon`;
    Server.callAPI(endpoint, "GET", null, "Error getting carousel data!",
        (results) => {
            console.log(results);
            var list;
            results.result.forEach(element => {
                list = Index.baserg.clone(true);
                Index.carouselMap.set(element.id, false);
                list.attr("id", element.id);
                list.find("#carousel-title").text(element.name);
                list.appendTo("#list_rg");
            });
            $("#rg_1").remove();
        },
    );
}

Index.initializeSortableList = function () {
    var target = document.getElementById("sortlist");
    // (A) SET CSS + GET ALL LIST ITEMS
    target.classList.add("slist");
    let items = target.getElementsByTagName("li"), current = null;

    // (B) MAKE ITEMS DRAGGABLE + SORTABLE
    for (let i of items) {
        // (B1) ATTACH DRAGGABLE
        i.draggable = true;

        // (B2) DRAG START - YELLOW HIGHLIGHT DROPZONES
        i.ondragstart = e => {
          current = i;
          for (let it of items) {
            if (it != current) { it.classList.add("hint"); }
          }
        };

        // (B3) DRAG ENTER - RED HIGHLIGHT DROPZONE
        i.ondragenter = e => {
          if (i != current) { i.classList.add("active"); }
        };

        // (B4) DRAG LEAVE - REMOVE RED HIGHLIGHT
        i.ondragleave = () => i.classList.remove("active");

        // (B5) DRAG END - REMOVE ALL HIGHLIGHTS
        i.ondragend = () => { for (let it of items) {
            it.classList.remove("hint");
            it.classList.remove("active");
        }};

        // (B6) DRAG OVER - PREVENT THE DEFAULT "DROP", SO WE CAN DO OUR OWN
        i.ondragover = e => e.preventDefault();

        // (B7) ON DROP - DO SOMETHING
        i.ondrop = e => {
          e.preventDefault();
          if (i != current) {
            let currentpos = 0, droppedpos = 0;
            for (let it=0; it<items.length; it++) {
              if (current == items[it]) { currentpos = it; }
              if (i == items[it]) { droppedpos = it; }
            }
            if (currentpos < droppedpos) {
              i.parentNode.insertBefore(current, i.nextSibling);
            } else {
              i.parentNode.insertBefore(current, i);
            }
          }
        };
    }
}

Index.toggleCarousel = function (e, updateLocalStorage = true) {
    var id = $(this).parent().parent()[0].id;

    if (!Index.carouselMap.get(id)) {
        Index.carouselMap.set(id, true);
        //$("#reload-carousel").show();

        Index.swiper = new Swiper("#"+id+" .index-carousel-container", {
            breakpoints: (() => {
                const breakpoints = {
                    0: { // ensure every device have at least 1 slide
                        slidesPerView: 1,
                    },
                };
                // virtual Slides doesn't work with slidesPerView: 'auto'
                // the following loops are meant to implement same functionality by doing mathworks
                // it also helps avoid writing a billion slidesPerView combos for window widths
                // when the screen width <= 560px, every thumbnails have a different width
                // from 169px, when the width is 17px bigger, we display 0.1 more slide
                for (let width = 169, sides = 1; width <= 424; width += 17, sides += 0.1) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                // from 427px, when the width is 46px bigger, we display 0.2 more slide
                // the width support up to 4K resolution
                for (let width = 427, sides = 1.8; width <= 3840; width += 46, sides += 0.2) {
                    breakpoints[width] = {
                        slidesPerView: sides,
                    };
                }
                return breakpoints;
            })(),
            breakpointsBase: "container",
            centerInsufficientSlides: false,
            mousewheel: true,
            navigation: {
                nextEl: ".carousel-next",
                prevEl: ".carousel-prev",
            },
            slidesPerView: 7,
            virtual: {
                enabled: true,
                addSlidesAfter: 2,
                addSlidesBefore: 2,
            },
        });

        Index.updateCarousel(e, id);
    }
};

Index.updateCarousel = function (e, id) {
    e?.preventDefault();
    $("#"+id+" #carousel-empty").hide();
    $("#"+id+" #carousel-loading").show();
    $("#"+id+" .swiper-wrapper").hide();

    //$("#"+id+"> #reload-carousel").addClass("fa-spin");

    // Hit a different API endpoint depending on the requested localStorage carousel type
    let endpoint;
    //$("#carousel-title").text("Randomly Picked");
    endpoint = `/api/tankoubon/${id}?decoded=1`;

    if (Index.carouselMap.get(id)) {
        Server.callAPI(endpoint, "GET", null, "Error getting carousel data!",
            (results) => {
                Index.swiper.virtual.removeAllSlides();
                const slides = results.archives
                    .map((archive) => LRR.buildThumbnailDiv(archive));
                Index.swiper.virtual.appendSlide(slides);
                Index.swiper.virtual.update();

                if (results.archives.length === 0) {
                    $("#"+id+" #carousel-empty").show();
                }

                $("#"+id+" #carousel-loading").hide();
                $("#"+id+" .swiper-wrapper").show();
                $("#"+id+" #reload-carousel").removeClass("fa-spin");
            },
        );
    }
};

Index.createList = function (e) {
    e?.preventDefault();
    var modal = document.getElementById("addl-modal");
    let endpoint;
    let lname = $("#list-name").val();
    endpoint = `/api/tankoubon?name=${lname}`;

    Server.callAPI(endpoint, 'PUT', null, "Error Creating!", 
        (json) => {
            var list;
            list = Index.baserg.clone(true);
            Index.carouselMap.set(json.tankoubon_id, false);
            list.attr("id", json.tankoubon_id);
            list.find("#carousel-title").text(lname);
            list.appendTo("#list_rg");
        }
    );

    modal.style.display = "none";

}

Index.editList = function (id) {
    let endpoint;
    endpoint = `/api/tankoubon/${id}?decoded=1`;
    Server.callAPI(endpoint, "GET", null, "Error getting carousel data!",
        (results) => {
            $("#sortlist").empty();

            for (var i = 0; i < results.archives.length; i++) {
                $(`<li id="${results.archives[i].arcid}">${results.archives[i].title}</li>`).appendTo("#sortlist");
            }

            $("#save-order").on("click", (e) => {
                Index.saveList(id);
            });
            

            //Show Modal
            Index.initializeSortableList();
            // Get the modal
            var modal = document.getElementById("editl-modal");

            //document.getElementById("create-list_form").reset();
            modal.style.display = "block";

            // When the user clicks anywhere outside of the modal, close it
            window.onclick = function(event) {
              if (event.target == modal) {
                modal.style.display = "none";
              }
            }
        },
    );
}

Index.saveList = function (id) {
    var updated_list = [];
    let endpoint = `/api/tankoubon/${id}/archive`;
    $('#sortlist li').each(function(i)
    {
       updated_list.push($(this).attr('id'));
    });

    Server.callAPIBody(endpoint, "PUT", 
        JSON.stringify({archives:updated_list}), null, "Error", (json) => {
            Index.updateCarousel(null, id);
        });
}

Index.removeList = function (id) {
    let endpoint;
    endpoint = `/api/tankoubon/${id}`;

    Server.callAPI(endpoint, 'DELETE', null, "Error deleting!", 
        (json) => {
            $(`#${id}`).remove();
        }
    );
}

Index.addElementToList = function (id, arcid) {
    var updated_list = [];
    let endpoint = `/api/tankoubon/${id}/${arcid}`;

    Server.callAPI(endpoint, 'PUT', null, "Error adding!", 
        (json) => {
            console.log(json);
        }
    );
}



jQuery(() => {
    Index.initializeAll();
});
