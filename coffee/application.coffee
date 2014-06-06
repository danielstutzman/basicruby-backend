DebuggerController = require './DebuggerController.coffee'
ExerciseController = require './ExerciseController.coffee'
ExerciseComponent  = require './ExerciseComponent.coffee'
SetupResizeHandler = require('./setup_resize_handler.coffee')

$one = (selector) -> document.querySelector(selector)
$all = (selector) -> document.querySelectorAll(selector)

document.addEventListener 'DOMContentLoaded', ->
  if $one('body.exercise') && !$one('div.exercise.purple')
    new ExerciseController($one('div.exercise'), featuresJson, exerciseJson,
      exerciseColor, pathForNextExercise, pathForNextRep).setup()

  # Fix bug where Mobile Safari landscape mode scrolls too far down the page
  window.addEventListener 'orientationchange', ->
    window.scrollTo 0, 1
