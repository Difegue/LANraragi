jQuery(() => {
    window.toast = (c) => window.reactToastify.toast(window.React.createElement("div", { dangerouslySetInnerHTML: { __html: `<h2>${c.heading}</h2><p>${c.text}</p>` } }), {
        toastId: c.toastId || undefined,
        type: c.icon || c.type || "info",
        position: c.position || "top-left",
        onOpen: c.onOpen || undefined,
        onClose: c.onClose || undefined,
        autoClose: c.hideAfter || c.autoClose || ((c.icon || c.type) === "info" || (c.icon || c.type) === "success") ? 5000 : 7000,
        closeButton: c.allowToastClose || c.closeButton || true,
        // false at default
        hideProgressBar: (typeof (c.loader) === "boolean" && !c.loader) || c.hideProgressBar,
        pauseOnHover: c.pauseOnHover || true,
        pauseOnFocusLoss: c.pauseOnFocusLoss || true,
        // false at default
        closeOnClick: c.closeOnClick || (c.icon || c.type) === "info" || (c.icon || c.type) === "success",
        // false at default
        draggable: c.draggable || (c.icon || c.type) === "info" || (c.icon || c.type) === "success",
    });
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.textAlign = "initial";
    window.React.render(
        window.React.createElement(window.reactToastify.ToastContainer, {
            style: {},
            limit: 7,
            theme: "colored",
        }, undefined), toastDiv);
});
