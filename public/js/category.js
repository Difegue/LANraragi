let categories = [];

function addNewCategory(isDynamic) {

    const catName = prompt("Enter a name for the new category:", "My Category");
    if (catName == null || catName == "") {
        return;
    }

    // Initialize dynamic collections with a bogus search
    const searchtag = isDynamic ? "language:english" : "";

    // Make an API request to create the category, if search is empty -> static, otherwise dynamic
    fetch(`/api/categories?name=${catName}&search=${searchtag}`, { method: 'PUT' })
        .then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
        .then((data) => {

            if (data.success) {
                $.toast({
                    showHideTransition: 'slide',
                    position: 'top-left',
                    loader: false,
                    heading: `Category "${catName}" created!`,
                    icon: 'success'
                });
                // Reload categories and select the newly created ID
                loadCategories(data.category_id);
            } else {
                throw new Error(data.error);
            }
        })
        .catch(error => showErrorToast("Error creating category", error));

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
    fetch(`/api/categories/${categoryID}?name=${catName}&search=${searchtag}&pinned=${pinned}`, { method: 'PUT' })
        .then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
        .then((data) => {
            if (!data.success)
                throw new Error(data.error);

            // Reload categories and select the newly created ID
            indicateSaved();
            loadCategories(data.category_id);
        })
        .catch(error => showErrorToast("Error updating category", error));
}

function updateArchiveInCategory(id, checked) {

    const categoryID = document.getElementById('category').value;
    indicateSaving();
    // PUT/DELETE api/categories/catID/archiveID
    fetch(`/api/categories/${categoryID}/${id}`, { method: checked ? 'PUT' : 'DELETE' })
        .then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
        .then(data => {
            if (!data.success)
                throw new Error(data.error);

            indicateSaved();
            // Reload categories to show the archive list properly
            loadCategories(categoryID);
        })
        .catch(error => showErrorToast("Error adding/removing archive to category", error));
}

function deleteSelectedCategory() {
    const categoryID = document.getElementById('category').value;
    if (confirm("Are you sure? The category will be deleted permanently!")) {

        fetch(`/api/categories/${categoryID}`, { method: 'DELETE' })
            .then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
            .then(data => {
                if (!data.success)
                    throw new Error(data.error);

                $.toast({
                    showHideTransition: 'slide',
                    position: 'top-left',
                    loader: false,
                    heading: "Category deleted!",
                    icon: 'success'
                });

                // Reload categories to show the archive list properly
                loadCategories();
            })
            .catch(error => showErrorToast("Error deleting category", error));

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