function initToast() {
    window.toast = (c) => {
        window.reactToastify.toast(window.react.createElement("div", { dangerouslySetInnerHTML: { __html: `<h2>${c.heading}</h2>${c.text}` } }), {
            type: c.icon,
            position: c.position,
            autoClose: c.hideAfter,
            closeButton: c.allowToastClose,
            limit: c.stack,
            hideProgressBar: !c.loader,
        });
    };
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.textAlign = "initial";
    window.react.render(
        window.react.createElement(window.reactToastify.ToastContainer, { theme: "colored" }, undefined), toastDiv);
}

$("head").append(`<link rel="stylesheet" type="text/css" href="/css/vendor/ReactToastify.min.css" />
<script src="/js/vendor/preact.umd.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/hooks.umd.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/compat.umd.js" type="text/JAVASCRIPT"></script>
<script>window.react = window.preactCompat;</script>
<script src="/js/vendor/clsx.min.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/react-toastify.umd.js" type="text/JAVASCRIPT"></script>
<script>jQuery(${initToast.toString()});</script>`);
