/**
 * Category Operations.
 */
const Category = {};

Category.categories = [];

Category.initializeAll = function () {

    Server.loadBookmarkCategoryId().then(_ => {
        Category.loadCategories();
    })

    // bind events to DOM
    $(document).on("change.category", "#category", Category.updateCategoryDetails);
    $(document).on("change.catname", "#catname", Category.saveCurrentCategoryDetails);
    $(document).on("change.catsearch", "#catsearch", Category.saveCurrentCategoryDetails);
    $(document).on("change.pinned", "#pinned", Category.saveCurrentCategoryDetails);
    $(document).on("change.bookmark-link", "#bookmark-link", Category.updateBookmarkLink);
    $(document).on("click.new-static", "#new-static", () => Category.addNewCategory(false));
    $(document).on("click.new-dynamic", "#new-dynamic", () => Category.addNewCategory(true));
    $(document).on("click.predicate-help", "#predicate-help", Category.predicateHelp);
    $(document).on("click.delete", "#delete", Category.deleteSelectedCategory);
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.apiURL("/"); });

};

Category.addNewCategory = function (isDynamic) {
    LRR.showPopUp({
        title: I18N.NewCategory,
        input: "text",
        inputPlaceholder: I18N.CategoryDefaultName,
        inputAttributes: {
            autocapitalize: "off",
        },
        showCancelButton: true,
        reverseButtons: true,
        inputValidator: (value) => {
            if (!value) {
                return I18N.MissingCatName;
            }
            return undefined;
        },
    }).then((result) => {
        if (result.isConfirmed) {
            // Initialize dynamic collections with a bogus search
            const searchtag = isDynamic ? "language:english" : "";

            // Make an API request to create category, search is empty -> static, otherwise dynamic
            Server.callAPI(`/api/categories?name=${result.value}&search=${searchtag}`, "PUT", `Category "${result.value}" created!`, "Error creating category:",
                (data) => {
                    // Reload categories and select the newly created ID
                    Category.loadCategories(data.category_id);
                },
            );
        }
    });
};

Category.loadCategories = function (selectedID) {
    fetch(new LRR.apiURL("/api/categories"))
        .then((response) => response.json())
        .then((data) => {
            // Save data clientside for reference in later functions
            Category.categories = data;

            // Clear combobox and fill it again with categories from the API
            const catCombobox = document.getElementById("category");
            catCombobox.options.length = 0;
            // Add default
            catCombobox.options[catCombobox.options.length] = new Option("-- "+ I18N.NoCategory + " --", "", true, false);

            // Add categories, select if the ID matches the optional argument
            data.forEach((c) => {
                const newOption = new Option(c.name, c.id, false, c.id === selectedID);
                catCombobox.options[catCombobox.options.length] = newOption;
            });
            // Update form with selected category details
            Category.updateCategoryDetails();
        })
        .catch((error) => LRR.showErrorToast(I18N.CategoryFetchError, error));
};

Category.updateCategoryDetails = function () {
    // Get selected category ID and find it in the reference array
    const categoryID = document.getElementById("category").value;
    const category = Category.categories.find((x) => x.id === categoryID);

    $("#archivelist").hide();
    $("#bookmarklinkfield").hide();
    $("#dynamicplaceholder").show();

    $(".tag-options").hide();
    if (!category) return;
    $(".tag-options").show();

    document.getElementById("catname").value = category.name;
    document.getElementById("catsearch").value = category.search;
    document.getElementById("pinned").checked = category.pinned === "1";

    if (category.search === "") {
        // Show archives if static and check the matching IDs
        document.getElementById("bookmark-link").checked = (localStorage.getItem("bookmarkCategoryId") === category.id);
        $("#archivelist").show();
        $("#bookmarklinkfield").show();
        $("#dynamicplaceholder").hide();
        $("#predicatefield").hide();

        // Sort archive list alphabetically
        const arclist = $("#archivelist");
        arclist.find("li").sort((a, b) => {
            const upA = $(a).find("label").text().toUpperCase();
            const upB = $(b).find("label").text().toUpperCase();
            if (upA < upB) {
                return -1;
            } else if (upA > upB) {
                return 1;
            } else {
                return 0;
            }
        }).appendTo("#archivelist");

        // Uncheck all
        $(".checklist > * > input:checkbox").prop("checked", false);
        category.archives.forEach((id) => {
            const checkbox = document.getElementById(id);

            if (checkbox != null) {
                checkbox.checked = true;
                // Prepend matching <li> element to the top of the list (ew)
                checkbox.parentElement.parentElement.prepend(checkbox.parentElement);
            }
        });
    } else {
        // Show predicate field if dynamic
        $("#predicatefield").show();
        $("#bookmarklinkfield").hide();
    }
};

Category.saveCurrentCategoryDetails = function () {
    // Get selected category ID
    const categoryID = document.getElementById("category").value;
    const catName = document.getElementById("catname").value;
    const searchtag = document.getElementById("catsearch").value;
    const pinned = document.getElementById("pinned").checked ? "1" : "0";

    Category.indicateSaving();

    // PUT update with name and search (search is empty if this is a static category)
    // Indicate saved and load categories are placed inside the API call to avoid race conditions.
    Server.callAPI(`/api/categories/${categoryID}?name=${catName}&search=${searchtag}&pinned=${pinned}`, "PUT", null, "Error updating category:",
        (data) => {
            Category.indicateSaved();
            Category.loadCategories(data.category_id);
        },
    );
};

Category.updateBookmarkLink = function () {
    const categoryID = document.getElementById("category").value;
    const isChecked = document.getElementById("bookmark-link").checked;
    const wasChecked = (localStorage.getItem("bookmarkCategoryId") === categoryID);
    
    if (!categoryID) {
        return;
    }
    
    Category.indicateSaving();
    
    if (isChecked && !wasChecked) {
        Server.callAPI(
            `/api/categories/bookmark_link/${categoryID}`,
            "PUT",
            null,
            I18N.BookmarkLinkError,
            () => {
                localStorage.setItem("bookmarkCategoryId", categoryID);
                Category.indicateSaved();
            }
        );
    } else if (!isChecked && wasChecked) {
        Server.callAPI(
            "/api/categories/bookmark_link",
            "DELETE",
            null,
            I18N.BookmarkUnlinkError,
            () => {
                localStorage.removeItem("bookmarkCategoryId");
                Category.indicateSaved();
            }
        );
    } else {
        Category.indicateSaved();
    }
};

Category.updateArchiveInCategory = function (id, checked) {
    const categoryID = document.getElementById("category").value;
    Category.indicateSaving();
    // PUT/DELETE api/categories/catID/archiveID
    Server.callAPI(`/api/categories/${categoryID}/${id}`, checked ? "PUT" : "DELETE", null, I18N.CategoryEditError,
        () => {
            // Reload categories and select the archive list properly
            Category.indicateSaved();
            Category.loadCategories(categoryID);
        },
    );
};

Category.deleteSelectedCategory = function () {
    const categoryID = document.getElementById("category").value;
    LRR.showPopUp({
        text: I18N.CategoryDeleteConfirm,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            Server.callAPI(`/api/categories/${categoryID}`, "DELETE", I18N.CategoryDeleted , I18N.CategoryDeleteError,
                () => {
                // Reload categories to show the archive list properly
                    Category.loadCategories();
                },
            );
        }
    });
};

Category.indicateSaving = function () {
    document.getElementById("status").innerHTML = "<i class=\"fas fa-spin fa-2x fa-compact-disc\"></i> Saving your modifications...";
};

Category.indicateSaved = function () {
    document.getElementById("status").innerHTML = "<i class=\"fas fa-2x fa-check-circle\"></i> Saved!";
};

Category.predicateHelp = function () {
    LRR.toast({
        toastId: "predicateHelp",
        heading: I18N.CategoryPredicateTitle,
        text: I18N.CategoryPredicateHelp,
        icon: "info",
        hideAfter: 20000,
    });
};

jQuery(() => {
    Category.initializeAll();
});
