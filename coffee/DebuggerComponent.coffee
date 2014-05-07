RIGHT_ARROW    = '\u2192'
POWER_SYMBOL   = '\u233d'
RIGHT_TRIANGLE = '\u25b6'
type           = React.PropTypes

MILLIS_FOR_SCROLLED_INSTRUCTIONS       = 500
MILLIS_FOR_SCROLLED_INSTRUCTIONS_TENTH = 5

DebuggerComponent = React.createClass

  displayName: 'DebuggerComponent'

  propTypes:
    state:         type.string.isRequired
    pos:           type.string
    console:       type.string.isRequired
    instructions:  type.string.isRequired
    highlightLine: type.bool.isRequired
    doCommand:     type.object.isRequired

  _instructionsToHtml: ->
    lines =
      if @props.instructions == '' then [] else @props.instructions.split("\n")

    { br, div } = React.DOM
    html = [ br { key: 1 } ] # blank line at beginning
    line_num = 1

    for line in lines

      html.push div
        key: "num#{line_num}"
        ref: "num#{line_num}"
        className: "num _#{line_num}"
        line_num

      isHighlighted = @props.highlightLine && @props.pos &&
        parseInt(@props.pos.split(',')[0]) == line_num
      html.push div
        key: "code#{line_num}"
        className: "code _#{line_num} " +
          (if isHighlighted then 'bold ' else '')
        line

      line_num += 1

    html.push br { key: 2, style: { clear: 'both' } }
    html.push br { key: 3 }
    html

  componentDidUpdate: (prevProps, prevState) ->
    if @props.pos != prevProps.pos && @props.pos
      @_scrollInstructions (->)
    if @props.console.split("\n").length != prevProps.console.split("\n").length
      @_scrollConsole()

  _scrollInstructions: (callback) ->
    $pointer = @refs.pointer.getDOMNode()
    $content = @refs.content.getDOMNode()
    line_num = @props.pos.split(',')[0]
    $pointer.style.display = 'block'
    $content.style.display = 'block'
    $element_1 = @refs["num1"].getDOMNode()
    $element_n = @refs["num#{line_num}"].getDOMNode()
    old_scroll_top = $content.scrollTop
    new_scroll_top = $element_n.getBoundingClientRect().top -
                     $element_1.getBoundingClientRect().top
    animateScrollTop = (progress) ->
      progress = 1.0 if progress > 1.0
      $content.scrollTop = (1.0 - progress) * old_scroll_top +
        progress * new_scroll_top
      if progress < 1.0
        window.setTimeout (=> animateScrollTop (progress + 0.1)),
          MILLIS_FOR_SCROLLED_INSTRUCTIONS_TENTH
      else
        window.setTimeout callback, MILLIS_FOR_SCROLLED_INSTRUCTIONS
    animateScrollTop 0.1

  _scrollConsole: ->
    $console = @refs.console.getDOMNode()
    $console.scrollTop = $console.scrollHeight

  render: ->
    { br, button, div, label, span } = React.DOM

    div
      className:
        'machine ' +
        (@props.state == 'OFF' && 'off ' || '') +
        (@props.state != 'OFF' && 'on ' || '')

      div
        className: 'buttons'
        button
          className: 'step'
          onClick: => @props.doCommand.step()
          disabled: @props.state == 'OFF' || @props.pos == null
          "#{RIGHT_TRIANGLE} Step"
        button
          className: 'fast-forward'
          onClick: => @props.doCommand.run()
          disabled: @props.state == 'OFF' || @props.pos == null
          "#{RIGHT_TRIANGLE}#{RIGHT_TRIANGLE} Run"
        button
          className: 'power ' +
            (@props.state != 'OFF' && 'active ' || '')
          onClick: => @props.doCommand.power()
          "#{POWER_SYMBOL} Power"

      label {}, 'Instructions'
      div
        className: 'instructions'
        if @props.pos
          div
            className: 'pointer'
            ref: 'pointer'
            RIGHT_ARROW
        if @props.pos
          div
            className: 'content'
            ref: 'content'
            @_instructionsToHtml()

      label {}, 'Input & Output'
      div
        className: 'console'
        ref: 'console'
        span
          className: 'before-cursor'
          @props.console
        div
          className: 'cursor'

      br { clear: 'all' }

module.exports = DebuggerComponent
