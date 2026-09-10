library(dplyr)
library(ggplot2)
library(shiny)
library(bslib)
library(thematic)
library(plotly)
library(tidyr)

# DATA SETUP -------------------------------------------------------------

stopifnot(
  "cereal.csv not found in the app directory" = file.exists("cereal.csv")
)
cereal <- readr::read_csv("cereal.csv")

mfr_map <- c(
  "A" = "American Home Food Products",
  "G" = "General Mills",
  "K" = "Kelloggs",
  "N" = "Nabisco",
  "P" = "Post",
  "Q" = "Quaker Oats",
  "R" = "Ralston Purina"
)

cereal <- cereal |>
  mutate(mfr_name = mfr_map[mfr])

if (anyDuplicated(cereal$name) > 0) {
  warning("cereal$name has duplicate values \u2014 Mix & Match totals key on the ",
          "first matching row for each selected name.")
}

nutritional_vars <- c(
  "Calories" = "calories",
  "Carbohydrates (g)" = "carbo",
  "Consumer Rating (x/100)" = "rating",
  "Fat (g)" = "fat",
  "Fiber (g)" = "fiber",
  "Potassium (mg)" = "potass",
  "Protein (g)" = "protein",
  "Sodium (mg)" = "sodium",
  "Sugar (g)" = "sugars"
)

# One shared palette for Carbs/Protein/Fat, used everywhere a macro
# breakdown is drawn (macro_chart, bowl_chart, mystery_pie) so colors
# stay consistent across the app.
macro_colors <- c(
  "Carbohydrates" = "#C51B7DFF",
  "Protein" = "#F1B6DAFF",
  "Fat" = "#7FBC41FF"
)

# Pages --------------------------------------------------------------------
ui <- page_navbar(
  title = "Cereal Nutrients!",
  theme = bs_theme(bootswatch = "sketchy"),

  # Page 1 --> Landing Page
  nav_panel(
    title = "Cereal Home",
    tags$div(
      class = "container text-center mt-5",
      tags$h1("Learn About These Cereals!!", class = "mb-4"),
      tags$p("Welcome to the Cereal Universe!
             Check out the full list of our 80 cereals below.
             When you are ready, use the navigation tabs at the top of the
             page to explore the data, mix your own breakfast bowl, or play a
             guessing game!", class = "lead mb-5"),

      card(
        card_header("The Cereal Database", class = "bg-primary text-white"),
        card_body(
          uiOutput("landing_cereal_list")
        )
      )
    )
  ),

  # Page 2: Data Explorer
  nav_panel(
    title = "Cereal Data Explorer",
    layout_sidebar(
      sidebar = sidebar(
        title = "Dashboard Controls",

        selectInput(
          "mfr",
          "Select Manufacturer(s)",
          choices = sort(unique(cereal$mfr_name)),
          selected = c("General Mills"),
          multiple = TRUE
        ),
        ## Choosing x-axis
        selectInput(
          "x_var",
          "Select X-Axis Metric",
          choices = nutritional_vars,
          selected = "sugars"
        ),
        ## Choosing y-axis
        selectInput(
          "var",
          "Select Y-Axis Metric",
          choices = nutritional_vars,
          selected = "calories"
        ),
        hr(),
        uiOutput("cereal_selector"),
        hr(),
        tags$div(
          class = "mt-auto",
          tags$small(
            "Data Source: ",
            tags$a(
              href = "https://www.kaggle.com/datasets/crawford/80-cereals",
              "Kaggle",
              target = "_blank"
            )
          )
        )
      ),

      uiOutput("valueboxes"),

      navset_card_tab(
        full_screen = TRUE,
        nav_panel(
          "Scatter Visualization",
          card_header(textOutput("plot_title")),
          card_body(plotlyOutput("plot"))
        ),
        nav_panel(
          "Macro Composition",
          card_header("Macronutrient Breakdown (Grams)"),
          card_body(plotlyOutput("macro_chart"))
        ),
        nav_panel(
          "Raw Data",
          card_body(tableOutput("preview_table"))
        )
      )
    )
  ),

  # Page 3: Mix and Match -- Combine Cereals Together
  nav_panel(
    title = "Mix & Match",
    layout_sidebar(
      sidebar = sidebar(
        title = "Recipe Mixer",
        helpText("Select up to 3 cereals to mix into one ultimate breakfast bowl!"),
        selectizeInput(
          "mix_cereals",
          "Choose Your Ingredients:",
          choices = sort(cereal$name),
          multiple = TRUE,
          options = list(maxItems = 3)
        ),
        hr(),
        # sliders for however many cereals they pick
        uiOutput("serving_sliders")
      ),
      card(
        card_header("Your Custom Cereal Bowl Nutrition"),
        layout_columns(
          value_box(
            "Total Calories",
            textOutput("bowl_cal"),
            showcase = bsicons::bs_icon("fire"),
            theme = "bg-gradient-indigo-blue"
          ),
          value_box(
            "Total Sugar (g)",
            textOutput("bowl_sugar"),
            showcase = bsicons::bs_icon("cup-hot"),
            theme = "bg-gradient-orange-pink"
          ),
          value_box(
            "Total Protein (g)",
            textOutput("bowl_protein"),
            showcase = bsicons::bs_icon("lightning"),
            theme = "bg-gradient-pink-indigo"
          )
        ),
        card_body(plotlyOutput("bowl_chart"))
      )
    )
  ),

  # Page 4: GAMEEEE Mixing Different Cereals
  nav_panel(
    title = "Cereal Game: Blind Taste Test!",
    page_fillable(
      layout_columns(
        card(
          card_header("Can you guess the cereal based only on its macros?"),
          card_body(
            actionButton("new_mystery", "Draw a Mystery Cereal!", class = "btn-primary mb-3"),
            tableOutput("mystery_stats_table"),
            hr(),
            selectizeInput("guess", "What Cereal Am I?", choices = sort(cereal$name), selected = NULL),
            actionButton("submit_guess", "Submit Guess!", class = "btn-success btn-lg")
          )
        ),
        card(
          card_header("Mystery Macros"),
          card_body(plotlyOutput("mystery_pie"))
        )
      )
    )
  )
)

# SERVER ---------------------------------------------------------------
server <- function(input, output, session) {
  thematic_shiny()

  # ---- Page 2: Cereal Data Explorer ----

  d_filtered <- reactive({
    req(input$mfr)
    cereal |>
      filter(mfr_name %in% input$mfr)
  })

  output$cereal_selector <- renderUI({
    req(input$mfr)
    selectInput(
      "selected_cereal",
      "Highlight Cereal(s)",
      choices = sort(d_filtered()$name),
      selected = NULL,
      multiple = TRUE
    )
  })

  output$valueboxes <- renderUI({
    # Guard against an empty filter result (e.g. all manufacturers
    # deselected), which would otherwise show "NaN" in every box.
    req(input$mfr, nrow(d_filtered()) > 0)

    layout_columns(
      value_box(
        "Avg Rating (x/100)",
        round(mean(d_filtered()$rating, na.rm = TRUE), 1),
        showcase = bsicons::bs_icon("star-fill"),
        theme = "bg-gradient-indigo-blue"
      ),
      value_box(
        "Avg Calories",
        round(mean(d_filtered()$calories, na.rm = TRUE), 1),
        showcase = bsicons::bs_icon("fire"),
        theme = "bg-gradient-orange-pink"
      ),
      value_box(
        "Avg Sugar (g)",
        round(mean(d_filtered()$sugars, na.rm = TRUE), 1),
        showcase = bsicons::bs_icon("cake"),
        theme = "bg-gradient-pink-indigo"
      )
    )
  })

  output$plot_title <- renderText({
    paste(
      names(nutritional_vars)[nutritional_vars == input$var],
      "vs.", names(nutritional_vars)[nutritional_vars == input$x_var]
    )
  })

  output$plot <- renderPlotly({
    has_selection <- !is.null(input$selected_cereal) && length(input$selected_cereal) > 0
    y_name <- names(nutritional_vars)[nutritional_vars == input$var]
    x_name <- names(nutritional_vars)[nutritional_vars == input$x_var]

    # Single shared path for both "nothing highlighted" and "cereals
    # highlighted" cases, instead of two near-duplicate ggplot() calls.
    plot_data <- d_filtered() |>
      mutate(
        point_alpha = if (has_selection) ifelse(name %in% input$selected_cereal, 1.0, 0.75) else 1,
        point_size  = if (has_selection) ifelse(name %in% input$selected_cereal, 4, 2) else 3
      )

    p <- ggplot(
      plot_data,
      aes(
        x = .data[[input$x_var]],
        y = .data[[input$var]],
        color = mfr_name,
        text = name,
        alpha = I(point_alpha),
        size = I(point_size)
      )
    ) +
      geom_point() +
      theme_minimal() +
      scale_color_viridis_d(option = "plasma", begin = 0.1, end = 0.85) +
      labs(x = x_name, y = y_name, color = "Brand")

    ggplotly(p, tooltip = c("text", "x", "y")) |>
      layout(hovermode = "closest")
  })

  output$macro_chart <- renderPlotly({
    req(input$selected_cereal)
    macro_df <- cereal |>
      filter(name %in% input$selected_cereal) |>
      select(name, Carbohydrates = carbo, Protein = protein, Fat = fat) |>
      pivot_longer(cols = c(Carbohydrates, Protein, Fat), names_to = "Nutrient", values_to = "Grams")

    p <- ggplot(
      macro_df,
      aes(
        x = name,
        y = Grams,
        fill = Nutrient,
        text = paste(Nutrient, ":", Grams, "g")
      )
    ) +
      geom_bar(stat = "identity", position = "stack", width = 0.6) +
      theme_minimal() +
      scale_fill_manual(values = macro_colors) +
      labs(x = NULL, y = "Grams") +
      theme(axis.text.x = element_text(hjust = 1))

    ggplotly(p, tooltip = "text") |> layout(barmode = "stack")
  })

  output$preview_table <- renderTable({
    d_filtered() |>
      select(
        Cereal = name,
        Brand = mfr_name,
        Calories = calories,
        Protein = protein,
        Fat = fat,
        Carbs = carbo,
        Sugars = sugars,
        Rating = rating
      ) |>
      arrange(Brand, Cereal)
  })

  # ---- Page 3: Mix & Match ----

  output$serving_sliders <- renderUI({
    req(input$mix_cereals)
    lapply(input$mix_cereals, function(c_name) {
      sliderInput(
        inputId = paste0("serve_", make.names(c_name)),
        label = paste("Servings of", c_name),
        min = 0.5, max = 3, value = 1, step = 0.5
      )
    })
  })

  # Combined nutrition for the bowl. Vectorized instead of a manual
  # accumulator loop, and uses slice(match(...)) so a duplicate cereal
  # name in the source data can't get double-counted.
  bowl_totals <- reactive({
    req(input$mix_cereals)

    servings <- vapply(input$mix_cereals, function(c_name) {
      s <- input[[paste0("serve_", make.names(c_name))]]
      if (is.null(s)) 1 else s
    }, numeric(1))

    cereal |>
      filter(name %in% input$mix_cereals) |>
      slice(match(input$mix_cereals, name)) |>
      mutate(across(c(calories, sugars, protein, fat, carbo), ~ .x * servings)) |>
      summarise(
        cal = sum(calories),
        sug = sum(sugars),
        pro = sum(protein),
        fat = sum(fat),
        carb = sum(carbo)
      ) |>
      as.list()
  })

  output$bowl_cal <- renderText({ bowl_totals()$cal })
  output$bowl_sugar <- renderText({ bowl_totals()$sug })
  output$bowl_protein <- renderText({ bowl_totals()$pro })

  output$bowl_chart <- renderPlotly({
    req(input$mix_cereals)
    m_df <- data.frame(
      Nutrient = c("Carbohydrates", "Protein", "Fat"),
      Grams = c(bowl_totals()$carb, bowl_totals()$pro, bowl_totals()$fat)
    )
    plot_ly(
      m_df,
      labels = ~Nutrient,
      values = ~Grams,
      type = "pie",
      textinfo = "label+percent",
      marker = list(colors = macro_colors[m_df$Nutrient])
    ) |>
      layout(title = "Bowl Macro Breakdown")
  })

  # ---- Page 4: Cereal Game ----

  mystery_cereal <- reactiveVal()

  # Drawing a random cereal when button is clicked (and once on startup)
  observeEvent(input$new_mystery, {
    mystery_cereal(cereal |> sample_n(1))
    updateSelectizeInput(session, "guess", selected = "")
  }, ignoreNULL = FALSE)

  output$mystery_stats_table <- renderTable({
    req(mystery_cereal())
    mystery_cereal() |>
      select(
        Calories = calories,
        Sugars = sugars,
        Fiber = fiber,
        Sodium = sodium,
        Rating = rating
      )
  })

  output$mystery_pie <- renderPlotly({
    req(mystery_cereal())
    m_df <- data.frame(
      Nutrient = c("Carbohydrates", "Protein", "Fat"),
      Grams = c(mystery_cereal()$carbo, mystery_cereal()$protein, mystery_cereal()$fat)
    )

    plot_ly(
      m_df,
      labels = ~Nutrient,
      values = ~Grams,
      type = "pie",
      textinfo = "value",
      marker = list(colors = macro_colors[m_df$Nutrient])
    ) |>
      layout(showlegend = TRUE)
  })

  # Check the answer --> trigger a pop-up modal
  observeEvent(input$submit_guess, {
    req(input$guess, mystery_cereal())
    actual_name <- mystery_cereal()$name

    if (input$guess == actual_name) {
      title_text <- "Correct!!!!!!!!!!!!"
      body_text <- paste("Amazing! It was indeed", actual_name)
    } else {
      title_text <- "WRONGGG! Not quite!"
      body_text <- paste("You guessed", input$guess, "but the correct answer was", actual_name)
    }

    showModal(modalDialog(
      title = title_text,
      body_text,
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })

  output$landing_cereal_list <- renderUI({
    tags$div(
      class = "d-flex flex-wrap justify-content-center",
      lapply(sort(cereal$name), function(cereal_name) {
        tags$span(
          class = "badge bg-dark m-1 p-2",
          style = "font-size: 14px; font-weight: normal;",
          cereal_name
        )
      })
    )
  })
}

shinyApp(ui, server)