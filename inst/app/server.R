shinyServer(
  function(input, output, session) {
    output$sidebar <- renderMenu({
      sidebarMenu(
        menuItem("Dashboard", tabName = "dashboard", icon = icon("tachometer-alt")),
        menuItem("Calendario", tabName = "calendario", icon = icon("calendar")),
        menuItem("Base de datos", tabName = "datos", icon = icon("database")),
        menuItem("Estimaciones", tabName = "estimaciones", icon = icon("chart-bar")),
        menuItem("A\u00f1adir datos",  icon = icon("plus"),
                 menuSubItem("Siembra", icon = icon("tint"), tabName = "siembra"),
                 menuSubItem("Germinaci\u00f3n", icon = icon("seedling"), tabName = "germinacion"),
                 menuSubItem("Hojas", icon = icon("leaf"), tabName = "hojas"),
                 menuSubItem("Cosecha", icon = icon("tractor"), tabName = "cosecha"),
                 startExpanded = TRUE),
        menuItem("Web", icon = icon("globe"), href = "https://www.cantabricagr.com/"),
        menuItem("GitHub", icon = icon("github"), href = "https://github.com/cantabricagr/cantabricar"),
        menuItem("Slack", icon = icon("slack"), href = "https://cantabrica.slack.com/home"),
        menuItem("Instagram", icon = icon("instagram"), href = "https://www.instagram.com/cantabricagr/"),
        menuItem("Twitter", icon = icon("twitter"), href = "https://twitter.com/cantabricagr"),
        menuItem("LinkedIn", icon = icon("linkedin"), href = "https://www.linkedin.com/company/cantabricagr/")
      )
    })

    output$notifications <- renderMenu({
      dropdownMenu(
        type = "tasks", headerText = "Activas", badgeStatus = "info",
        taskItem(value = round(100*length(active_ids()$germinaciones)/length(active_ids()$siembras), 2), color = "green", text = "Germinadas"),
        taskItem(value = round(100*length(active_ids()$hojas)/length(active_ids()$siembras), 2), color = "yellow", text = "Con hojas"),
        taskItem(value = round(100*length(active_ids()$cosechas)/length(active_ids()$siembras), 2), color = "red", text = "Trasplantadas")
      )
    })

    output$n_sembradas <- renderText({ length(active_ids()$siembras) })
    output$n_germinadas <- renderText({ length(active_ids()$germinaciones) })
    output$n_hojas <- renderText({ length(active_ids()$hojas) })
    output$n_cosechadas <- renderText({ length(d$cosechas) })

    active_ids <- reactive({
      d %>%
        map(
          function(x)
          {
            filter(x, !(id %in% d$cosechas$id)) %>%
              pull(id) %>%
              sort()
          }
        )
    })

      inactive_ids <- reactive({
        d %>%
          map(
            function(x)
            {
              filter(x, id %in% d$cosechas$id) %>%
                pull(id) %>%
                sort()
            }
          )
      })

      observe({
        updateTextInput(
          session, "database_siembra_id",
          value = ifelse(nrow(d$siembras) > 0, max(d$siembras$id, na.rm = TRUE)+1, 1),
          placeholder = ifelse(nrow(d$siembras) > 0, max(d$siembras$id, na.rm = TRUE), 1),
        )
        updateSelectInput(session, "database_germinacion_id", choices = ifelse(
          length(active_ids()$siembras > 0),
          first(active_ids()$siembras),
          NA_integer_
        ))
        updateSelectInput(session, "database_hojas_id", choices = ifelse(
          length(active_ids()$siembras > 0),
          active_ids()$siembras,
          NA_integer_
        ))
        updateSelectInput(session, "database_cosecha_id", choices = ifelse(
          length(active_ids()$siembras > 0),
          active_ids()$siembras,
          NA_integer_
        ))
        updateSelectInput(session, "database_siembra_especie", choices = values$especie)
        updateSelectInput(session, "database_siembra_variedad", choices = values$variedad)
        updateSelectInput(session, "database_siembra_marca", choices = values$marca)
        updateSelectInput(session, "database_siembra_medio_siembra", choices = values$medio_siembra)
        updateSelectInput(session, "database_siembra_planta_tipo", choices = values$planta_tipo)
        updateSelectInput(session, "database_eliminar_siembra_id", choices = ifelse(
          length(active_ids()$siembras > 0),
          active_ids()$siembras,
          NA_integer_
        ))
        updateSelectInput(session, "database_eliminar_germinacion_id", choices = ifelse(
          length(active_ids()$germinaciones > 0),
          active_ids()$germinaciones,
          NA_integer_
        ))
        updateSelectInput(session, "database_eliminar_hojas_id",  choices = ifelse(
          length(active_ids()$hojas > 0),
          active_ids()$hojas,
          NA_integer_
        ))
        updateSelectInput(session, "database_eliminar_cosecha_id", choices = ifelse(
          length(active_ids()$cosechas > 0),
          active_ids()$cosechas,
          NA_integer_
        ))
      })


      observeEvent(input$actualizar, {
        message("Updating...")
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        d <<- db_get_data(con)
        remove_modal_spinner()
        session$reload()
      })


      ## germinaciones ----
      output$dashboard_germinaciones_table <- renderDataTable({
        x <- d_all %>%
          drop_na(fecha_siembra) %>%
          filter(
            id %in% active_ids()$sembradas,
            !(id %in% active_ids()$cosechadas)
          ) %>%
          mutate(
            fecha_siembra = format(as_datetime(fecha_siembra)),
            fecha_germinacion_estimada = format(as_datetime(fecha_siembra) + round(fixef(fit_germinacion)[1], 2))
          ) %>%
          select(id, fecha_siembra, fecha_germinacion_estimada, estanteria, balda, bandeja) %>%
          DT::datatable(
            colnames = c("ID", "Siembra", "Germinaci\u00f3n estimada", "estanteria", "balda", "bandeja"),
            caption = "Bandejas en sembradas y fecha estimada de germinacion (95%)",
            options = list(autoWidth = FALSE, searching = FALSE),
            rownames = FALSE
          )
        return(x)
      })

      output$dashboard_fechas_plot <- renderPlotly({
        x <- db_summarise(con) %>%
          count(fecha_siembra,  especie) %>%
          mutate(fecha_siembra = as.Date(fecha_siembra)) %>%
          group_by(especie) %>%
          mutate(n_cum = cumsum(n)) %>%
          ungroup() %>%
          ggplot(
            aes(fecha_siembra, n_cum, fill = especie, colour = especie,
                texto = paste0(especie, ": n=", n_cum, " (", fecha_siembra, ")"))
          ) +
          geom_line(aes(group = especie), size = 1) +
          labs(x = "Fecha de siembra", y = "# siembras", colour = "Especie") +
          theme_custom() +
          scale_x_date(date_labels = "%b %d") +
          scale_y_continuous(labels = as.integer) +
          theme(
            legend.position = "top",
            legend.title = element_blank(),
            panel.grid.major.x = element_blank(),
            axis.text = element_text(size = 12)
          )
        return(x)
      })

      output$dashboard_species_plot <- renderPlotly({
        x <-  db_summarise(con) %>%
          count(especie) %>%
          mutate(prop = n/sum(.$n)) %>%
          ggplot(aes(x = 1, y = prop, fill = especie, text = paste0(especie, " (n=", n, ", ", round(prop*100, 2), "%)"))) +
          geom_bar(stat = "identity") +
          labs(fill = "Especie", y = "%") +
          scale_x_continuous(limits = c(0.5, 1.5)) +
          theme_void() +
          theme(
            legend.position = "none",
            panel.grid = element_blank()
          )
        return(x)
      })


      # calendario ----
      output$calendario <- renderCalendar({
        x <- db_summarise(con) %>%
          select(id, especie, variedad, fecha_siembra) %>%
          mutate(
            fecha_siembra = as_datetime(fecha_siembra),
            start = fecha_siembra,
            end = fecha_siembra + ceiling(fixef(fit_cosecha)[1]),
            title = paste0("ID: ", id, " (", especie, " ", variedad, ")"),
            body = paste("Tiempo de siembra-cosecha estimado para ID: ", id, "."),
            recurrenceRule = NA_character_,
            category = "time",
            location = "Cantabrica",
            bgColor = case_when(
              especie=="Rábano" ~ "#F8766D",
              especie=="Swisschard" ~ "#D39200",
              especie=="Guisante" ~ "#93AA00",
              especie=="Albahaca" ~ "#00BA38",
              especie=="Melisa" ~ "#00C19F",
              especie=="Pe-tsai" ~ "#00B9E3",
              especie=="Pak choi" ~ "#619CFF",
              especie=="Mizuna" ~ "#DB72FB",
              TRUE ~ "#000000"
            ),
            borderColor = case_when(
              especie=="Rábano" ~ "#F8766D",
              especie=="Swisschard" ~ "#D39200",
              especie=="Guisante" ~ "#93AA00",
              especie=="Albahaca" ~ "#00BA38",
              especie=="Melisa" ~ "#00C19F",
              especie=="Pe-tsai" ~ "#00B9E3",
              especie=="Pak choi" ~ "#619CFF",
              especie=="Mizuna" ~ "#DB72FB",
              TRUE ~ "#000000"
            ),
            color = case_when(
              especie=="Rábano" ~ "#F8766D",
              especie=="Swisschard" ~ "#D39200",
              especie=="Guisante" ~ "#93AA00",
              especie=="Albahaca" ~ "#00BA38",
              especie=="Melisa" ~ "#00C19F",
              especie=="Pe-tsai" ~ "#00B9E3",
              especie=="Pak choi" ~ "#619CFF",
              especie=="Mizuna" ~ "#DB72FB",
              TRUE ~ "#000000"
            )
          ) %>%
          calendar(
            view = "month",
            useDetailPopup = TRUE,
            isReadOnly = TRUE,
            useNavigation = TRUE
          ) %>%
          cal_week_options(
            startDayOfWeek = 1,
            daynames = c("L", "M", "X", "J", "V", "S", "D")
          )

        return(x)
      })

      # base de datos ----
      output$database_table <- render_gt({

        x <- db_summarise(con) %>%
          arrange(desc(id)) %>%
          select(-planta_tipo) %>%
          relocate(id, especie, variedad, marca, starts_with("fecha_"), starts_with("t_")) %>%
          mutate_at(vars(starts_with("t_")), function(x) ifelse(is.na(x), NA_real_, as.numeric(x))) %>%
          mutate_at(vars(starts_with("fecha_")), function(x) ifelse(is.na(x), NA_Date_, as.character(x))) %>%
          gt() %>%
          fmt_number(starts_with("t_")) %>%
          fmt_missing(columns = everything(), rows = everything(), missing_text = " - ") %>%
          tab_spanner(md("**Fechas**"), starts_with("fecha_")) %>%
          tab_spanner(md("**Tiempos (d)**"), starts_with("t_")) %>%
          fmt_date(starts_with("fecha_"), date_style = "iso") %>%
          cols_label(
            id = md("**ID**"),
            especie = md("**Especie**"),
            variedad = md("**Variedad**"),
            marca = md("**Marca**"),
            fecha_siembra = md("**Siembra**"),
            fecha_germinacion = md("**Germinaci\u00f3n**"),
            fecha_hojas = md("**Hojas**"),
            fecha_cosecha = md("**Cosecha**"),
            medio_siembra =  md("**Medio**"),
            luz = md("**Luz**"),
            domo = md("**Domo**"),
            peso = md("**Peso**"),
            calor = md("**Calor**"),
            peso_semillas = md("**Semillas (g)**"),
            t_germinacion = md("**Germinaci\u00f3n**"),
            t_hojas = md("**Hojas**"),
            t_cosecha = md("**Cosecha**")
          )

        return(x)
      })

      output$descargar <- downloadHandler(
        filename = function() paste0("cantabrica_", format(Sys.time(), "%Y-%m-%d_%H%M"), ".csv"),
        content = function(file)
        {
          x <- d_all %>%
            mutate_at(vars(starts_with("t_")), function(x) ifelse(is.na(x), "-", x)) %>%
            mutate_at(vars(starts_with("fecha_")), as_datetime) %>%
            arrange(desc(fecha_siembra), desc(id))
          write.table(x, file = file, sep = ",", na = "", row.names = FALSE)
        }
      )

      # estimaciones ----
      observeEvent(input$ajustar_modelos, {
        message("Ajustando modelos")
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Germinaciones (1/3)")
        fit_germinacion <<- fit_model(
          data = d_all %>% drop_na(t_germinacion) %>% select(id, especie, t_germinacion) %>% mutate(t_germinacion = as.integer(t_germinacion)) %>% rename(y = t_germinacion),
          type = "germinacion"
        )
        show_modal_spinner(spin = "semipolar", color = "Crimson", text = "Hojas verdaderas (2/3)")
        fit_hojas <<- fit_model(
          data = d_all %>% drop_na(t_hojas) %>% select(id, especie, t_hojas) %>% mutate(t_hojas = as.integer(t_hojas)) %>% rename(y = t_hojas),
          type = "hojas"
        )
        show_modal_spinner(spin = "semipolar", color = "DarkOrange", text = "Cosechas (3/3)")
        fit_cosecha <<- fit_model(
          data = d_all %>% drop_na(t_cosecha) %>% select(id, especie, t_cosecha) %>% mutate(t_cosecha = as.integer(t_cosecha)) %>% rename(y = t_cosecha),
          type = "cosecha"
        )
        remove_modal_spinner()
        session$reload()
      })

      ## germinacion
      output$estimaciones_germinacion_table <- render_gt({
        x <- ranef(fit_germinacion)$especie[,,"Intercept"] + fixef(fit_germinacion)[1]
        tbl <- as.data.frame(x, row.names = row.names(x)) %>%
          rownames_to_column("especie") %>%
          gt() %>%
          fmt_number(Estimate:Q97.5) %>%
          cols_merge(Q2.5:Q97.5, pattern = "[{1}, {2}]") %>%
          cols_label(
            especie = md("**Especie**"),
            Estimate = md("***Media***"),
            Est.Error = md("***SE***"),
            Q2.5 = md("**95% *CrI***")
          )
        return(tbl)
      })

      # estimaciones germinacion
      output$estimaciones_germinacion_plot <- renderPlot({
        x <- fit_germinacion
        plot_model(x)
      })

      # estimaciones hojas
      output$estimaciones_hojas_table <- render_gt({
        x <- brms::ranef(fit_hojas)$especie[,,"Intercept"]+fixef(fit_hojas)[1]
        tbl <- as.data.frame(x, row.names = row.names(x)) %>%
          rownames_to_column("especie") %>%
          gt() %>%
          fmt_number(Estimate:Q97.5) %>%
          cols_merge(Q2.5:Q97.5, pattern = "[{1}, {2}]") %>%
          cols_label(
            especie = md("**Especie**"),
            Estimate = md("***Media***"),
            Est.Error = md("***SE***"),
            Q2.5 = md("**95% *CrI***")
          )
        return(tbl)
      })

      output$estimaciones_hojas_plot <- renderPlot({
        x <- fit_hojas
        plot_model(x)
      })

      # estimaciones cosecha
      output$estimaciones_cosecha_table <- render_gt({
        x <- brms::ranef(fit_cosecha)$especie[,,"Intercept"]+fixef(fit_cosecha)[1]
        tbl <- as.data.frame(x, row.names = row.names(x)) %>%
          rownames_to_column("especie") %>%
          gt() %>%
          fmt_number(Estimate:Q97.5) %>%
          cols_merge(Q2.5:Q97.5, pattern = "[{1}, {2}]") %>%
          cols_label(
            especie = md("**Especie**"),
            Estimate = md("***Media***"),
            Est.Error = md("***SE***"),
            Q2.5 = md("**95% *CrI***")
          )
        return(tbl)
      })

      output$estimaciones_cosecha_plot <- renderPlot({
        x <- fit_cosecha
        plot_model(x)
      })

      ## siembra ----
      observeEvent(input$database_nueva_siembra, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_row(
          con, "plantas",
          id = input$database_siembra_id,
          especie = input$database_siembra_especie,
          variedad = input$database_siembra_variedad,
          marca = input$database_siembra_marca,
          planta_tipo = input$database_siembra_planta_tipo
        )
        db_add_row(
          con, "siembras",
          id = input$database_siembra_id,
          fecha_siembra = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          medio_siembra = input$database_siembra_medio_siembra,
          peso = input$database_siembra_peso,
          luz = input$database_siembra_luz,
          calor = input$database_siembra_calor,
          domo = input$database_siembra_domo,
          peso_semillas = input$database_siembra_peso_semillas,
          comentarios = input$database_siembra_comentarios
        )

        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        remove_modal_spinner()
        session$reload()
      })

      observeEvent(input$database_siembra_eliminar_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_delete_row(con, "siembras", input$database_eliminar_siembra_id)
        db_delete_row(con, "plantas", input$database_eliminar_siembra_id)
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        session$reload()
        remove_modal_spinner()
      })

      observeEvent(input$database_siembra_nuevo_especie_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "se
                           mipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_values(con, "especie", input$database_siembra_nuevo_especie)
        remove_modal_spinner()
        values <<- db_db_get_values(con)
        session$reload()
      })

      observeEvent(input$database_siembra_nuevo_variedad_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_db_add_values(con, "variedad", input$database_siembra_nuevo_variedad)
        remove_modal_spinner()
        values <<- db_db_get_values(con)
        session$reload()
      })

      observeEvent(input$database_siembra_nuevo_marca_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_db_add_values(con, "marca", input$database_siembra_nuevo_marca)
        remove_modal_spinner()
        values <<- db_db_get_values(con)
        session$reload()
      })

      observeEvent(input$database_siembra_nuevo_medio_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_values(con, "medio_siembra", input$database_siembra_nuevo_medio)
        remove_modal_spinner()
        values <<- db_get_values(con)
        session$reload()
      })

      observeEvent(input$database_siembra_nuevo_tipo_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_values(con, "planta_tipo", input$database_siembra_nuevo_tipo)
        remove_modal_spinner()
        values <<- db_get_values(con)
        session$reload()
        remove_modal_spinner()
      })

      output$siembra_table <- DT::renderDataTable({
        x <- d_all  %>%
          drop_na(fecha_siembra) %>%
          select(id, especie, variedad, marca, luz, calor, domo, medio_siembra) %>%
          DT::datatable(
            colnames = c("Especie", "Variedad", "Marca", "Luz", "Calor", "Domo", "Medio de siembra"),
            caption = "Estadisticas de siembra.",
            options = list(autoWidth = TRUE, searching = FALSE),
            rownames = FALSE
          )
        return(x)
      })

      ## germinacion ------------
      observeEvent(input$database_nueva_germinacion, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_row(
          con, "germinaciones",
          id = input$database_germinacion_id,
          fecha_germinacion = format(Sys.time(), "%Y-%m-%d %H:%M:%D"),
          comentarios = input$database_germinacion_comentarios
        )
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        remove_modal_spinner()
        session$reload()
      })

      observeEvent(input$database_germinacion_eliminar_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_delete_row(con, "germinaciones", input$database_eliminar_germinacion_id)
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, data)
        remove_modal_spinner()
        session$reload()
      })

      output$germinacion_table <- DT::renderDataTable({
        x <- d_all %>%
          mutate(
            planta = paste0(especie, " (", variedad, ")"),
            t_germinacion = difftime(fecha_germinacion, fecha_siembra, units = "days")
          ) %>%
          drop_na(t_germinacion) %>%
          select(id, planta, medio_siembra, t_germinacion) %>%
          group_by(planta, medio_siembra) %>%
          summarise(
            n = n(),
            t_germinacion = mean(t_germinacion, na.rm = TRUE),
            sd_t_germinacion = sd(t_germinacion, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          relocate(planta, medio_siembra, n) %>%
          mutate(se_t_germinacion = sd_t_germinacion/sqrt(n)) %>%
          DT::datatable(
            colnames = c("Especie (variedad)", "Medio siembra", "N", "Media", "DE", "EE"),
            caption = "Estadisticas de germinacion (horas). DE: desviacion estandar. EE: error estandar",
            options = list(autoWidth = TRUE, searching = FALSE),
            rownames = FALSE
          )
        return(x)
      })

      ## hojas ----------
      observeEvent(input$database_nuevas_hojas, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_row(
          con, "hojas",
          id = input$database_hojas_id,
          fecha_hojas = format(Sys.time(), "%Y-%m-%d %H:%M:%D"),
          comentarios = input$database_hojas_comentarios
        )
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, data)
        remove_modal_spinner()
        session$reload()
      })

      observeEvent(input$database_hojas_eliminar_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_delete_row(con, "hojas", input$database_eliminar_hojas_id)
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        remove_modal_spinner()
        session$reload()
      })

      output$hojas_table <- DT::renderDataTable({
        x <- d_all  %>%
          mutate(
            planta = paste0(especie, " (", variedad, ")"),
            t_hojas = difftime(fecha_hojas, fecha_siembra, units = "days")
          ) %>%
          drop_na(t_hojas) %>%
          select(id, planta, medio_siembra, t_hojas) %>%
          group_by(planta, medio_siembra) %>%
          summarise(
            n = n(),
            t_hojas = mean(t_hojas, na.rm = TRUE),
            sd_t_hojas = sd(t_hojas, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          relocate(planta, medio_siembra, n) %>%
          mutate(se_t_hojas = sd_t_hojas/sqrt(n)) %>%
          DT::datatable(
            colnames = c("Especie (variedad)", "Medio siembra", "N", "Media", "DE", "EE"),
            caption = "Estadisticas de hojas (horas). DE: desviacion estandar. EE: error estandar",
            options = list(autoWidth = TRUE, searching = FALSE),
            rownames = FALSE
          )
        return(x)
      })



      ## cosecha ---------
      observeEvent(input$database_nueva_cosecha, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_add_row(
          con, "cosechas",
          id = input$database_cosecha_id,
          fecha_cosecha = format(Sys.time(), "%Y-%m-%d %H:%M:%D"),
          comentarios = input$database_cosecha_comentarios
        )
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        session$reload()
        remove_modal_spinner()
      })

      observeEvent(input$database_cosecha_eliminar_button, {
        Sys.sleep(1.5)
        show_modal_spinner(spin = "semipolar", color = "DeepSkyBlue", text = "Cargando")
        db_delete_row(con, "cosechas", input$database_eliminar_cosecha_id)
        d <<- db_get_data(con)
        d_all <<- db_summarise(con, d)
        remove_modal_spinner()
        session$reload()
      })

      output$cosecha_table <- DT::renderDataTable({
        x <- d_all  %>%
          mutate(
            planta = paste0(especie, " (", variedad, ")"),
            t_cosecha = difftime(fecha_cosecha, fecha_siembra, units = "days")
          ) %>%
          drop_na(t_cosecha) %>%
          select(id, planta, medio_siembra, t_cosecha) %>%
          group_by(planta, medio_siembra) %>%
          summarise(
            n = n(),
            t_cosecha = mean(t_cosecha, na.rm = TRUE),
            sd_t_cosecha = sd(t_cosecha, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          relocate(planta, medio_siembra, n) %>%
          mutate(se_t_cosecha = sd_t_cosecha/sqrt(n)) %>%
          DT::datatable(
            colnames = c("Especie (variedad)", "Medio siembra", "N", "Media", "DE", "EE"),
            caption = "Estadisticas de cosecha (horas). DE: desviacion estandar. EE: error estandar",
            options = list(autoWidth = TRUE, searching = FALSE),
            rownames = FALSE
          )
        return(x)
      })
  }

    )
