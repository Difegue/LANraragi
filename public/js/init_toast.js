jQuery(() => {
    window.toast = (c) => window.reactToastify.toast(
        window.React.createElement("div", { dangerouslySetInnerHTML: { __html: `${c.heading ? `<h2>${c.heading}</h2>` : ""}${c.text ?? ""}` } }), (() => {
            const toastType = c.icon || c.typel;
            const isWarningOrError = (toastType === "warning") || (toastType === "error");
            const autoCloseTime = {
                info: 5000,
                success: 5000,
                warning: 10000,
                error: false,
            };
            return {
                toastId: c.toastId,
                type: toastType || "info",
                position: c.position || "top-left",
                onOpen: c.onOpen,
                onClose: c.onClose,
                autoClose: c.hideAfter ?? c.autoClose ?? autoCloseTime[toastType] ?? 7000,
                closeButton: c.allowToastClose ?? c.closeButton ?? true,
                hideProgressBar: (typeof (c.loader) === "boolean" && !c.loader) ?? c.hideProgressBar ?? false,
                pauseOnHover: c.pauseOnHover ?? true,
                pauseOnFocusLoss: c.pauseOnFocusLoss ?? true,
                closeOnClick: c.closeOnClick ?? (!isWarningOrError),
                draggable: c.draggable ?? (!isWarningOrError),
            };
        })());
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.textAlign = "initial";
    window.React.render(
        window.React.createElement(window.reactToastify.ToastContainer, {
            style: {},
            limit: 7,
            theme: "light",
        }, undefined), toastDiv);
});
