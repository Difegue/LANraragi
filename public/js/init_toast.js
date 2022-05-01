function initToast() {
    window.toast = window.reactToastify;
    const toastDiv = document.createElement("div");
    document.body.appendChild(toastDiv);
    toastDiv.style.all = "initial";
    window.react.render(
        window.react.createElement(window.reactToastify.ToastContainer, null, undefined), toastDiv);
}

$("head").append(`<link rel="stylesheet" type="text/css" href="/css/vendor/ReactToastify.min.css" />
<script src="/js/vendor/preact.umd.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/hooks.umd.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/compat.umd.js" type="text/JAVASCRIPT"></script>
<script>window.react = window.preactCompat;</script>
<script src="/js/vendor/clsx.min.js" type="text/JAVASCRIPT"></script>
<script src="/js/vendor/react-toastify.umd.js" type="text/JAVASCRIPT"></script>
<script>jQuery(${initToast.toString()});</script>`);
