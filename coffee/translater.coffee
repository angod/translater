blsd = require "blessed"

#################################################################
# UI start
#################################################################

commonWindowDecoration = {
  border: {
    type: "line"
    fg: "green"
  }
}

screen = blsd.screen {
  title: "translater v.0.0.1"
}
screenCenterX = Math.ceil(screen.width / 2)

form = blsd.form {
  height: 3
  border: commonWindowDecoration.border
}

source = blsd.textbox {
  padding:
    left: screenCenterX
}

transcription = blsd.box {
  top: 3
  height: 3
  border: commonWindowDecoration.border
}

gtranslate = blsd.box {
  top: 6
  width: "40%"
  border: commonWindowDecoration.border
}

multitran = blsd.box {
  top: 6
  right: 0
  width: "60%"
  border: commonWindowDecoration.border
}

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

screen.key ["C-c", "q"], ->
  process.exit 0

offset = 0
wordLength = 0
source.on "keypress", (ch) ->
  if ch?
    if ch.charCodeAt() is 13
      
    else if ch.charCodeAt() is 127
      if wordLength
        --wordLength
    else
      ++wordLength

  offset = screenCenterX - parseInt(wordLength / 2)
  source.padding.left = offset

  screen.render()

screen.key "space", ->
  # reset input
  wordLength = 0
  source.clearValue()
  source.padding.left = screenCenterX

  source.readInput()
  screen.render()

screen.key "e", ->
  source.readInput()
  screen.render()

#################################################################
# Events end
#################################################################


#################################################################
# Google Translate output start
#################################################################



#################################################################
# Google Translate output
#################################################################
