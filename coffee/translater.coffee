blsd = require "blessed"
request = require "request"
gttoken = require "google-translate-token"

fs = require "fs"

#################################################################
# UI start
#################################################################

focusedWindowBorderColor = "blue"
unfocusedWindowBorderColor = "green"
commonBorderType = "line"

commonSliderColor = "white"

screen = blsd.screen {
  title: "translater v.0.0.2"
  smartCSR: true
}

screenCenterX = (Math.floor screen.width / 2) - 1
screenWidth = screen.width
screenHeight = screen.height

singleRowWindowHeight = 3

form = blsd.form {
  height: singleRowWindowHeight

  border: commonBorderType
  style:
    border:
      fg: unfocusedWindowBorderColor
}

source = blsd.textbox {
  style:
    bold: true
  padding:
    left: screenCenterX
}

transcription = blsd.box {
  top: form.height
  height: singleRowWindowHeight

  border: commonBorderType
  style:
    border:
      fg: unfocusedWindowBorderColor

  tags: true
}

gtranslate = blsd.box {
  top: form.height + transcription.height
  height: Math.floor (screenHeight - (form.height + transcription.height)) / 2

  border: commonBorderType
  style:
    border:
      fg: unfocusedWindowBorderColor
  scrollbar:
    bg: commonSliderColor

  scrollable: true
  tags: true
}

multitran = blsd.box {
  height: screenHeight - (form.height + transcription.height + gtranslate.height)
  bottom: 0

  border: commonBorderType
  style:
    border:
      fg: unfocusedWindowBorderColor
  scrollbar:
    bg: commonSliderColor

  scrollable: true
  tags: true
}

# add windows to screen
screen.append form
screen.append transcription
screen.append gtranslate
screen.append multitran
form.append source
screen.render()

#################################################################
# UI end
#################################################################


#################################################################
# Events start
#################################################################

wordLength = 0
sourceInputToggle = true

screen.on "resize", () ->
  # TODO: implement restore boxes with new parameters when screen resize
  screen.render()

screen.key ["C-c", "q"], ->
  process.exit 0

clearWindowsContent = () ->
  transcription.setContent()
  gtranslate.setContent()
  multitran.setContent()

screen.key "space", ->
  clearWindowsContent()
  # reset input
  wordLength = 0
  source.clearValue()
  source.padding.left = screenCenterX

  source.focus()
  source.readInput()
  screen.render()

screen.key "e", ->
  clearWindowsContent()
  source.focus()
  source.readInput()
  screen.render()

source.on "keypress", (ch) ->
  if ch? and sourceInputToggle
    if ch.charCodeAt() is 13
      form.submit()
    else if ch.charCodeAt() is 127
      if wordLength
        --wordLength
    else
      ++wordLength

    source.padding.left = screenCenterX - Math.ceil wordLength / 2
    screen.render()

source.on "focus", () ->
  sourceInputToggle = true
  form.style.border.fg = focusedWindowBorderColor
  screen.render()

form.on "submit", () ->
  sourceInputToggle = false
  form.style.border.fg = unfocusedWindowBorderColor

  gtranslateGetTranslation source.value
  gtranslate.focus()

  screen.render()

gtranslate.on "focus", () ->
  gtranslate.style.border.fg = focusedWindowBorderColor
  screen.render()

gtranslate.on "blur", () ->
  gtranslate.style.border.fg = unfocusedWindowBorderColor
  screen.render()

gtranslateLinesLength = 0
gtranslate.key ["k", "j"], (ch) ->
  if gtranslateLinesLength > gtranslate.height
    if ch is "k"
      if gtranslate.getScroll() - gtranslate.childOffset
        --gtranslate.childBase
        gtranslate.scroll -1
      else
        gtranslate.setScroll 0
    else
      if gtranslate.childBase + gtranslate.height <= gtranslateLinesLength
        ++gtranslate.childBase
        gtranslate.scroll 1
      else
        gtranslate.setScroll gtranslateLinesLength - 1
  screen.render()
#################################################################
# Events end
#################################################################


#################################################################
# Google Translate output start
#################################################################

gtranslateRequestOptions = {
  url: "",
  method: "GET",
  headers: {
    "User-Agent": "Chromium/53.0.2785.143"
  },
  setUrl: (token, slWord) ->
    this.url = "https://translate.google.com/translate_a/single?client=t&sl=en&tl=ru&hl=en&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t&ie=UTF-8&oe=UTF-8&source=btn&rom=1&ssel=0&tsel=0&kc=0&tk=" + token + "&q=" + slWord
}

gtranslateGetTranslation = (slWord) ->
  gttoken.get(slWord).then (token) ->
    gtranslateRequestOptions.setUrl token.value, slWord
    # fs.writeFile "debug.log", gtranslateRequestOptions.url + "\n", (e) ->
    request gtranslateRequestOptions, (error, response, result) ->
      if error or response.statusCode isnt 200
        logTime = new Date()
        logTime.setTime logTime.getTime() + Math.abs logTime.getTimezoneOffset() * 60 * 1000
        gtranslate.setContent logTime.toUTCString() + ":\tCannot connect to Google Translate"
        screen.render()
      else
        i = 1
        fixedResult = ""
        resultLength = result.length - 1
        while i < resultLength
          if (result[i] is "," and result[i + 1] is ",") or
             (result[i] is "[" and result[i + 1] is ",") or
             (result[i] is "," and result[i + 1] is "]")
            fixedResult += result[i++] + "\"\""
          else
            fixedResult += result[i++]

        result = JSON.parse "[" + fixedResult + "]"

        translationInstances = []
        mostPossibleTranslation = result[0][0][0]
        for sourceWordClass, ti in result[1]
          translationInstances.push [sourceWordClass[0], []]
          for translationInstance in sourceWordClass[2]
            # translationInstance[3] => translationUsage
            # translationInstance[0] => possibleTranslations
            # translationInstance[1] => sourceSynonyms
            translationPercentUsage = (translationInstance[3] * 100).toFixed 3
            translationInstances[ti][1].push [translationPercentUsage, translationInstance[0], translationInstance[1]]

        gtranslatePrintTranslation(mostPossibleTranslation, translationInstances)

gtranslatePrintTranslation = (mostPossibleTranslation, translationInstances) ->
  currentLine = 0
  # pt => possible translation
  ptOutputFieldLen = 32
  gtranslate.insertLine currentLine++, "{center}{bold}{magenta-fg}#{mostPossibleTranslation}{/magenta-fg}{/bold}{/center}"

  for sourceWordClass, ti in translationInstances
    # debug file logging
    # fs.appendFileSync "debug.log", "\n\n#{sourceWordClass[0]}", (e) ->
    gtranslate.insertLine currentLine++," ".repeat(12) + "{bold}{red-fg}#{sourceWordClass[0]}{/red-fg}{/bold}" 

    # translationInstance[0] => translationPercentUsage -> 68.729
    # translationInstance[1] => possibleTranslations    -> время
    # translationInstance[2] => sourceSynonyms          -> time,period,when,day,season,date
    for translationInstance, i in sourceWordClass[1]
      fmtTranslationInstance = "| "
      if not isNaN translationInstance[0]
        isEmptyLeadingSymbol = if 10 > translationInstance[0] then "0" else ""
        fmtTranslationInstance += "{cyan-fg}#{isEmptyLeadingSymbol}#{translationInstance[0]}{/cyan-fg} | "
      else
        fmtTranslationInstance += "{cyan-fg}00.000{/cyan-fg} | "

      padLen = ptOutputFieldLen - translationInstance[1].length
      fmtTranslationInstance += "{green-fg}#{translationInstance[1]}{/green-fg}" + " ".repeat(padLen)  + " | "
      fmtTranslationInstance += "{yellow-fg}#{translationInstance[2]}{/yellow-fg}"

      gtranslate.insertLine currentLine++, fmtTranslationInstance
      # debug file logging
      # isEmptyLeadingSymbol = if 10 > i then "|  " else "| "
      # fs.appendFileSync "debug.log", "    #{isEmptyLeadingSymbol}#{i} #{fmtTranslationInstance}\n", (e) ->

  gtranslateLinesLength = gtranslate.getLines().length

  # delete is "a fucking schrodinger" empty line in the end of box
  gtranslate.deleteLine(gtranslateLinesLength)
  screen.render()

#################################################################
# Google Translate output
#################################################################
