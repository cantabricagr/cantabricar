tab_hojas <- function() {
    tabItem(
        tabName = "hojas",
        fluidPage(
            useShinyjs(),
            tags$head(tags$script(src = "message-handler.js")),
            title = "Hojas",
            fluidRow(
                box(
                    title = "Nuevas hojas",
                    status = "success",
                    width = 4,
                    selectInput(inputId = "database_hojas_id", label = "ID", choices = sort(pull(filter(d$siembras, !(id %in% d$cosechas$id), !(id %in% d$hojas$id)), id)), selected = NULL, multiple = TRUE),
                    dateInput(inputId = "database_hojas_date", label = "Fecha", value = today(), language = "es", max = today()),
                    br(),
                    textInput(inputId = "database_hojas_comentarios", label = "Comentarios", value = ""),
                    br(),
                    actionButton("database_nuevas_hojas", "Guardar")
                ),
                box(
                    title = "Borrar hojas",
                    status = "danger",
                    selectInput(inputId = "database_eliminar_hojas_id", label = "ID", choices = sort(d$hojas$id), selected = NULL),
                    br(),
                    actionButton("database_hojas_eliminar_button", "Eliminar")
                )
            ),
            fluidRow(
                DT::dataTableOutput(outputId = "hojas_table")
            )
        )
    )
}
