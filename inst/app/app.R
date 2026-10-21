# Shiny entry point of the rcli interface, used for deployment (Shiny
# Server, Posit Connect) and by the browser tests. Set the environment
# variable RCLI_LANGUAGE to "en" for the English interface.
rcli::rcli_app(Sys.getenv("RCLI_LANGUAGE", "id"))
