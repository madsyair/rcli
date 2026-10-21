# Headless Chrome refuses to start as root without --no-sandbox, which is
# the usual situation in containers and CI runners.
if (requireNamespace("chromote", quietly = TRUE) &&
    identical(unname(Sys.info()[["user"]]), "root")) {
  chromote::set_chrome_args(c(chromote::default_chrome_args(),
                              "--no-sandbox", "--disable-gpu"))
}
