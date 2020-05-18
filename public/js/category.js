let categories = [];

function addNewCategory(isDynamic) {

    const catName = prompt("Enter a name for the new category:", "My Category");
    if (catName == null || catName == "") {
        return;
    }

    // Initialize dynamic collections with a bogus search
    const searchtag = isDynamic ? "language:english" : "";

    // Make an API request to create the category, if search is empty -> static, otherwise dynamic
    genericAPICall(`/api/categories?name=${catName}&search=${searchtag}`, "PUT", `Category "${catName}" created!`, "Error creating category:",
        function (data) {
            // Reload categories and select the newly created ID
            loadCategories(data.category_id);
        });

}

function loadCategories(selectedID) {

    fetch("/api/categories")
        .then(response => response.json())
        .then((data) => {

            // Save data clientside for reference in later functions
            categories = data;

            // Clear combobox and fill it again with categories from the API
            const catCombobox = document.getElementById('category');
            catCombobox.options.length = 0;
            // Add default
            catCombobox.options[catCombobox.options.length] = new Option("-- No Category --", "", true, false);

            // Add categories, select if the ID matches the optional argument
            data.forEach(c => {
                catCombobox.options[catCombobox.options.length] = new Option(c.name, c.id, false, c.id === selectedID);
            });
            // Update form with selected category details
            updateCategoryDetails();
        })
        .catch(error => showErrorToast("Error getting categories from server", error));

}

function updateCategoryDetails() {

    // Get selected category ID and find it in the reference array
    const categoryID = document.getElementById('category').value;
    const category = categories.find(x => x.id === categoryID);

    $("#archivelist").hide();
    $("#dynamicplaceholder").show();

    $(".tag-options").hide();
    if (!category) return;
    $(".tag-options").show();

    document.getElementById('catname').value = category.name;
    document.getElementById('catsearch').value = category.search;
    document.getElementById('pinned').checked = category.pinned === "1";

    if (category.search === "") {
        // Show archives if static and check the matching IDs
        $("#archivelist").show();
        $("#dynamicplaceholder").hide();
        $("#predicatefield").hide();

        // Sort archive list alphabetically
        const arclist = $("#archivelist");
        arclist.find('li').sort(function (a, b) {
            var upA = $(a).find('label').text().toUpperCase();
            var upB = $(b).find('label').text().toUpperCase();
            return (upA < upB) ? -1 : (upA > upB) ? 1 : 0;
        }).appendTo("#archivelist");

        // Uncheck all
        $(".checklist > * > input:checkbox").prop("checked", false);
        category.archives.forEach(id => {
            const checkbox = document.getElementById(id);
            checkbox.checked = true;
            // Prepend matching <li> element to the top of the list (ew)
            checkbox.parentElement.parentElement.prepend(checkbox.parentElement);
        });

    } else {
        // Show predicate field if dynamic
        $("#predicatefield").show();
    }

}

function saveCurrentCategoryDetails() {

    // Get selected category ID
    const categoryID = document.getElementById('category').value;
    const catName = document.getElementById('catname').value;
    const searchtag = document.getElementById('catsearch').value;
    const pinned = document.getElementById('pinned').checked ? "1" : "0";

    indicateSaving();

    // PUT update with name and search (search is empty if this is a static category)
    genericAPICall(`/api/categories/${categoryID}?name=${catName}&search=${searchtag}&pinned=${pinned}`,
        "PUT", null, "Error updating category:",
        function (data) {
            // Reload categories and select the newly created ID
            indicateSaved();
            loadCategories(data.category_id);
        });
}

function updateArchiveInCategory(id, checked) {

    const categoryID = document.getElementById('category').value;
    indicateSaving();
    // PUT/DELETE api/categories/catID/archiveID
    genericAPICall(`/api/categories/${categoryID}/${id}`, checked ? 'PUT' : 'DELETE', null, "Error adding/removing archive to category",
        function (data) {
            // Reload categories and select the archive list properly
            indicateSaved();
            loadCategories(data.category_id);
        });
}

function deleteSelectedCategory() {
    const categoryID = document.getElementById('category').value;
    if (confirm("Are you sure? The category will be deleted permanently!")) {

        genericAPICall(`/api/categories/${categoryID}`, "DELETE", "Category deleted!", "Error deleting category",
            function (data) {
                // Reload categories to show the archive list properly
                loadCategories();
            });
    }
}

function indicateSaving() {
    document.getElementById("status").innerHTML = `<i class="fas fa-spin fa-2x fa-compact-disc"></i> Saving your modifications...`;
}

function indicateSaved() {
    document.getElementById("status").innerHTML = `<i class="fas fa-2x fa-check-circle"></i> Saved!`;
}

function predicateHelp() {
    $.toast({
        heading: 'Writing a Predicate',
        text: 'Predicates follow the same syntax as searches in the Archive Index. Check the <a href="https://sugoi.gitbook.io/lanraragi/basic-operations/searching">Documentation</a> for more information.',
        hideAfter: false,
        position: 'top-left',
        icon: 'info'
    });
}