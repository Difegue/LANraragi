/**
 * Reader stamps/marker system
 */
import * as Server from "./server.js";
import * as LRR from "./common.js";
import I18N from "i18n";

import { state, getArchiveForPage, inFullscreen } from "./reader_common.js";
import { checkStampedPages } from "./reader_archive_overlay.js";
import { effect } from "@preact/signals";

export function initializeStamps() {
    initContextMenu();

    $(document).on("keyup", (e) => handleShortcuts(e));

    effect(() => {
        // Show or hide the markers
        localStorage.markersVisible = state.markersVisible.value;
        renderMarkers();
    });

    $(document).on("click.reader-image", ".reader-image", (e) => {
        if (!state.markerMode) return;

        $(".reader-image").css("cursor", "");
        $(".reader-image").css("z-index", 19);

        // Compute marker position
        // This basically estimates the percentage of the width and legth of the image
        // where the user clicked, so later from this percentage can be reversed
        // without being affected by if the image got scaled up or down
        const img = e.currentTarget;

        const rect = img.getBoundingClientRect();

        const clickX = e.clientX - rect.left;
        const clickY = e.clientY - rect.top;

        const xPercent = (clickX / rect.width) * 100;
        const yPercent = (clickY / rect.height) * 100;

        const markerData = {
            x: xPercent,
            y: yPercent,
            name: `Marker`,
            left: true,
        };

        let page = state.currentPage.value + 1;

        if (state.doublePageMode.value && state.currentPage.value > 0
            && state.currentPage.value < state.maxPage.value) {
            if (img.id == "img_doublepage") {
                page += 1;
                markerData.left = false;
            }
        }
        LRR.showPopUp({
            title: I18N.StampName,
            input: "text",
            inputPlaceholder: I18N.StampPlaceholder,
            inputAttributes: {
                autocapitalize: "off",
            },
            showCancelButton: true,
            reverseButtons: true,
        }).then((result) => {
            $("#overlay-page").hide();
            state.markerMode = false;
            if (result.isConfirmed && result.value.trim() !== "") {
                const { arcId, localPage } = getArchiveForPage(page);
                Server.callAPI(`/api/archives/${arcId}/stamps/${localPage}?position=${markerData.x},${markerData.y}&content=${result.value}`, 
                    "PUT", "Stamp added!", I18N.StampError,
                    (data) => {
                        markerData.id = data["stamp_id"];
                        markerData.name = result.value;

                        state.markers.push(markerData);
                        renderMarkers();
                        checkStampedPages();
                    }
                );
            } else {
                renderMarkers();
            }
        });
        e.stopPropagation();
    });

    // Press esc to cancel set stamp action
    $(document).on("keydown.stamps", (e) => {
        e.stopPropagation();
        if (e.key === "Escape" && state.markerMode) {
            $("#overlay-page").hide();
            state.markerMode = false;
            renderMarkers();
            state.pageNaviState = true;
            $(".reader-image").css("cursor", "");
            $(".reader-image").css("z-index", 19);
        }
    });

    window.addEventListener("resize", () => {
        // Reload the markers everytime the image size changes
        renderMarkers();
    });
}

/** Process inputs
 * @param {JQuery.KeyDownEvent<Document, undefined, Document, Document> | JQuery.KeyUpEvent<Document, undefined, Document, Document>} e
*/
function handleShortcuts(e) {
    if (e.target.tagName === "INPUT") {
        return;
    }

    switch (e.which) {
        case 83: // s
            if (!state.infiniteScroll.value) {
                addStamp();
            }
            break;
        default:
            break;
    }
}

function addStamp() {
    if (state.infiniteScroll.value) return;
    if (!LRR.isUserLogged()) return;
    state.markerMode = true;
    clearMarkers();
    $(".reader-image").css("cursor", "cell");
    $(".reader-image").css("z-index", 22);
    $("#overlay-page").show();
}

function createMarkerElement(markerData, index) {
    if (state.infiniteScroll.value) return;
    const img = markerData.left
        ? document.getElementById("img")
        : document.getElementById("img_doublepage");


    const display = document.getElementById("display");
    const container = document.getElementById("i1");

    const marker = document.createElement("div");
    marker.className = "marker marker-context-menu";

    // Compute the px coordinates from the percentage based coordinates
    const rect = img.getBoundingClientRect();
    const xPx = (markerData.x / 100) * rect.width;
    const yPx = (markerData.y / 100) * rect.height;

    const containerRect = container.getBoundingClientRect();

    let leftFix = rect.left - containerRect.left;
    let topFix = rect.top - containerRect.top;

    if (!markerData.left) {
        // Add the width of the left page plus the left and right margin
        const img = document.getElementById("img");
        leftFix += img.width+2;
    }

    marker.style.left = `${leftFix + xPx}px`;
    marker.style.top = `${topFix + yPx}px`;

    marker.title = markerData.name;
    marker.dataset.index = index;

    // Edit
    let isDragging = false;

    marker.addEventListener("mousedown", (e) => {
        if (e.button !== 0) return;
        e.stopPropagation();
        isDragging = true;

        // So no text gets selected during the D&D
        document.body.style.userSelect = "none";
        state.pageNaviState = false;
    });

    document.addEventListener("mousemove", (e) => {
        if (!isDragging) return;

        const imgRect = img.getBoundingClientRect();
        const dispRect = display.getBoundingClientRect();

        // Ensure that the stamp remains inside the image
        let x = e.clientX - imgRect.left + leftFix;
        let y = e.clientY - imgRect.top + topFix;

        x = Math.max(leftFix, Math.min(x, imgRect.width + leftFix));
        y = Math.max(topFix, Math.min(y, imgRect.height + topFix));

        marker.style.left = `${imgRect.left + x - dispRect.left}px`;
        marker.style.top = `${imgRect.top + y - dispRect.top}px`;
    });

    document.addEventListener("mouseup", (e) => {
        e.stopPropagation();
        // Each marker individually run this event when on mouseup
        // this line ensures that only one of them execute the action
        // also a good improvement would be to change this to an attachable event only for the dragged marker
        if (!isDragging) return;

        isDragging = false;
        document.body.style.userSelect = "auto";

        const imgRect = img.getBoundingClientRect();

        let x = e.clientX - imgRect.left;
        let y = e.clientY - imgRect.top;

        x = Math.max(0, Math.min(x, imgRect.width));
        y = Math.max(0, Math.min(y, imgRect.height));

        const xPercent = (x / imgRect.width) * 100;
        const yPercent = (y / imgRect.height) * 100;

        const i = marker.dataset.index;
        let inputValue = markerData.name;

        Server.callAPI(`/api/stamps/${markerData.id}?position=${xPercent},${yPercent}`, "PUT", "Stamp updated!", I18N.StampError,
            () => {
                state.markers[i].x = xPercent;
                state.markers[i].y = yPercent;

                state.pageNaviState = true;
                renderMarkers();
            }
        );
    });

    display.appendChild(marker);
}

export function renderMarkers() {
    if (state.infiniteScroll.value || inFullscreen()) return;
    // Clean markers
    const existing = document.querySelectorAll(".marker");
    existing.forEach(el => el.remove());

    if (!state.markersVisible.value) return;

    // Draw markers
    state.markers.forEach((markerData, index) => {
        createMarkerElement(markerData, index);
    });
}

export function clearMarkers() {
    const existing = document.querySelectorAll(".marker");
    existing.forEach(el => el.remove());
}

function loadStamps(currentPage) {
    if (state.infiniteScroll.value) return;
    state.markers = [];
    const { arcId: id1, localPage: p1 } = getArchiveForPage(currentPage);
    // Call for the first page
    Server.callAPI(`/api/archives/${id1}/stamps/${p1}`, "GET", null, I18N.ServerInfoError,
        (data) => {
            for (var i = data.result.length - 1; i >= 0; i--) {
                let markerData = {};
                let x = data.result[i].position.split(",")[0];
                let y = data.result[i].position.split(",")[1];
                markerData.x = x;
                markerData.y = y;
                markerData.name = data.result[i].content;
                markerData.id = data.result[i].id;
                markerData.left = true;
                state.markers.push(markerData);
            }

            if (state.doublePageMode.value && currentPage > 0
                && currentPage < state.maxPage.value) {

                const { arcId: id2, localPage: p2 } = getArchiveForPage(currentPage + 1);
                // Call for the second page (may be in a different archive for tanks)
                Server.callAPI(`/api/archives/${id2}/stamps/${p2}`, "GET", null, I18N.ServerInfoError,
                    (data) => {
                        for (var i = data.result.length - 1; i >= 0; i--) {
                            let markerData = {};
                            let x = data.result[i].position.split(",")[0];
                            let y = data.result[i].position.split(",")[1];
                            markerData.x = x;
                            markerData.y = y;
                            markerData.name = data.result[i].content;
                            markerData.id = data.result[i].id;
                            markerData.left = false;
                            state.markers.push(markerData);
                        }

                        // Render markers
                        renderMarkers();
                    }
                );
            } else {
                // Render markers
                renderMarkers();
            }
        }
    );
}

function handleMarkerContextMenu(option, index) {
    if (state.infiniteScroll.value) return;
    let i = parseInt(index);

    switch (option) {
        case "editmarker": {
            let emarker = state.markers[i];
            let inputValue = emarker.name;

            LRR.showPopUp({
                title: I18N.StampName,
                input: "text",
                inputPlaceholder: I18N.StampPlaceholder,
                inputAttributes: {
                    autocapitalize: "off",
                },
                inputValue,
                showCancelButton: true,
                reverseButtons: true,
            }).then((result) => {
                if (result.isConfirmed && result.value.trim() !== "") {
                    Server.callAPI(`/api/stamps/${emarker.id}?content=${result.value}`, "PUT", "Stamp updated!", I18N.StampError,
                        () => {
                            state.markers[i].name = result.value;

                            state.pageNaviState = true;
                            renderMarkers();
                        }
                    );
                } else {
                    state.pageNaviState = true;
                }
            });
            break;
        }
        case "deletemarker": {
            let dmarker = state.markers[i];
            Server.callAPI(`/api/stamps/${dmarker.id}`, "DELETE", "Stamp deleted!", I18N.StampError,
                () => {
                    state.markers.splice(i, 1);
                    renderMarkers();
                    if (state.markers.length == 0) {
                        checkStampedPages();
                    }
                }
            );
            break;
        }
        default:
            break;
    }
}

export function updateStamps(page) {
    // Clear markers
    state.markers = [];
    renderMarkers();

    // Load stamps
    if (!state.infiniteScroll.value) {
        loadStamps(page);
    }
}

function initContextMenu() {
    $.contextMenu({
        selector: `.marker-context-menu`,
        build: ($trigger, e) => {
            e.preventDefault();
            e.stopPropagation();
            return {
                callback: function (key, options) {
                    handleMarkerContextMenu(key, $(this).attr("data-index"));
                },
                items: {
                    "editmarker": {"name": "Edit Marker", "icon":"fas fa-pen-to-square"},
                    "deletemarker": {"name": "Delete Marker", "icon":"fas fa-minus"},
                }
            };
        }
    });
}
