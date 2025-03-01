
## 1) EINLEITUNG UND PAKET-LADEBEREICH ----


# In diesem Abschnitt werden alle grundlegenden Dinge für unsere Shiny-App
# vorbereitet. Dazu zählen:
# - Laden der benötigten R-Pakete (z. B. shiny, DT, openxlsx)
# - Definieren von globalen Variablen und Pfaden
# - Hinterlegen des Google-API-Keys (für Google Translate)
# - Definition von Custom-CSS, um das Layout zu gestalten

library(shiny)        # Hauptpaket für Shiny-Apps
library(shinythemes)  # Ermöglicht die Nutzung von Themes (z. B. flatly)
library(httr)         # Für HTTP-Anfragen (z. B. POST an Google-Translate-API)
library(jsonlite)     # Zum Verarbeiten von JSON-Antworten (Google Translate)
library(openxlsx)     # Zum Lesen/Schreiben von Excel-Dateien
library(DT)           # Für DataTables (interaktive Tabellen in Shiny)
library(stringr)      # Praktische String-Funktionen
library(ggplot2)      # Plotten von Diagrammen (z. B. Quiz-Verläufe)


## 1.1) Google-API-Key ----

# Bitte hier deinen eigenen Google-API-Key eintragen, damit die
# Übersetzungsfunktion (Google Translate) funktioniert.

API_KEY <- "AIzaSyDR3-F8HnlRYBSjgAISHxR5VjYrKMlNuxY"


## 1.2) Custom-CSS ----

# Im folgenden String customCSS definieren wir einige CSS-Regeln,
# um das Erscheinungsbild der Shiny-App anzupassen (z. B. Buttons,
# Tabs, Tabellenbreite usw.).

customCSS <- "
/* Allgemeine Schriftart */
body {
  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
}
/* Hintergründe für wellPanels */
.well {
  background-color: #f9f9f9;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 10px;
  margin-bottom: 10px;
}
/* Buttons in der linken Spalte */
#leftButtons .btn {
  margin-right: 5px;
  margin-bottom: 5px;
}
/* Tabs-Layout: Deutlichere Register */
.nav-tabs > li > a {
  font-weight: bold;
  background-color: #e8e8e8;
  color: #333;
  margin-right: 2px;
  border: 1px solid #ccc;
}
.nav-tabs > li.active > a,
.nav-tabs > li.active > a:focus,
.nav-tabs > li.active > a:hover {
  background-color: #fff;
  color: #000;
  border: 1px solid #ccc;
}
.tab-content {
  margin-top: 15px;
}
/* Buchstaben-Filter: kompakte Anordnung */
.letters-row .checkbox-inline {
  margin-right: 8px;
  margin-bottom: 4px;
}
/* Verkleinert die maximale Breite von DT-Tabellen */
.dataTables_wrapper {
  max-width: 1000px;
}
/* Quiz-Buttons im Tab */
.quiz-btn {
  margin-right: 10px;
  margin-bottom: 5px;
}
"


# 2) FUNKTIONEN ZUM LADEN UND SPEICHERN VON XLSX-DATEIEN ----

# In diesem Abschnitt werden sämtliche Hilfsfunktionen definiert, die für das
# Laden und Speichern verschiedener Excel-Dateien (Settings, Queries, Quiz-Logs)
# verantwortlich sind. Dadurch können wir an anderer Stelle diese Funktionen
# einfach aufrufen, ohne den Code zu duplizieren.




## 2.1) SETTINGS (INDEX, LOAD, SAVE) ----

settings_index_path <- "settings_index.xlsx"

loadSettingsIndex <- function(){
  # Prüfen, ob die Datei 'settings_index.xlsx' existiert.
  # Falls nicht, geben wir ein leeres DataFrame zurück.
  if(!file.exists(settings_index_path)){
    df <- data.frame(
      SettingName = character(),
      FilePath    = character(),
      Archived    = logical(),
      stringsAsFactors = FALSE
    )
    return(df)
  } else {
    # Ansonsten laden wir das Excel und prüfen, ob die Spalten "SettingName",
    # "FilePath" und "Archived" vorhanden sind. Wenn nicht, werden sie angelegt.
    df <- openxlsx::read.xlsx(settings_index_path, sheet = 1)
    needed <- c("SettingName", "FilePath", "Archived")
    for(nc in needed){
      if(!nc %in% names(df)) df[[nc]] <- NA
    }
    df <- df[, needed, drop = FALSE]
    return(df)
  }
}

saveSettingsIndex <- function(df){
  # Speichert den DataFrame 'df' wieder in die Datei 'settings_index.xlsx'.
  # Dabei achten wir darauf, dass die Spalten "SettingName", "FilePath" und
  # "Archived" existieren.
  needed <- c("SettingName", "FilePath", "Archived")
  for(nc in needed){
    if(!nc %in% names(df)) df[[nc]] <- NA
  }
  df <- df[, needed, drop = FALSE]
  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  saveWorkbook(wb, settings_index_path, overwrite = TRUE)
}

loadSettingData <- function(settingName){
  # Lädt die Daten zu einem konkreten Setting. Dafür schlagen wir im
  # settings_index.xlsx nach, wo die Datei liegt (FilePath).
  # Wenn kein aktives Setting oder archiviert => leeres DataFrame.
  si <- loadSettingsIndex()
  rowMatch <- si[si$SettingName == settingName & si$Archived == FALSE, ]
  if(nrow(rowMatch) == 0){
    return(data.frame(
      Zeitstempel   = character(),
      Sprache       = character(),
      Original      = character(),
      Uebersetzung  = character(),
      Wortkategorie = character(),
      Bemerkungen   = character(),
      stringsAsFactors = FALSE
    ))
  }
  path <- rowMatch$FilePath[1]
  if(!file.exists(path)){
    # Falls Datei noch nicht existiert, leeres DF
    df <- data.frame(
      Zeitstempel   = character(),
      Sprache       = character(),
      Original      = character(),
      Uebersetzung  = character(),
      Wortkategorie = character(),
      Bemerkungen   = character(),
      stringsAsFactors = FALSE
    )
    return(df)
  } else {
    # Datei existiert => laden und Spalten prüfen
    df <- openxlsx::read.xlsx(path, sheet = 1)
    needed <- c("Zeitstempel","Sprache","Original","Uebersetzung","Wortkategorie","Bemerkungen")
    for(nc in needed){
      if(!nc %in% names(df)) df[[nc]] <- NA_character_
    }
    df <- df[, needed, drop = FALSE]
    return(df)
  }
}

saveSettingData <- function(df, settingName){
  # Speichert die Daten eines konkreten Settings in dessen Excel-Datei.
  si <- loadSettingsIndex()
  rowMatch <- si[si$SettingName == settingName, ]
  if(nrow(rowMatch) == 0) return(NULL)
  path <- rowMatch$FilePath[1]
  needed <- c("Zeitstempel","Sprache","Original","Uebersetzung","Wortkategorie","Bemerkungen")
  for(nc in needed){
    if(!nc %in% names(df)) df[[nc]] <- NA_character_
  }
  df <- df[, needed, drop = FALSE]
  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  saveWorkbook(wb, path, overwrite = TRUE)
}


## 2.2) MY_QUERYS (ÜBERSETZUNGS-HISTORIE) ----

path_queries <- "my_querys.xlsx"

load_querys <- function(){
  # Lädt die Datei my_querys.xlsx oder gibt ein leeres DataFrame zurück,
  # falls sie noch nicht existiert.
  if(!file.exists(path_queries)){
    data.frame(
      Zeitstempel  = character(),
      Sprache      = character(),
      Original     = character(),
      Uebersetzung = character(),
      stringsAsFactors = FALSE
    )
  } else {
    df <- openxlsx::read.xlsx(xlsxFile = path_queries, sheet = 1)
    needed <- c("Zeitstempel","Sprache","Original","Uebersetzung")
    for(nc in needed){
      if(!nc %in% names(df)) df[[nc]] <- NA_character_
    }
    df <- df[, needed, drop = FALSE]
    df
  }
}

save_querys <- function(df){
  # Speichert den DataFrame df in die Datei my_querys.xlsx
  needed <- c("Zeitstempel","Sprache","Original","Uebersetzung")
  for(nc in needed){
    if(!nc %in% names(df)) df[[nc]] <- NA_character_
  }
  df <- df[, needed, drop = FALSE]
  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  saveWorkbook(wb, path_queries, overwrite = TRUE)
}


# 2.3) QUIZ-DATEN UND SESSION-HISTORY ----

quiz_log_path        <- "my_quizlog.xlsx"
session_history_path <- "my_session_history.xlsx"

load_quiz_data <- function(){
  # Lädt das Quiz-Log (alle bisherigen Quiz-Einträge).
  if(!file.exists(quiz_log_path)){
    data.frame(
      Zeitstempel         = character(),
      Abfragerichtung     = character(),
      Abfragewort         = character(),
      RichtigeUebersetzung= character(),
      MeineUebersetzung   = character(),
      Ergebnis            = character(),
      Setting             = character(),
      SettingNiveau       = character(),
      stringsAsFactors    = FALSE
    )
  } else {
    df <- openxlsx::read.xlsx(xlsxFile = quiz_log_path, sheet = 1)
    needed <- c("Zeitstempel","Abfragerichtung","Abfragewort",
                "RichtigeUebersetzung","MeineUebersetzung",
                "Ergebnis","Setting","SettingNiveau")
    for(nc in needed){
      if(!nc %in% names(df)) df[[nc]] <- NA_character_
    }
    df <- df[, needed, drop = FALSE]
    df
  }
}

save_quiz_data <- function(df){
  # Speichert den DataFrame df in das Quiz-Log (my_quizlog.xlsx)
  needed <- c("Zeitstempel","Abfragerichtung","Abfragewort",
              "RichtigeUebersetzung","MeineUebersetzung",
              "Ergebnis","Setting","SettingNiveau")
  for(nc in needed){
    if(!nc %in% names(df)) df[[nc]] <- NA_character_
  }
  df <- df[, needed, drop = FALSE]
  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  saveWorkbook(wb, quiz_log_path, overwrite = TRUE)
}

load_session_history <- function(){
  # Lädt die Historie aller Quiz-Sessions (Start-/Endzeiten, Anzahl etc.).
  if(!file.exists(session_history_path)){
    data.frame(
      SessionID     = integer(),
      Startzeit     = character(),
      Endzeit       = character(),
      Dauer         = character(),
      Anzahl        = integer(),
      Richtig       = integer(),
      Falsch        = integer(),
      QuoteRichtig  = character(),
      QuoteFalsch   = character(),
      Setting       = character(),
      DetailRichtig = character(),
      DetailFalsch  = character(),
      stringsAsFactors = FALSE
    )
  } else {
    df <- openxlsx::read.xlsx(xlsxFile = session_history_path, sheet = 1)
    needed <- c("SessionID","Startzeit","Endzeit","Dauer","Anzahl",
                "Richtig","Falsch","QuoteRichtig","QuoteFalsch","Setting",
                "DetailRichtig","DetailFalsch")
    for(nc in needed){
      if(!nc %in% names(df)) df[[nc]] <- NA_character_
    }
    df <- df[, needed, drop = FALSE]
    df
  }
}

save_session_history <- function(df){
  # Speichert den DataFrame df in die Datei my_session_history.xlsx
  needed <- c("SessionID","Startzeit","Endzeit","Dauer","Anzahl",
              "Richtig","Falsch","QuoteRichtig","QuoteFalsch","Setting",
              "DetailRichtig","DetailFalsch")
  for(nc in needed){
    if(!nc %in% names(df)) df[[nc]] <- NA_character_
  }
  df <- df[, needed, drop = FALSE]
  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  saveWorkbook(wb, session_history_path, overwrite = TRUE)
}


# 3) SHINY-UI (OBERFLÄCHE) ----

# In diesem Abschnitt wird das Layout (UI) unserer Shiny-App definiert.
# Wir legen fest, wie die App strukturiert ist (linke Spalte mit Eingaben,
# rechte Spalte mit Tabs usw.).



ui <- fluidPage(
  ## 3.1) Theme und Custom-CSS ----
  theme = shinytheme("flatly"),
  tags$head(tags$style(HTML(customCSS))),
  
  ## 3.2) Titelzeile ----
  titlePanel("Mein Übersetzer mit Settings & Quiz"),
  
  ## 3.3) Haupt-Layout: Zwei Spalten (fluidRow): ----
  #      Links => Settings-Wahl, Übersetzungs-Eingabe, Navigation
  #      Rechts => Aktuelle Übersetzung + Tabs (Settings, Queries, Quiz etc.)
  fluidRow(
    column(
      width = 3,
      ### 3.3.1) Wahl, ob vorhandenes Setting oder neues Setting
      wellPanel(
        radioButtons("settingChoice", "Was möchten Sie tun?",
                     choices = c("Vorhandenes Setting auswählen" = "existing",
                                 "Neues Setting erstellen" = "new"),
                     selected = "existing"),
        conditionalPanel(
          condition = "input.settingChoice == 'existing'",
          uiOutput("settingsDropdownUI")
        ),
        conditionalPanel(
          condition = "input.settingChoice == 'new'",
          textInput("newSettingName", "Neues Setting anlegen (Name):", ""),
          actionButton("createSettingBtn", "Neues Setting erstellen", class = "btn-success")
        )
      ),
      
      #### 3.3.2) Eingabe-Bereich für Übersetzungen (Eingabesprache, Text, Modus) ----
      wellPanel(
        h4("Einstellungen & Eingabe"),
        selectInput("lang_in", "Eingabesprache:",
                    choices = c("Deutsch" = "de", "Englisch" = "en",
                                "Französisch" = "fr", "Spanisch" = "es",
                                "Italienisch" = "it"),
                    selected = "de"),
        textAreaInput("text_in", "Zu übersetzender Text:",
                      "Hallo", width = "100%", height = "80px"),
        radioButtons("translate_mode", "Übersetzungsmodus:",
                     choices = c("Pro Zeile" = "linewise",
                                 "Ganze Textblöcke" = "block"),
                     selected = "linewise"),
        selectInput("target_langs", "Zielsprache(n):",
                    choices = c("Englisch"="en", "Französisch"="fr",
                                "Spanisch"="es", "Italienisch"="it"), 
                    selected = "en", multiple = TRUE),
        actionButton("go", "Übersetzen", class = "btn-primary"),
        br(), br(),
        actionButton("saveExcel", "Ergebnis speichern", class = "btn-success"),
        br(), br(),
        
        #### 3.3.3) Buchstaben-Filter für Übersetzungen ----
        strong("Buchstaben-Filter"),
        radioButtons("filterByCol", "Filter anwenden auf:",
                     choices = c("Original", "Uebersetzung"),
                     selected = "Original", inline = TRUE),
        div(
          class = "letters-row",
          checkboxGroupInput("letters_row0", label = NULL,
                             choices = c("Alle"), selected = "Alle", inline = TRUE),
          checkboxGroupInput("letters_row1", label = NULL,
                             choices = c("A","B","C","D","E","F","G","H"), inline = TRUE),
          checkboxGroupInput("letters_row2", label = NULL,
                             choices = c("I","J","K","L","M","N","O","P","Q"), inline = TRUE),
          checkboxGroupInput("letters_row3", label = NULL,
                             choices = c("R","S","T","U","V","W","X","Y","Z"), inline = TRUE),
          checkboxGroupInput("letters_row4", label = NULL,
                             choices = c("Ä","Ö","Ü"), inline = TRUE)
        ),
        uiOutput("langFilterUI")
      ),
      
      #### 3.3.4) Navigationstasten ----
      div(
        id = "leftButtons",
        actionButton("btnGoTranslate", "Übersetzen", class="btn-info"),
        actionButton("btnGoQuiz", "Quiz", class="btn-primary"),
        actionButton("btnGoSettings", "Settings verwalten", class="btn-success")
      )
    ),
    
    ## 3.4) Rechte Spalte: Anzeige der aktuellen Übersetzung + Tabs ----
    column(
      width = 9,
      h4("Aktuelle Übersetzung im Speicher:"),
      DTOutput("tbl_current"),
      
      tabsetPanel(
        id = "subTabs",
        
        #### 3.4.1) Tab 1: Anzeige gewähltes Setting ----
        tabPanel("Anzeige gewähltes Setting",
                 fluidRow(
                   column(6, actionButton("delRows", "Zeile löschen (Setting)", class = "btn-warning")),
                   column(6, p("Zellen direkt bearbeiten (Double-click)"))
                 ),
                 DTOutput("mainDT")
        ),
        
        #### 3.4.2) Tab 2: Alle bisherigen Übersetzungen ----
        tabPanel("Alle bisherigen Übersetzungen",
                 fluidRow(
                   column(6, actionButton("delQueries", "Zeile löschen (Queries)", class = "btn-warning")),
                   column(6,
                          fluidRow(
                            column(6, actionButton("showDuplicates", "Zeige Duplikate", class = "btn-info", width = "100%")),
                            column(6, actionButton("removeDuplicates", "Duplikate entfernen", class = "btn-danger", width = "100%"))
                          )
                   )
                 ),
                 br(),
                 DTOutput("myQueriesDT"),
                 br(),
                 h4("Gefundene Duplikate (Original == Übersetzung):"),
                 DTOutput("myQueriesDuplicates")
        ),
        
        #### 3.4.3) Tab 3: Quiz ----
        tabPanel("Quiz",
                 br(),
                 strong("Aktuell gewählte Abfragerichtung (Filter):"),
                 textOutput("quiz_mode_text"),
                 br(),
                 actionButton("startQuiz", "Session starten", class="btn btn-success quiz-btn"),
                 actionButton("quiz_check", "Prüfen", class="btn btn-warning quiz-btn"),
                 actionButton("endQuiz", "Session beenden", class="btn btn-danger quiz-btn"),
                 br(), br(),
                 strong("Aktuelles Wort/Satz:"),
                 textOutput("quiz_word"),
                 br(),
                 uiOutput("quiz_direction_UI"),
                 br(),
                 textOutput("quiz_feedback"),
                 br(),
                 h4("Aktuelle Quizsession"),
                 DTOutput("quizSessionDT"),
                 br(),
                 h4("Statistik Quizsession"),
                 tableOutput("quizStats"),
                 br(),
                 h4("Historie Abfragesession"),
                 fluidRow(
                   column(12, actionButton("delSessionHist", "Zeile löschen (Historie)", class="btn-warning"))
                 ),
                 br(),
                 DTOutput("sessionHistDT"),
                 br(),
                 h4("Quiz-Log"),
                 fluidRow(
                   column(6, actionButton("reloadQuizLog", "Neu laden", class="btn-secondary")),
                   column(6, actionButton("delQuizLog", "Zeile löschen (Quiz-Log)", class="btn-warning"))
                 ),
                 br(),
                 DTOutput("quizLogTable"),
                 br(),
                 h4("Grafische Statistik"),
                 plotOutput("quizPlot", height = "400px")
        ),
        
        #### 3.4.4) Tab 4: Settings verwalten ----
        tabPanel("Settings verwalten",
                 br(),
                 fluidRow(
                   column(6, actionButton("archiveSettingBtn", "Setting archivieren", class = "btn-warning")),
                   column(6, actionButton("deleteSettingBtn", "Setting löschen", class = "btn-danger"))
                 ),
                 br(),
                 DTOutput("settingsIndexDT")
        )
      )
    )
  )
)


# 4) SERVER-BEREICH ----

# Hier implementieren wir die eigentliche Logik der App:
# - Laden/Speichern von Settings
# - Übersetzungs-API-Aufrufe
# - Filtern von Tabellen
# - Quiz-Funktionalität (Start/Ende einer Session, Logging)
# - Einstellungen verwalten (Archivieren, Löschen)

server <- function(input, output, session){
  
  
  ## 4.1) Navigation per Buttons ----
  
  observeEvent(input$btnGoTranslate, {
    updateTabsetPanel(session, "subTabs", selected = "Anzeige gewähltes Setting")
  })
  observeEvent(input$btnGoQuiz, {
    updateTabsetPanel(session, "subTabs", selected = "Quiz")
  })
  observeEvent(input$btnGoSettings, {
    updateTabsetPanel(session, "subTabs", selected = "Settings verwalten")
  })
  
  
  ## 4.2) REACTIVE VALUES (Speicher für dynamische Daten) ----
  
  settingsIndexRV  <- reactiveVal(loadSettingsIndex())   # Liste aller Settings
  currentData      <- reactiveVal(data.frame())          # Letzte Übersetzung
  storedData       <- reactiveVal(data.frame())          # Daten des akt. Settings
  queryDataRV      <- reactiveVal(load_querys())         # Alle Übersetzungen (my_querys)
  myQueriesDuplicatesRV <- reactiveVal(data.frame())     # Duplikate in my_querys
  quizLogRV        <- reactiveVal(load_quiz_data())      # Komplettes Quiz-Log
  sessionHistRV    <- reactiveVal(load_session_history())# Historie der Quiz-Sessions
  quizSessionRV    <- reactiveVal(data.frame())          # Aktuelle Quiz-Session
  quizWordRV       <- reactiveVal(NULL)                  # Aktuelles Quiz-Wort
  quizSessionStart <- reactiveVal(NULL)                  # Startzeit der Quiz-Session
  quizStageRV      <- reactiveVal(FALSE)                 # Hilfsflag
  
  
  ## 4.3) SETTINGS DROPDOWN UND LADEN DES AKTUELLEN SETTINGS ----
  
  output$settingsDropdownUI <- renderUI({
    si <- settingsIndexRV()
    si_active <- si[si$Archived == FALSE, ]
    if(nrow(si_active)==0){
      tagList(p("Noch keine Settings vorhanden oder alle archiviert."))
    } else {
      selectInput("which_setting", "Vorhandenes Setting wählen:",
                  choices = si_active$SettingName,
                  selected = si_active$SettingName[1])
    }
  })
  
  observeEvent(list(settingsIndexRV(), input$which_setting), {
    req(input$which_setting)
    df <- loadSettingData(input$which_setting)
    storedData(df)
    # Falls Quizsession läuft => nächstes Wort ziehen
    if(!is.null(quizSessionStart())){
      getNextWord()
    }
  }, ignoreNULL = TRUE)
  
  
  ## 4.4) NEUES SETTING ERSTELLEN ----
  
  observeEvent(input$createSettingBtn, {
    newName <- trimws(input$newSettingName)
    if(nchar(newName) == 0){
      showNotification("Bitte einen Namen für das neue Setting eingeben!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    if(any(si$SettingName == newName)){
      showNotification("SettingName existiert bereits!", type = "error")
      return(NULL)
    }
    safeName <- gsub("[^a-zA-Z0-9_-]", "_", newName)
    filePath <- paste0("my_", safeName, ".xlsx")
    df_empty <- data.frame(
      Zeitstempel   = character(),
      Sprache       = character(),
      Original      = character(),
      Uebersetzung  = character(),
      Wortkategorie = character(),
      Bemerkungen   = character(),
      stringsAsFactors = FALSE
    )
    saveSettingData(df_empty, newName)
    newRow <- data.frame(
      SettingName = newName,
      FilePath    = filePath,
      Archived    = FALSE,
      stringsAsFactors = FALSE
    )
    si_new <- rbind(si, newRow)
    saveSettingsIndex(si_new)
    settingsIndexRV(si_new)
    showNotification(paste("Neues Setting angelegt:", newName), type = "message")
    updateTextInput(session, "newSettingName", value = "")
    updateRadioButtons(session, "settingChoice", selected = "existing")
  })
  
  
  ## 4.5) ÜBERSETZUNGS-FUNKTION (GOOGLE TRANSLATE) UND SPEICHERN IN my_querys ----
  
  output$tbl_current <- renderDT({
    df <- currentData()
    if(nrow(df) == 0){
      return(datatable(data.frame(`(Keine Daten)` = "Keine aktuelle Übersetzung"), 
                       options = list(dom = 't')))
    } else {
      datatable(df, extensions = c("Buttons"),
                options = list(autoWidth = TRUE, dom = "Bfrtip",
                               buttons = c("copy", "csv", "excel", "pdf", "print")))
    }
  })
  
  observeEvent(input$go, {
    req(input$which_setting)
    lines_in <- strsplit(input$text_in, "\n")[[1]]
    lines_in <- lines_in[lines_in != ""]
    if(length(lines_in)==0){
      showNotification("Keine Eingabezeilen!", type = "warning")
      currentData(data.frame())
      return(NULL)
    }
    src <- input$lang_in
    tg  <- setdiff(input$target_langs, src)
    if(length(tg)==0){
      showNotification("Keine Zielsprache gewählt (oder identisch mit Eingabesprache)!", type = "warning")
      currentData(data.frame())
      return(NULL)
    }
    base_url <- paste0("https://translation.googleapis.com/language/translate/v2?key=", API_KEY)
    mode <- input$translate_mode
    bigList <- list()
    
    # Unterscheidung: pro Zeile oder ganze Blöcke
    if(mode=="linewise"){
      for(ln in lines_in){
        for(tlang in tg){
          resp <- httr::POST(url = base_url,
                             body = list(q = ln, source = src, target = tlang, format = "text"),
                             encode = "json")
          cont <- httr::content(resp, as = "text", encoding = "UTF-8")
          js <- fromJSON(cont)
          if(!is.null(js$error)){
            showNotification(paste("API-Fehler:", js$error$message), type = "error")
            currentData(data.frame())
            return(NULL)
          }
          trText <- js$data$translations$translatedText[1]
          
          rowdf <- data.frame(
            Zeitstempel   = format(Sys.time(), "%d.%m.%Y_%H.%M.%S"),
            Sprache       = paste0(src, " - ", tlang),
            Original      = ln,
            Uebersetzung  = trText,
            Wortkategorie = "Unbekannt",
            Bemerkungen   = "",
            stringsAsFactors = FALSE
          )
          bigList[[length(bigList) + 1]] <- rowdf
        }
      }
    } else {
      # block-Modus
      block_txt <- paste(lines_in, collapse = "\n")
      for(tlang in tg){
        resp <- httr::POST(url = base_url,
                           body = list(q = block_txt, source = src, target = tlang, format = "text"),
                           encode = "json")
        cont <- httr::content(resp, as = "text", encoding = "UTF-8")
        js <- fromJSON(cont)
        if(!is.null(js$error)){
          showNotification(paste("API-Fehler:", js$error$message), type = "error")
          currentData(data.frame())
          return(NULL)
        }
        trText <- js$data$translations$translatedText[1]
        
        rowdf <- data.frame(
          Zeitstempel   = format(Sys.time(), "%d.%m.%Y_%H.%M.%S"),
          Sprache       = paste0(src, " - ", tlang),
          Original      = block_txt,
          Uebersetzung  = trText,
          Wortkategorie = "",
          Bemerkungen   = "",
          stringsAsFactors = FALSE
        )
        bigList[[length(bigList) + 1]] <- rowdf
      }
    }
    
    # Zusammenführen aller Zeilen
    df_out <- do.call(rbind, bigList)
    
    # Zeilen entfernen, in denen Original == Übersetzung
    dup_self <- tolower(trimws(df_out$Original)) == tolower(trimws(df_out$Uebersetzung))
    if(any(dup_self)){
      showNotification(paste(sum(dup_self), "Zeile(n) identisch => ignoriert."), type = "warning")
      df_out <- df_out[!dup_self, ]
    }
    
    # Speichern in my_querys, wenn nicht bereits vorhanden
    if(nrow(df_out) > 0){
      oldQ <- queryDataRV()
      combo_old <- paste(tolower(oldQ$Sprache), tolower(oldQ$Original), tolower(oldQ$Uebersetzung))
      combo_new <- paste(tolower(df_out$Sprache), tolower(df_out$Original), tolower(df_out$Uebersetzung))
      isdup_q   <- combo_new %in% combo_old
      if(any(isdup_q)){
        showNotification(paste(sum(isdup_q), 
                               "Zeile(n) bereits in my_querys => nicht erneut gespeichert."),
                         type = "warning")
      }
      df_qnew <- df_out[!isdup_q, c("Zeitstempel","Sprache","Original","Uebersetzung")]
      if(nrow(df_qnew) > 0){
        appendedQ <- rbind(oldQ, df_qnew)
        save_querys(appendedQ)
        queryDataRV(appendedQ)
        showNotification(paste(nrow(df_qnew), 
                               "Zeilen neu in my_querys.xlsx gespeichert."),
                         type = "message")
      }
    }
    
    # currentData updaten => Anzeige "Aktuelle Übersetzung im Speicher"
    currentData(df_out)
  })
  
  
  ## 4.6) ERGEBNISSE INS AKTIVE SETTING SPEICHERN ----
  
  observeEvent(input$saveExcel, {
    req(input$which_setting)
    df_tr <- currentData()
    if(nrow(df_tr)==0){
      showNotification("Keine Zeilen zum Speichern!", type = "warning")
      return(NULL)
    }
    old_stored <- storedData()
    combo_old <- paste(tolower(old_stored$Original), tolower(old_stored$Uebersetzung))
    combo_new <- paste(tolower(df_tr$Original), tolower(df_tr$Uebersetzung))
    isdup_s   <- combo_new %in% combo_old
    if(any(isdup_s)){
      showNotification(paste(sum(isdup_s), "Zeile(n) bereits im Setting => ignoriert."), type = "warning")
    }
    df_new <- df_tr[!isdup_s, ]
    if(nrow(df_new) == 0){
      showNotification("Alles war bereits im Setting vorhanden.", type = "warning")
      return(NULL)
    }
    appended <- rbind(old_stored, df_new)
    saveSettingData(appended, input$which_setting)
    storedData(appended)
    showNotification(paste(nrow(df_new), "Zeilen appended & gespeichert!"), type = "message")
    
    # currentData leeren
    currentData(data.frame())
  })
  
  
  ## 4.7) ALLE BISHERIGEN ÜBERSETZUNGEN (my_querys) ----
  
  output$myQueriesDT <- renderDT({
    datatable(queryDataRV(), selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 5, autoWidth = TRUE, dom = "Bfrtip",
                             buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  observeEvent(input$delQueries, {
    sel <- input$myQueriesDT_rows_selected
    if(length(sel)==0){
      showNotification("Keine Zeile in my_querys markiert!", type = "warning")
      return(NULL)
    }
    oldQ <- queryDataRV()
    newQ <- oldQ[-sel, ]
    queryDataRV(newQ)
    save_querys(newQ)
    showNotification(paste(length(sel), "Zeile(n) aus my_querys gelöscht!"), type = "message")
  })
  
  ### 4.7.1 Duplikate ----
  output$myQueriesDuplicates <- renderDT({
    datatable(myQueriesDuplicatesRV(), selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 5, autoWidth = TRUE, dom = "Bfrtip",
                             buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  observeEvent(input$showDuplicates, {
    dfQ <- queryDataRV()
    if(nrow(dfQ)==0){
      showNotification("my_querys ist leer => keine Duplikate", type = "warning")
      myQueriesDuplicatesRV(data.frame())
      return(NULL)
    }
    dupRows <- dfQ[dfQ$Original == dfQ$Uebersetzung, , drop = FALSE]
    if(nrow(dupRows)==0){
      showNotification("Keine Duplikate gefunden!", type = "message")
    } else {
      showNotification(paste(nrow(dupRows), "Duplikate gefunden!"), type = "message")
    }
    myQueriesDuplicatesRV(dupRows)
  })
  
  observeEvent(input$removeDuplicates, {
    dfQ <- queryDataRV()
    if(nrow(dfQ)==0){
      showNotification("my_querys ist leer => nichts zu entfernen", type = "warning")
      return(NULL)
    }
    keep <- (dfQ$Original != dfQ$Uebersetzung)
    removedCount <- sum(!keep)
    newQ <- dfQ[keep, ]
    if(removedCount>0){
      queryDataRV(newQ)
      save_querys(newQ)
      showNotification(paste(removedCount, "Duplikate entfernt!"), type = "message")
    } else {
      showNotification("Keine Duplikate gefunden => nichts entfernt!", type = "warning")
    }
    myQueriesDuplicatesRV(data.frame())
  })
  
  
  ## 4.8) BUCHSTABEN-FILTER UND SPRACH-FILTER (FÜR DAS ACTIVE SETTING) ----
  
  observeEvent(c(input$letters_row1, input$letters_row2, input$letters_row3, input$letters_row4), {
    sumLetters <- length(input$letters_row1) + length(input$letters_row2) +
      length(input$letters_row3) + length(input$letters_row4)
    if(sumLetters > 0){
      updateCheckboxGroupInput(session, "letters_row0", selected = character(0))
    }
  })
  observeEvent(input$letters_row0, {
    if("Alle" %in% input$letters_row0){
      updateCheckboxGroupInput(session, "letters_row1", selected = character(0))
      updateCheckboxGroupInput(session, "letters_row2", selected = character(0))
      updateCheckboxGroupInput(session, "letters_row3", selected = character(0))
      updateCheckboxGroupInput(session, "letters_row4", selected = character(0))
    }
  })
  
  output$langFilterUI <- renderUI({
    df_line <- storedData()
    if(nrow(df_line) == 0){
      ch <- "Keine Daten"
    } else {
      uspr <- unique(df_line$Sprache)
      ch <- sort(uspr)
    }
    ch <- c("Alle", ch)
    checkboxGroupInput("filter_sprachen",
                       "Filter nach Sprache (mehrfach möglich):",
                       choices = ch, selected = "Alle", inline = TRUE)
  })
  
  getFilteredData <- reactive({
    df <- storedData()
    if(nrow(df)==0) return(df[0,])
    colFilter <- ifelse(input$filterByCol == "Original", "Original", "Uebersetzung")
    let0 <- input$letters_row0
    let1 <- input$letters_row1
    let2 <- input$letters_row2
    let3 <- input$letters_row3
    let4 <- input$letters_row4
    if(!("Alle" %in% let0)){
      chosen <- c(let1, let2, let3, let4)
      if(length(chosen)==0){
        df <- df[0,]
      } else {
        firstChar <- substr(df[[colFilter]], 1, 1)
        df <- df[tolower(firstChar) %in% tolower(chosen), ]
      }
    }
    selLang <- input$filter_sprachen
    if(!is.null(selLang) && !("Alle" %in% selLang)){
      df <- df[df$Sprache %in% selLang, ]
    }
    df
  })
  
  output$mainDT <- renderDT({
    datatable(getFilteredData(), selection = "single", editable = TRUE, extensions = c("Buttons"),
              options = list(pageLength = 25, autoWidth = TRUE, dom = "Bfrtip",
                             buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  observeEvent(input$mainDT_cell_edit, {
    info <- input$mainDT_cell_edit
    df_filtered <- isolate(getFilteredData())
    df_full <- storedData()
    if(nrow(df_full)==0) return(NULL)
    i <- info$row; j <- info$col; v <- info$value
    rowNameFiltered <- rownames(df_filtered)[i]
    idxFull <- as.integer(rowNameFiltered)
    colN <- colnames(df_filtered)[j]
    df_full[idxFull, colN] <- v
    storedData(df_full)
    req(input$which_setting)
    saveSettingData(df_full, input$which_setting)
    showNotification(paste("Zelle geändert:", colN, "=>", v), type = "message")
  })
  
  observeEvent(input$delRows, {
    sel <- input$mainDT_rows_selected
    if(length(sel)==0){
      showNotification("Keine Zeile markiert!", type = "warning")
      return(NULL)
    }
    df_f <- getFilteredData()
    df_full <- storedData()
    rowNameFiltered <- rownames(df_f)[sel]
    idxFull <- as.integer(rowNameFiltered)
    df_full <- df_full[-idxFull, ]
    storedData(df_full)
    req(input$which_setting)
    saveSettingData(df_full, input$which_setting)
    showNotification(paste(length(sel), "Zeile(n) gelöscht!"), type = "message")
  })
  
  
  ## 4.9) QUIZ-FUNKTIONALITÄT ----
  
  getNextWord <- function(){
    df <- isolate(getFilteredData())
    if(nrow(df)==0){
      quizWordRV(NULL)
      return(NULL)
    }
    set.seed(as.integer(Sys.time()))
    idx <- sample(seq_len(nrow(df)), 1)
    quizWordRV(df[idx, , drop = FALSE])
  }
  
  observeEvent(input$startQuiz, {
    quizSessionRV(data.frame())
    quizWordRV(NULL)
    quizSessionStart(Sys.time())
    showNotification("Abfrasesession gestartet!", type = "message")
    getNextWord()
  })
  
  output$quiz_word <- renderText({
    rw <- quizWordRV()
    if(is.null(rw) || nrow(rw)==0) return("")
    rw$Original[1]
  })
  
  observeEvent(input$quiz_check, {
    ans <- trimws(input$quiz_answer)
    if(nchar(ans)==0){
      showNotification("Bitte zuerst eine Antwort eingeben!", type = "warning")
      return(NULL)
    }
    if(is.null(quizSessionStart())){
      showNotification("Keine Session aktiv => zuerst starten!", type = "warning")
      return(NULL)
    }
    quizStageRV(TRUE)
    rw <- quizWordRV()
    if(is.null(rw) || nrow(rw)==0){
      showNotification("Kein aktuelles Wort => NextWord...", type = "warning")
      getNextWord()
      return(NULL)
    }
    realVal <- rw$Uebersetzung[1]
    res <- ifelse(tolower(ans) == tolower(trimws(realVal)), "ok", "nok")
    rowQ <- data.frame(
      Zeitstempel         = format(Sys.time(), "%d.%m.%Y_%H.%M.%S"),
      Abfragerichtung     = rw$Sprache,
      Abfragewort         = rw$Original,
      RichtigeUebersetzung= realVal,
      MeineUebersetzung   = ans,
      Ergebnis            = res,
      Setting             = input$which_setting,
      SettingNiveau       = "",
      stringsAsFactors    = FALSE
    )
    oldSS <- quizSessionRV()
    newSS <- rbind(oldSS, rowQ)
    quizSessionRV(newSS)
    
    oldQL <- quizLogRV()
    newQL <- rbind(oldQL, rowQ)
    quizLogRV(newQL)
    save_quiz_data(newQL)
    
    if(res=="ok"){
      showNotification("Richtig!", type = "message")
    } else {
      showNotification(paste("Falsch! Korrekt wäre:", realVal), type = "warning")
    }
    updateTextInput(session, "quiz_answer", value = "")
    getNextWord()
  })
  
  output$quiz_mode_text <- renderText({
    selLang <- input$filter_sprachen
    if(is.null(selLang) || length(selLang)==0) return("Keine Auswahl")
    if("Alle" %in% selLang) "Alle Sprachen" else paste(selLang, collapse = ", ")
  })
  
  output$quiz_direction_UI <- renderUI({
    tagList(
      strong("Aktuelle Abfragerichtung:"),
      textOutput("quiz_currentDirection", inline = TRUE),
      br(),
      textInput("quiz_answer", "Meine Übersetzung (Antwort):", "")
    )
  })
  
  output$quiz_currentDirection <- renderText({
    rw <- quizWordRV()
    if(is.null(rw) || nrow(rw)==0) return("???")
    rw$Sprache[1]
  })
  
  output$quiz_feedback <- renderText({
    if(!quizStageRV()) return("")
    ""
  })
  
  output$quizSessionDT <- renderDT({
    df <- quizSessionRV()
    if(nrow(df) > 0){
      df$ParsedTS <- as.POSIXct(df$Zeitstempel, format="%d.%m.%Y_%H.%M.%S")
      df <- df[order(df$ParsedTS, decreasing=TRUE), ]
      df$ParsedTS <- NULL
    }
    datatable(df, selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 5, autoWidth = TRUE, dom = "Bfrtip",
                             buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  output$quizStats <- renderTable({
    sess <- quizSessionRV()
    st <- quizSessionStart()
    if(is.null(st) || nrow(sess)==0){
      return(data.frame(
        Zeit = "00:00", AnzahlAbfragen = 0, Richtig = 0, Falsch = 0,
        QuoteRichtig = "0%", QuoteFalsch = "0%"
      ))
    }
    nGes <- nrow(sess)
    nOk <- sum(sess$Ergebnis=="ok")
    nNo <- sum(sess$Ergebnis=="nok")
    qOk <- paste0(round(100*nOk/nGes,0),"%")
    qNo <- paste0(round(100*nNo/nGes,0),"%")
    diffSec <- as.numeric(difftime(Sys.time(), st, units = "secs"))
    mm <- floor(diffSec/60)
    ss <- round(diffSec - mm*60)
    data.frame(
      Zeit = sprintf("%02d:%02d", mm, ss),
      AnzahlAbfragen = nGes,
      Richtig = nOk,
      Falsch = nNo,
      QuoteRichtig = qOk,
      QuoteFalsch = qNo,
      stringsAsFactors = FALSE
    )
  })
  
  observeEvent(input$endQuiz, {
    st <- quizSessionStart()
    if(is.null(st)){
      showNotification("Keine aktive Session!", type = "warning")
      return(NULL)
    }
    sess <- quizSessionRV()
    if(nrow(sess)>0){
      nGes <- nrow(sess)
      nOk  <- sum(sess$Ergebnis=="ok")
      nNo  <- sum(sess$Ergebnis=="nok")
      diffSec <- as.numeric(difftime(Sys.time(), st, units = "secs"))
      mm <- floor(diffSec/60)
      ss <- round(diffSec - mm*60)
      dauer <- sprintf("%02d:%02d", mm, ss)
      oldHist <- sessionHistRV()
      newRow <- data.frame(
        SessionID     = nrow(oldHist)+1,
        Startzeit     = format(st, "%d.%m.%Y_%H:%M:%S"),
        Endzeit       = format(Sys.time(), "%d.%m.%Y_%H:%M:%S"),
        Dauer         = dauer,
        Anzahl        = nGes,
        Richtig       = nOk,
        Falsch        = nNo,
        QuoteRichtig  = paste0(round(100*nOk/nGes,0),"%"),
        QuoteFalsch   = paste0(round(100*nNo/nGes,0),"%"),
        Setting       = input$which_setting,
        DetailRichtig = "",
        DetailFalsch  = "",
        stringsAsFactors = FALSE
      )
      newHist <- rbind(oldHist, newRow)
      sessionHistRV(newHist)
      save_session_history(newHist)
    }
    quizSessionStart(NULL)
    showNotification("Abfrasesession beendet!", type = "message")
  })
  
  output$sessionHistDT <- renderDT({
    datatable(sessionHistRV(), selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 5, autoWidth = TRUE, order = list(list(1, "desc")),
                             dom = "Bfrtip", buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  observeEvent(input$delSessionHist, {
    sel <- input$sessionHistDT_rows_selected
    if(length(sel)==0){
      showNotification("Keine Zeile in der Session-Historie markiert!", type="warning")
      return(NULL)
    }
    df <- sessionHistRV()
    df <- df[-sel, ]
    sessionHistRV(df)
    save_session_history(df)
    showNotification(paste(length(sel), "Zeile(n) aus Session-Historie gelöscht!"), type="message")
  })
  
  
  ## 4.10) QUIZ-LOG (IM SELBEN TAB) ----
  
  observeEvent(input$reloadQuizLog, {
    df <- load_quiz_data()
    quizLogRV(df)
    showNotification("Quiz-Log neu geladen.", type = "message")
  })
  
  output$quizLogTable <- renderDT({
    datatable(quizLogRV(), selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 25, autoWidth = TRUE, order = list(list(0, "desc")),
                             dom = "Bfrtip", buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  observeEvent(input$delQuizLog, {
    sel <- input$quizLogTable_rows_selected
    if(length(sel)==0){
      showNotification("Keine Zeile im Quiz-Log markiert!", type = "warning")
      return(NULL)
    }
    df <- quizLogRV()
    df <- df[-sel, ]
    quizLogRV(df)
    save_quiz_data(df)
    showNotification(paste(length(sel), "Zeile(n) gelöscht (Quiz-Log)!"), type = "message")
  })
  
  output$quizPlot <- renderPlot({
    dfq <- quizLogRV()
    if(nrow(dfq)==0){
      plot.new()
      title("Kein Quiz-Log => kein Diagramm")
      return(NULL)
    }
    times <- strptime(dfq$Zeitstempel, "%d.%m.%Y_%H.%M.%S")
    dfq$TimePOSIX <- as.POSIXct(times)
    dfp <- dfq[!is.na(dfq$TimePOSIX), ]
    if(nrow(dfp)==0){
      plot.new()
      title("Keine parsebaren Zeitstempel => kein Diagramm")
      return(NULL)
    }
    dfp$OkVal <- ifelse(dfp$Ergebnis=="ok", 1L, 0L)
    ggplot(dfp, aes(x = TimePOSIX, y = OkVal, color = Abfragerichtung)) +
      geom_point(size = 3, alpha = 0.7) +
      geom_line(aes(group = Abfragerichtung), alpha = 0.4) +
      scale_y_continuous(breaks = c(0,1), labels = c("nok", "ok")) +
      labs(x = "Zeit", y = "Ergebnis (ok=1, nok=0)",
           title = "Quiz-Log Zeitverlauf") +
      theme_minimal()
  })
  
  
  ## 4.11) SETTINGS VERWALTEN (ARCHIVIEREN / LÖSCHEN) ----
  
  output$settingsIndexDT <- renderDT({
    datatable(settingsIndexRV(), selection = "single", extensions = c("Buttons"),
              options = list(pageLength = 5, autoWidth = TRUE, dom = "Bfrtip",
                             buttons = c("copy", "csv", "excel", "pdf", "print")))
  })
  
  deleteSettingFile <- function(settingName){
    si <- settingsIndexRV()
    rowMatch <- si[si$SettingName == settingName, ]
    if(nrow(rowMatch)==0) return(NULL)
    path <- rowMatch$FilePath[1]
    if(file.exists(path)) file.remove(path)
  }
  
  observeEvent(input$archiveSettingBtn, {
    sel <- input$settingsIndexDT_rows_selected
    if(length(sel)==0){
      showNotification("Kein Setting in der Tabelle markiert!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    selName <- si$SettingName[sel]
    si$Archived[si$SettingName == selName] <- TRUE
    saveSettingsIndex(si)
    settingsIndexRV(si)
    showNotification(paste("Setting archiviert:", selName), type = "message")
  })
  
  observeEvent(input$deleteSettingBtn, {
    sel <- input$settingsIndexDT_rows_selected
    if(length(sel)==0){
      showNotification("Kein Setting in der Tabelle markiert!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    selName <- si$SettingName[sel]
    showModal(
      modalDialog(
        title = "Löschen bestätigen",
        paste("Möchtest du das Setting wirklich löschen? (", selName, ")"),
        footer = tagList(
          modalButton("Abbrechen"),
          actionButton("confirmDeleteSetting", "Ja, löschen", class = "btn-danger")
        )
      )
    )
  })
  
  observeEvent(input$confirmDeleteSetting, {
    removeModal()
    sel <- input$settingsIndexDT_rows_selected
    si <- settingsIndexRV()
    selName <- si$SettingName[sel]
    si <- si[si$SettingName != selName, ]
    saveSettingsIndex(si)
    settingsIndexRV(si)
    deleteSettingFile(selName)
    showNotification(paste("Setting gelöscht:", selName), type = "error")
  })
  
}


# 5) APP STARTEN ----

# Mit dem folgenden Aufruf wird die App schließlich gestartet. Wenn man
# diesen Code in einer R-Umgebung ausführt, öffnet sich ein Shiny-Fenster,
# in dem alle oben definierten Funktionen, UI-Elemente und Abläufe
# verfügbar sind.

shinyApp(ui, server)
