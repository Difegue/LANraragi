/**
 * Category Operations.
 */
const Category = {};

Category.categories = [];

Category.initializeAll = function () {
    // bind events to DOM
    $(document).on("change.category", "#category", Category.updateCategoryDetails);
    $(document).on("change.catname", "#catname", Category.saveCurrentCategoryDetails);
    $(document).on("change.catsearch", "#catsearch", Category.saveCurrentCategoryDetails);
    $(document).on("change.pinned", "#pinned", Category.saveCurrentCategoryDetails);
    $(document).on("click.new-static", "#new-static", () => Category.addNewCategory(false));
    $(document).on("click.new-dynamic", "#new-dynamic", () => Category.addNewCategory(true));
    $(document).on("click.predicate-help", "#predicate-help", Category.predicateHelp);
    $(document).on("click.delete", "#delete", Category.deleteSelectedCategory);
    $(document).on("click.return", "#return", () => { window.location.href = "/"; });

    Category.loadCategories();
};

Category.addNewCategory = function (isDynamic) {
    const catName = prompt("Enter a name for the new category:", "My Category");
    if (catName === null || catName === "") {
        return;
    }

    // Initialize dynamic collections with a bogus search
    const searchtag = isDynamic ? "language:english" : "";

    // Make an API request to create the category, if search is empty -> static, otherwise dynamic
    Server.callAPI(`/api/categories?name=${catName}&search=${searchtag}`, "PUT", `Category "${catName}" created!`, "Error creating category:",
        (data) => {
            // Reload categories and select the newly created ID
            Category.loadCategories(data.category_id);
        },
    );
};

Category.loadCategories = function (selectedID) {
    fetch("/api/categories")
        .then((response) => response.json())
        .then((data) => {
            // Save data clientside for reference in later functions
            Category.categories = data;

            // Clear combobox and fill it again with categories from the API
            const catCombobox = document.getElementById("category");
            catCombobox.options.length = 0;
            // Add default
            catCombobox.options[catCombobox.options.length] = new Option("-- No Category --", "", true, false);

            // Add categories, select if the ID matches the optional argument
            data.forEach((c) => {
                const newOption = new Option(c.name, c.id, false, c.id === selectedID);
                catCombobox.options[catCombobox.options.length] = newOption;
            });
            // Update form with selected category details
            Category.updateCategoryDetails();
        })
        .catch((error) => LRR.showErrorToast("Error getting categories from server", error));
};

Category.updateCategoryDetails = function () {
    // Get selected category ID and find it in the reference array
    const categoryID = document.getElementById("category").value;
    const category = Category.categories.find((x) => x.id === categoryID);

    $("#archivelist").hide();
    $("#dynamicplaceholder").show();

    $(".tag-options").hide();
    if (!category) return;
    $(".tag-options").show();

    document.getElementById("catname").value = category.name;
    document.getElementById("catsearch").value = category.search;
    document.getElementById("pinned").checked = category.pinned === "1";

    if (category.search === "") {
        // Show archives if static and check the matching IDs
        $("#archivelist").show();
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
    Server.callAPI(`/api/categories/${categoryID}?name=${catName}&search=${searchtag}&pinned=${pinned}`, "PUT", null, "Error updating category:",
        (data) => {
            // Reload categories and select the newly created ID
            Category.indicateSaved();
            Category.loadCategories(data.category_id);
        },
    );
};

Category.updateArchiveInCategory = function (id, checked) {
    const categoryID = document.getElementById("category").value;
    Category.indicateSaving();
    // PUT/DELETE api/categories/catID/archiveID
    Server.callAPI(`/api/categories/${categoryID}/${id}`, checked ? "PUT" : "DELETE", null, "Error adding/removing archive to category",
        () => {
            // Reload categories and select the archive list properly
            Category.indicateSaved();
            Category.loadCategories(categoryID);
        },
    );
};

Category.deleteSelectedCategory = function () {
    const categoryID = document.getElementById("category").value;
    if (window.confirm("Are you sure? The category will be deleted permanently!")) {
        Server.callAPI(`/api/categories/${categoryID}`, "DELETE", "Category deleted!", "Error deleting category",
            () => {
                // Reload categories to show the archive list properly
                Category.loadCategories();
            },
        );
    }
};

Category.indicateSaving = function () {
    document.getElementById("status").innerHTML = "<i class=\"fas fa-spin fa-2x fa-compact-disc\"></i> Saving your modifications...";
};

Category.indicateSaved = function () {
    document.getElementById("status").innerHTML = "<i class=\"fas fa-2x fa-check-circle\"></i> Saved!";
};

Category.predicateHelp = function () {
    $.toast({
        heading: "Writing a Predicate",
        text: "Predicates follow the same syntax as searches in the Archive Index. Check the <a href=\"https://sugoi.gitbook.io/lanraragi/basic-operations/searching\">Documentation</a> for more information.",
        hideAfter: false,
        position: "top-left",
        icon: "info",
    });
};

jQuery(() => {
    Category.initializeAll();
});
