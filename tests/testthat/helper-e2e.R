# Helpers for the browser (end-to-end) tests of the Shiny interface.

skip_if_no_browser <- function() {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")
  skip_if(is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
          "Chrome is not available")
}

# Start the installed application in headless Chrome.
start_app <- function(name, language = "en") {
  old <- Sys.getenv("RCLI_LANGUAGE")
  Sys.setenv(RCLI_LANGUAGE = language)
  on.exit(Sys.setenv(RCLI_LANGUAGE = old))
  shinytest2::AppDriver$new(
    system.file("app", package = "rcli"), name = name,
    width = 1400, height = 1100, load_timeout = 60000, timeout = 60000,
    seed = 1
  )
}

# Screenshots are saved for human review (they are not compared, because
# fonts differ between platforms). Set RCLI_SCREENSHOT_DIR to keep them.
shot <- function(app, file) {
  dir <- Sys.getenv("RCLI_SCREENSHOT_DIR", tempdir())
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  app$get_screenshot(file.path(dir, paste0(file, ".png")))
}

go_to <- function(app, k) {
  app$click(paste0("next", k - 1L))
  app$wait_for_idle(timeout = 60000)
  expect_equal(app$get_value(input = "step"), paste0("s", k))
}

# A plot output has been drawn as a PNG image.
expect_plot <- function(app, id) {
  v <- app$get_value(output = id)
  expect_true(is.list(v) && startsWith(v$src, "data:image/png"),
              label = sprintf("plot '%s' is drawn", id))
}

notifications <- function(app) {
  html <- app$get_html("#shiny-notification-panel")
  if (is.null(html)) "" else html
}

# No JavaScript exception or console error in the browser.
expect_no_browser_errors <- function(app) {
  logs <- as.data.frame(app$get_logs())
  bad <- logs[logs$location == "chromote" &
                (logs$level %in% "error" | logs$type %in% "exception"), ]
  expect_equal(nrow(bad), 0L,
               label = paste(c("browser errors", bad$message),
                             collapse = "\n"))
}

# The text of an element contains `text`. Outputs of a tab that has just
# become visible are drawn after the inputs settle, later on slow machines,
# so wait for the text before checking it.
expect_text_soon <- function(app, selector, text, timeout = 30000) {
  js <- sprintf(paste0("(function() { var e = document.querySelector(%s);",
                       " return e !== null && e.innerText.indexOf(%s) >= 0;",
                       " })()"),
                encodeString(selector, quote = "\""),
                encodeString(text, quote = "\""))
  tryCatch(app$wait_for_js(js, timeout = timeout), error = function(e) NULL)
  expect_match(app$get_text(selector), text, fixed = TRUE)
}
