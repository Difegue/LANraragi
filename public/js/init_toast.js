jQuery(() => {
    window.toast = (c) => window.reactToastify.toast(window.React.createElement("div", { dangerouslySetInnerHTML: { __html: `<h2>${c.heading}</h2><p>${c.text}</p>` } }), {
        toastId: c.toastId,
        type: c.icon || c.type || "info",
        position: c.position || "top-left",
        onOpen: c.onOpen,
        onClose: c.onClose,
        autoClose: c.hideAfter || c.autoClose || ((c.icon || c.type) === "info" || (c.icon || c.type) === "success") ? 5000 : 7000,
        closeButton: c.allowToastClose ?? c.closeButton ?? true,
        hideProgressBar: (typeof (c.loader) === "boolean" && !c.loader) ?? c.hideProgressBar ?? false,
        pauseOnHover: c.pauseOnHover ?? true,
        pauseOnFocusLoss: c.pauseOnFocusLoss ?? true,
        closeOnClick: c.closeOnClick ?? ((c.icon || c.type) === "info" || (c.icon || c.type) === "success") ?? false,
        draggable: c.draggable ?? ((c.icon || c.type) === "info" || (c.icon || c.type) === "success") ?? false,
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
