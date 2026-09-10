# 🥣 Cereal Nutrients!

An interactive R Shiny dashboard for exploring nutrition data across 80 breakfast cereals — compare brands, mix your own custom bowl, and play a nutrition-based guessing game.

**Live app:** https://019ddfd6-4b5c-a1ae-787f-d6c2c3c046de.share.connect.posit.cloud/

## Features

- **Cereal Home** — a landing page introducing the app and listing all 80 cereals in the dataset.
- **Cereal Data Explorer** — filter by manufacturer, plot any two nutritional metrics against each other on an interactive scatterplot, highlight specific cereals, view a stacked macronutrient breakdown, and browse the raw data in a sortable table.
- **Mix & Match** — pick up to three cereals, adjust servings with sliders, and see the combined calories, sugar, and protein for your custom bowl, plus a pie chart of its macro breakdown.
- **Cereal Game: Blind Taste Test!** — draw a random "mystery" cereal, view its macros, and guess which cereal it is.

## Design choices

- **Theme:** [bslib](https://rstudio.github.io/bslib/) `sketchy` bootswatch theme, chosen for a fun, lighthearted feel to match the subject matter.
- **Color palettes:** `viridis` (plasma) and `PiYG` were used for scatterplots and macro charts to keep visualizations colorblind-accessible while still fitting the playful theme.
- **Value boxes:** styled with gradient themes for a warm, welcoming look.
- **Interactivity:** built with [plotly](https://plotly.com/r/) for hoverable tooltips throughout, and reactive UI elements (sliders, dynamic selectors, modals) for the Mix & Match and Game pages.

## Data

Data comes from the [80 Cereals dataset on Kaggle](https://www.kaggle.com/datasets/crawford/80-cereals).

The app expects a `cereal.csv` file in the same directory as `app.R`, containing (at minimum) the following columns: `name`, `mfr`, `calories`, `carbo`, `rating`, `fat`, `fiber`, `potass`, `protein`, `sodium`, `sugars`.

## Running locally

1. Clone this repo.
2. Make sure `cereal.csv` is in the same folder as `app.R`.
3. Install the required R packages:

   ```r
   install.packages(c("dplyr", "ggplot2", "shiny", "bslib", "thematic", "plotly", "tidyr", "bsicons", "readr"))
   ```

4. Open `app.R` in RStudio and click **Run App**, or run:

   ```r
   shiny::runApp()
   ```

## Deploying updates

This app is deployed via Posit Connect Cloud. To push changes:

```r
library(rsconnect)
rsconnect::deployApp()
```

## Tech stack

R · Shiny · bslib · plotly · dplyr · ggplot2 · tidyr

## GAI use

Generative AI was used to look up Shiny/bslib function documentation, color palette options, and to help implement the reactive gamified feature (buttons, dynamic selection, pop-up modals) alongside course materials.