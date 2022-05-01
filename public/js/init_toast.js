jQuery(() => {
    window.toast = (c) => window.reactToastify.toast(window.react.createElement("div", { dangerouslySetInnerHTML: { __html: `<h2>${c.heading}</h2>${c.text}` } }), {
        type: c.icon,
        position: c.position,
        autoClose: c.hideAfter,
        closeButton: c.allowToastClose,
        limit: c.stack,
        hideProgressBar: !c.loader,
    });
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.textAlign = "initial";
    window.react.render(
        window.react.createElement(window.reactToastify.ToastContainer, { theme: "colored" }, undefined), toastDiv);
});
