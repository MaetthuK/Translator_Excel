############################################################################
# app.R (inkl. Task 6 und Integration alter Funktionalitäten)
# Shiny-App für dynamische Settings + Google-Translate + Quiz-Log
############################################################################

library(shiny)
library(shinythemes)
library(httr)
library(jsonlite)
library(openxlsx)
library(DT)
library(stringr)
library(ggplot2)

# -------------------------------------------------------------------------
# BITTE DEINEN API-KEY HIER EINTRAGEN
# -------------------------------------------------------------------------
API_KEY <- "AIzaSyDR3-F8HnlRYBSjgAISHxR5VjYrKMlNuxY"

# -------------------------------------------------------------------------
# Custom-CSS
# -------------------------------------------------------------------------
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

############################################################################
# XLSX-FUNKTIONEN (load/save) – unverändert aus dem alten Code
############################################################################

settings_index_path <- "settings_index.xlsx"

loadSettingsIndex <- function(){
  if(!file.exists(settings_index_path)){
    df <- data.frame(
      SettingName = character(),
      FilePath    = character(),
      Archived    = logical(),
      stringsAsFactors = FALSE
    )
    return(df)
  } else {
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

path_queries <- "my_querys.xlsx"

load_querys <- function(){
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

quiz_log_path        <- "my_quizlog.xlsx"
session_history_path <- "my_session_history.xlsx"

load_quiz_data <- function(){
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

############################################################################
# 2) UI
############################################################################

ui <- fluidPage(
  theme = shinytheme("flatly"),
  tags$head(tags$style(HTML(customCSS))),
  
  # Titel
  titlePanel("Mein Übersetzer mit Settings & Quiz"),
  
  # Layout: Linke Spalte für Settingwahl, Übersetzungseingabe & Navigation
  fluidRow(
    column(
      width = 3,
      wellPanel(
        radioButtons("settingChoice", "Was möchten Sie tun?",
                     choices = c("Vorhandenes Setting auswählen" = "existing",
                                 "Neues Setting erstellen" = "new"),
                     selected = "existing"),
        # Wenn "existing" gewählt: Dropdown mit vorhandenen Settings
        conditionalPanel(
          condition = "input.settingChoice == 'existing'",
          uiOutput("settingsDropdownUI")
        ),
        # Wenn "new" gewählt: Neues Setting anlegen
        conditionalPanel(
          condition = "input.settingChoice == 'new'",
          textInput("newSettingName", "Neues Setting anlegen (Name):", ""),
          actionButton("createSettingBtn", "Neues Setting erstellen", class = "btn-success")
        )
      ),
      
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
      
      # Navigationstasten
      div(
        id = "leftButtons",
        actionButton("btnGoTranslate", "Übersetzen", class="btn-info"),
        actionButton("btnGoQuiz", "Quiz", class="btn-primary"),
        actionButton("btnGoSettings", "Settings verwalten", class="btn-success")
      )
    ),
    
    # Rechte Spalte: Anzeige aktueller Übersetzung & Tabs
    column(
      width = 9,
      
      h4("Aktuelle Übersetzung im Speicher:"),
      DTOutput("tbl_current"),
      
      tabsetPanel(
        id = "subTabs",
        # Tab 1: Anzeige des gewählten Settings
        tabPanel("Anzeige gewähltes Setting",
                 fluidRow(
                   column(6, actionButton("delRows", "Zeile löschen (Setting)", class = "btn-warning")),
                   column(6, p("Zellen direkt bearbeiten (Double-click)"))
                 ),
                 DTOutput("mainDT")
        ),
        # Tab 2: Alle bisherigen Übersetzungen (my_querys)
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
        # Tab 3: Quiz – hier sind neben der aktiven Session auch der Quiz-Log und eine grafische Statistik integriert
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
        # Tab 4: Settings verwalten (Archivieren/Löschen)
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

############################################################################
# 3) SERVER
############################################################################

server <- function(input, output, session){
  
  # Navigation: Schalte zu den entsprechenden Tabs
  observeEvent(input$btnGoTranslate, {
    updateTabsetPanel(session, "subTabs", selected = "Anzeige gewähltes Setting")
  })
  observeEvent(input$btnGoQuiz, {
    updateTabsetPanel(session, "subTabs", selected = "Quiz")
  })
  observeEvent(input$btnGoSettings, {
    updateTabsetPanel(session, "subTabs", selected = "Settings verwalten")
  })
  
  # REACTIVE VALUES
  settingsIndexRV  <- reactiveVal(loadSettingsIndex())
  currentData      <- reactiveVal(data.frame())
  storedData       <- reactiveVal(data.frame())
  queryDataRV      <- reactiveVal(load_querys())
  myQueriesDuplicatesRV <- reactiveVal(data.frame())
  quizLogRV        <- reactiveVal(load_quiz_data())
  sessionHistRV    <- reactiveVal(load_session_history())
  quizSessionRV    <- reactiveVal(data.frame())
  quizWordRV       <- reactiveVal(NULL)
  quizSessionStart <- reactiveVal(NULL)
  quizStageRV      <- reactiveVal(FALSE)
  
  # UI: Settings Dropdown
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
  
  # Bei Änderung des ausgewählten Settings laden
  observeEvent(list(settingsIndexRV(), input$which_setting), {
    req(input$which_setting)
    df <- loadSettingData(input$which_setting)
    storedData(df)
    if(!is.null(quizSessionStart())){
      getNextWord()
    }
  }, ignoreNULL = TRUE)
  
  # Neues Setting erstellen
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
  
  # Übersetzung: Aktuelle Übersetzungen generieren und speichern in my_querys
  output$tbl_current <- renderDT({
    df <- currentData()
    if(nrow(df) == 0){
      return(datatable(data.frame(`(Keine Daten)` = "Keine aktuelle Übersetzung"), options = list(dom = 't')))
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
    df_out <- do.call(rbind, bigList)
    # Überspringe Zeilen, in denen Original und Übersetzung identisch sind
    dup_self <- tolower(trimws(df_out$Original)) == tolower(trimws(df_out$Uebersetzung))
    if(any(dup_self)){
      showNotification(paste(sum(dup_self), "Zeile(n) identisch => ignoriert."), type = "warning")
      df_out <- df_out[!dup_self, ]
    }
    # In my_querys speichern, falls noch nicht vorhanden
    if(nrow(df_out) > 0){
      oldQ <- queryDataRV()
      combo_old <- paste(tolower(oldQ$Sprache), tolower(oldQ$Original), tolower(oldQ$Uebersetzung))
      combo_new <- paste(tolower(df_out$Sprache), tolower(df_out$Original), tolower(df_out$Uebersetzung))
      isdup_q   <- combo_new %in% combo_old
      if(any(isdup_q)){
        showNotification(paste(sum(isdup_q), "Zeile(n) bereits in my_querys => nicht erneut gespeichert."), type = "warning")
      }
      df_qnew <- df_out[!isdup_q, c("Zeitstempel","Sprache","Original","Uebersetzung")]
      if(nrow(df_qnew) > 0){
        appendedQ <- rbind(oldQ, df_qnew)
        save_querys(appendedQ)
        queryDataRV(appendedQ)
        showNotification(paste(nrow(df_qnew), "Zeilen neu in my_querys.xlsx gespeichert."), type = "message")
      }
    }
    currentData(df_out)
  })
  
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
    currentData(data.frame())
  })
  
  # my_querys – Anzeige, Zeilen löschen, Duplikate anzeigen/entfernen
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
  
  # Buchstaben-Filter
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
  
  # Haupt-Tabelle (gewähltes Setting) mit Sprach- und Buchstabenfilter
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
  
  # Quiz-Funktionalität
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
    showNotification("Abfragesession gestartet!", type = "message")
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
    showNotification("Abfragesession beendet!", type = "message")
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
  
  # Quiz-Log in das Quiz-Register integrieren
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
  
  # Settings verwalten: Anzeige der Settings-Übersicht und Buttons zum Archivieren/Löschen
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

############################################################################
# 4) APP STARTEN
############################################################################

shinyApp(ui, server)
