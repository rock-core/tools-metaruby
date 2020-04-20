function toggleBacktraceVisibility(element) {
    /** The ancient JS/CSS engine used by Qt4 does not set style.display
     * from CSS. So, assume that the default is 'none'
     */
    if (element.style.display === "block") {
        element.style.display = "none";
    }
    else {
        element.style.display = "block";
    }
}

function toggleFilteredBacktraceVisibility(element) {
    id = element.id;
    document.getElementById("backtrace_full_" + id).style.display = "none";
    toggleBacktraceVisibility(document.getElementById("backtrace_filtered_" + id));
}

function toggleFullBacktraceVisibility(element) {
    id = element.id;
    document.getElementById("backtrace_filtered_" + id).style.display = "none";
    toggleBacktraceVisibility(document.getElementById("backtrace_full_" + id));
}