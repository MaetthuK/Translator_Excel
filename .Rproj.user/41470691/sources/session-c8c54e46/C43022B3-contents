############################################################################
# app_mobile.R
# Mobile Version der Shiny-App für dynamische Settings + Google-Translate +
# Quiz-Log (mit Archivierung und Löschfunktion für Settings)
############################################################################

# Pakete laden (bitte sicherstellen, dass sie installiert sind)
library(shiny)
library(shinyMobile)
library(httr)
library(jsonlite)
library(openxlsx)
library(DT)
library(stringr)
library(ggplot2)

# -- BITTE ANPASSEN: Dein Google-API-Key --
API_KEY <- "AIzaSyDR3-F8HnlRYBSjgAISHxR5VjYrKMlNuxY"

# Einfaches Custom-CSS für mobile Anpassungen
customCSS <- "
body {
  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
  padding: 10px;
}
.f7-navbar, .f7-toolbar {
  background-color: #008cba !important;
}
.btn, .fm-button {
  width: 100%;
  margin-bottom: 10px;
}
"

############################################################################
# 1) GLOBALE FUNKTIONEN FÜR XLSX-LADE-/SPEICHERPROZESSE
############################################################################

# A) Zentrales Settings-Register: "settings_index.xlsx"
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

# B) Funktion, um das eigentliche Setting-Excel zu laden/speichern
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

# C) my_querys.xlsx => alle Übersetzungen werden hier ebenfalls gesammelt
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

# D) Quiz-Log + Session-History
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
# 2) UI (Mobile Version mit shinyMobile)
############################################################################

ui <- f7Page(
  title = "Übersetzer + Quiz - Mobile",
  init = f7Init(theme = "light", skin = "blue"),
  tags$head(tags$style(HTML(customCSS))),
  f7TabLayout(
    navbar = f7Navbar(title = "Übersetzer + Quiz"),
    f7Tabs(
      animated = TRUE,
      id = "tabs",
      # TAB: Übersetzen
      f7Tab(
        tabName = "Übersetzen",
        icon = f7Icon("arrow_right_arrow_left"),
        active = TRUE,
        f7BlockTitle("Einstellungen & Eingabe"),
        uiOutput("settingsDropdownUI"),
        f7Select(inputId = "lang_in", label = "Eingabesprache:",
                 choices = c("Deutsch" = "de", "Englisch" = "en",
                             "Französisch" = "fr", "Spanisch" = "es",
                             "Italienisch" = "it"), selected = "de"),
        f7TextArea(inputId = "text_in", label = "Zu übersetzender Text:",
                   value = "Hallo", placeholder = "Text eingeben..."),
        f7Segmented(inputId = "translate_mode", label = "Übersetzungsmodus:",
                    choices = list("Pro Zeile" = "linewise", 
                                   "Ganze Textblöcke" = "block"),
                    selected = "linewise"),
        uiOutput("targetLangUI"),
        f7Button(inputId = "go", label = "Übersetzen", color = "blue"),
        f7Button(inputId = "saveExcel", label = "Ergebnis speichern", color = "green"),
        f7BlockTitle("Buchstaben-Filter"),
        f7CheckboxGroup(inputId = "letters_row0", label = "Zeile 0 (Alle):",
                        choices = c("Alle"), selected = "Alle"),
        f7CheckboxGroup(inputId = "letters_row1", label = "Zeile 1 (A-H):",
                        choices = c("A","B","C","D","E","F","G","H")),
        f7CheckboxGroup(inputId = "letters_row2", label = "Zeile 2 (I-Q):",
                        choices = c("I","J","K","L","M","N","O","P","Q")),
        f7CheckboxGroup(inputId = "letters_row3", label = "Zeile 3 (R-Z):",
                        choices = c("R","S","T","U","V","W","X","Y","Z")),
        f7CheckboxGroup(inputId = "letters_row4", label = "Zeile 4 (Umlaute):",
                        choices = c("Ä","Ö","Ü")),
        uiOutput("langFilterUI"),
        f7BlockTitle("Aktuelle Übersetzung:"),
        tableOutput("tbl_current"),
        f7Collapsible("My Queries", DTOutput("myQueriesDT")),
        f7Collapsible("Duplikate", DTOutput("myQueriesDuplicates")),
        f7Collapsible("Gespeicherte Daten", DTOutput("mainDT")),
        f7Collapsible("Quiz",
                      f7Button(inputId = "startQuiz", label = "Quiz starten", color = "blue"),
                      textOutput("quiz_word"),
                      uiOutput("quiz_direction_UI"),
                      f7Button(inputId = "quiz_check", label = "Prüfen", color = "green"),
                      textOutput("quiz_feedback"),
                      f7Button(inputId = "endQuiz", label = "Quiz beenden", color = "red")
        )
      ),
      # TAB: Quiz-Log
      f7Tab(
        tabName = "Quiz-Log",
        icon = f7Icon("list_bullet"),
        active = FALSE,
        f7BlockTitle("Quiz-Log"),
        DTOutput("quizLogTable"),
        f7Button(inputId = "delQuizLog", label = "Zeilen löschen", color = "orange"),
        f7Button(inputId = "reloadQuizLog", label = "Neu laden", color = "gray"),
        f7BlockTitle("Grafische Statistik"),
        plotOutput("quizPlot", height = "300px")
      ),
      # TAB: Settings verwalten
      f7Tab(
        tabName = "Settings",
        icon = f7Icon("settings"),
        active = FALSE,
        f7BlockTitle("Settings verwalten"),
        f7Text(inputId = "newSettingName", label = "Neues Setting anlegen (Name):", value = ""),
        f7Button(inputId = "createSettingBtn", label = "Neues Setting erstellen", color = "green"),
        f7Button(inputId = "archiveSettingBtn", label = "Setting archivieren", color = "orange"),
        f7Button(inputId = "deleteSettingBtn", label = "Setting löschen", color = "red"),
        DTOutput("settingsIndexDT")
      )
    )
  )
)

############################################################################
# 3) SERVER
############################################################################

server <- function(input, output, session){
  
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
  
  # UI: Settings-Dropdown
  output$settingsDropdownUI <- renderUI({
    si <- settingsIndexRV()
    si_active <- si[si$Archived == FALSE, ]
    if(nrow(si_active) == 0){
      return(f7Block("Noch keine Settings vorhanden oder alle archiviert."))
    } else {
      f7Select(inputId = "which_setting", label = "Setting wählen:",
               choices = si_active$SettingName, selected = si_active$SettingName[1])
    }
  })
  
  observeEvent(list(settingsIndexRV(), input$which_setting), {
    req(input$which_setting)
    df <- loadSettingData(input$which_setting)
    storedData(df)
    if(!is.null(quizSessionStart())){
      getNextWord()
    }
  }, ignoreNULL = TRUE)
  
  # Settings-Verwaltung (Tab "Settings")
  output$settingsIndexDT <- renderDT({
    df <- settingsIndexRV()
    datatable(df, selection = "single",
              options = list(pageLength = 5, scrollX = TRUE))
  })
  
  observeEvent(input$createSettingBtn, {
    newName <- trimws(input$newSettingName)
    if(nchar(newName) == 0){
      f7Notification("Bitte einen Namen für das neue Setting eingeben!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    if(any(si$SettingName == newName)){
      f7Notification("SettingName existiert bereits!", type = "error")
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
    f7Notification(paste("Neues Setting angelegt:", newName), type = "message")
    updateTextInput(session, "newSettingName", value = "")
  }, ignoreInit = TRUE)
  
  deleteSettingFile <- function(settingName){
    si <- settingsIndexRV()
    rowMatch <- si[si$SettingName == settingName, ]
    if(nrow(rowMatch) == 0) return(NULL)
    path <- rowMatch$FilePath[1]
    if(file.exists(path)) file.remove(path)
  }
  
  observeEvent(input$archiveSettingBtn, {
    sel <- input$settingsIndexDT_rows_selected
    if(length(sel) == 0){
      f7Notification("Kein Setting in der Tabelle markiert!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    selName <- si$SettingName[sel]
    si$Archived[si$SettingName == selName] <- TRUE
    saveSettingsIndex(si)
    settingsIndexRV(si)
    f7Notification(paste("Setting archiviert:", selName), type = "message")
  })
  
  observeEvent(input$deleteSettingBtn, {
    sel <- input$settingsIndexDT_rows_selected
    if(length(sel) == 0){
      f7Notification("Kein Setting in der Tabelle markiert!", type = "warning")
      return(NULL)
    }
    si <- settingsIndexRV()
    selName <- si$SettingName[sel]
    
    showModal(
      f7Popup(
        title = "Löschen bestätigen",
        f7Block(paste("Möchtest du das Setting wirklich löschen? (", selName, ")")),
        f7Button(inputId = "confirmDeleteSetting", label = "Ja, löschen", color = "red"),
        closeByBackdrop = TRUE
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
    f7Notification(paste("Setting gelöscht:", selName), type = "error")
  })
  
  output$targetLangUI <- renderUI({
    allch <- c("Deutsch" = "de","Englisch" = "en","Französisch" = "fr",
               "Spanisch" = "es","Italienisch" = "it")
    chosen <- input$lang_in
    rest   <- allch[allch != chosen]
    defv   <- c("en","fr")
    defv2  <- defv[defv %in% rest]
    f7CheckboxGroup(inputId = "target_langs", label = "Zielsprachen:",
                    choices = rest, selected = defv2)
  })
  
  output$tbl_current <- renderTable({
    currentData()
  })
  
  observeEvent(input$go, {
    if(is.null(input$which_setting)){
      f7Notification("Kein Setting ausgewählt!", type = "warning")
      currentData(data.frame())
      return(NULL)
    }
    lines_in <- strsplit(input$text_in, "\n")[[1]]
    lines_in <- lines_in[ lines_in != "" ]
    if(length(lines_in)==0){
      f7Notification("Keine Eingabezeilen!", type = "warning")
      currentData(data.frame())
      return(NULL)
    }
    src <- input$lang_in
    tg <- setdiff(input$target_langs, src)
    if(length(tg)==0){
      f7Notification("Keine Zielsprache gewählt!", type = "warning")
      currentData(data.frame())
      return(NULL)
    }
    mode <- input$translate_mode
    base_url <- paste0("https://translation.googleapis.com/language/translate/v2?key=", API_KEY)
    bigList <- list()
    
    if(mode=="linewise"){
      for(ln in lines_in){
        for(tlang in tg){
          resp <- httr::POST(
            url = base_url,
            body = list(q = ln, source = src, target = tlang, format = "text"),
            encode = "json"
          )
          cont <- httr::content(resp, as = "text", encoding = "UTF-8")
          js <- fromJSON(cont)
          if(!is.null(js$error)){
            f7Notification(paste("API-Fehler:", js$error$message), type = "error")
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
        resp <- httr::POST(
          url = base_url,
          body = list(q = block_txt, source = src, target = tlang, format = "text"),
          encode = "json"
        )
        cont <- httr::content(resp, as = "text", encoding = "UTF-8")
        js <- fromJSON(cont)
        if(!is.null(js$error)){
          f7Notification(paste("API-Fehler:", js$error$message), type = "error")
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
    
    dup_self <- tolower(trimws(df_out$Original)) == tolower(trimws(df_out$Uebersetzung))
    if(any(dup_self)){
      f7Notification(paste(sum(dup_self), "Zeile(n) identisch (Original == Übersetzung) => werden ignoriert."), type = "warning")
      df_out <- df_out[!dup_self, ]
    }
    
    if(nrow(df_out) > 0){
      oldQ <- queryDataRV()
      combo_old <- paste(tolower(oldQ$Sprache), tolower(oldQ$Original), tolower(oldQ$Uebersetzung))
      combo_new <- paste(tolower(df_out$Sprache), tolower(df_out$Original), tolower(df_out$Uebersetzung))
      isdup_q   <- combo_new %in% combo_old
      if(any(isdup_q)){
        f7Notification(paste(sum(isdup_q), "Zeile(n) bereits in my_querys => werden nicht erneut gespeichert."), type = "warning")
      }
      df_qnew <- df_out[!isdup_q, c("Zeitstempel","Sprache","Original","Uebersetzung")]
      if(nrow(df_qnew) > 0){
        appendedQ <- rbind(oldQ, df_qnew)
        save_querys(appendedQ)
        queryDataRV(appendedQ)
        f7Notification(paste(nrow(df_qnew), "Zeilen neu in my_querys.xlsx gespeichert."), type = "message")
      }
    }
    
    currentData(df_out)
  })
  
  observeEvent(input$saveExcel, {
    req(input$which_setting)
    df_tr <- currentData()
    if(nrow(df_tr)==0){
      f7Notification("Keine Zeilen zum Speichern!", type = "warning")
      return(NULL)
    }
    old_stored <- storedData()
    combo_old <- paste(tolower(old_stored$Original), tolower(old_stored$Uebersetzung))
    combo_new <- paste(tolower(df_tr$Original), tolower(df_tr$Uebersetzung))
    isdup_s   <- combo_new %in% combo_old
    if(any(isdup_s)){
      f7Notification(paste(sum(isdup_s), "Zeile(n) bereits im Setting vorhanden => werden ignoriert."), type = "warning")
    }
    df_new <- df_tr[!isdup_s, ]
    if(nrow(df_new) == 0){
      f7Notification("Alles war bereits im Setting vorhanden.", type = "warning")
      return(NULL)
    }
    appended <- rbind(old_stored, df_new)
    saveSettingData(appended, input$which_setting)
    storedData(appended)
    f7Notification(paste(nrow(df_new), "Zeilen appended & gespeichert!"), type = "message")
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
    f7CheckboxGroup(inputId = "filter_sprachen",
                    label = "Filter nach Sprache:",
                    choices = ch, selected = "Alle")
  })
  
  getFilteredData <- reactive({
    df <- storedData()
    if(nrow(df)==0) return(df[0,])
    let0 <- input$letters_row0
    let1 <- input$letters_row1
    let2 <- input$letters_row2
    let3 <- input$letters_row3
    let4 <- input$letters_row4
    if(!is.null(let0) && !("Alle" %in% let0)){
      chosen <- union(let1, union(let2, union(let3, let4)))
      if(length(chosen)==0){
        df <- df[0,]
      } else {
        firstChar <- substr(df$Original,1,1)
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
    df <- getFilteredData()
    datatable(df, selection = "multiple", editable = TRUE,
              options = list(pageLength = 25, scrollY = "400px"))
  })
  
  observeEvent(input$mainDT_cell_edit, {
    info <- input$mainDT_cell_edit
    i <- info$row
    j <- info$col
    v <- info$value
    df_filtered <- isolate(getFilteredData())
    df_full <- storedData()
    if(nrow(df_full)==0) return(NULL)
    rowNameFiltered <- rownames(df_filtered)[i]
    idxFull <- as.integer(rowNameFiltered)
    colN <- colnames(df_filtered)[j]
    df_full[idxFull, colN] <- v
    storedData(df_full)
    req(input$which_setting)
    saveSettingData(df_full, input$which_setting)
    f7Notification(paste("Zelle geändert:", colN, "=>", v), type = "message")
  })
  
  observeEvent(input$delRows, {
    sel <- input$mainDT_rows_selected
    if(length(sel)==0){
      f7Notification("Keine Zeilen markiert!", type = "warning")
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
    f7Notification(paste(length(sel), "Zeile(n) gelöscht!"), type = "message")
  })
  
  output$quiz_mode_text <- renderText({
    selLang <- input$filter_sprachen
    if(is.null(selLang) || length(selLang)==0) return("Keine Auswahl")
    if("Alle" %in% selLang){
      "Alle Sprachen"
    } else {
      paste(selLang, collapse = ", ")
    }
  })
  
  output$quiz_direction_UI <- renderUI({
    tagList(
      strong("Aktuelle Abfragerichtung:"),
      textOutput("quiz_currentDirection", inline = TRUE),
      f7Text(inputId = "quiz_answer", label = "Meine Übersetzung:", value = "")
    )
  })
  
  output$quiz_currentDirection <- renderText({
    rw <- quizWordRV()
    if(is.null(rw) || nrow(rw)==0) return("???")
    rw$Sprache[1]
  })
  
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
    f7Notification("Abfragesession gestartet!", type = "message")
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
      f7Notification("Bitte zuerst eine Antwort eingeben!", type = "warning")
      return(NULL)
    }
    if(is.null(quizSessionStart())){
      f7Notification("Keine Session aktiv => zuerst starten!", type = "warning")
      return(NULL)
    }
    quizStageRV(TRUE)
    rw <- quizWordRV()
    if(is.null(rw) || nrow(rw)==0){
      f7Notification("Kein aktuelles Wort => NextWord...", type = "warning")
      getNextWord()
      return(NULL)
    }
    realVal <- rw$Uebersetzung[1]
    res <- ifelse(tolower(ans)==tolower(trimws(realVal)), "ok", "nok")
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
      f7Notification("Richtig!", type = "message")
    } else {
      f7Notification(paste("Falsch! Korrekt wäre:", realVal), type = "warning")
    }
    updateTextInput(session, "quiz_answer", value = "")
    getNextWord()
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
    datatable(df, options = list(pageLength = 5, scrollX = TRUE))
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
      f7Notification("Keine aktive Session!", type = "warning")
      return(NULL)
    }
    sess <- quizSessionRV()
    if(nrow(sess)>0){
      nGes <- nrow(sess)
      nOk <- sum(sess$Ergebnis=="ok")
      nNo <- sum(sess$Ergebnis=="nok")
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
    f7Notification("Abfragesession beendet!", type = "message")
  })
  
  output$sessionHistDT <- renderDT({
    datatable(sessionHistRV(), 
              options = list(pageLength = 5, scrollX = TRUE,
                             order = list(list(1, "desc"))))
  })
  
  observeEvent(input$reloadQuizLog, {
    df <- load_quiz_data()
    quizLogRV(df)
    f7Notification("Quiz-Log neu geladen.", type = "message")
  })
  
  output$quizLogTable <- renderDT({
    quizLogRV()
  }, selection = "multiple",
  options = list(pageLength = 25, scrollX = TRUE, order = list(list(0, "desc"))))
  
  observeEvent(input$delQuizLog, {
    sel <- input$quizLogTable_rows_selected
    if(length(sel)==0){
      f7Notification("Keine Zeilen im Quiz-Log markiert!", type = "warning")
      return(NULL)
    }
    df <- quizLogRV()
    df <- df[-sel, ]
    quizLogRV(df)
    save_quiz_data(df)
    f7Notification(paste(length(sel), "Zeile(n) gelöscht (Quiz-Log)!"), type = "message")
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
}

############################################################################
# 4) APP STARTEN
############################################################################

shinyApp(ui, server)

