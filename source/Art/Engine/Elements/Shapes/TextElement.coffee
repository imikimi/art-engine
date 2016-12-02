Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Text = require 'art-text'
FillableBase = require '../FillableBase'
GlobalEpochCycle = require '../../Core/GlobalEpochCycle'

{log, BaseObject, shallowClone, pureMerge, merge, createWithPostCreate, isPlainArray
  isString, isNumber
} = Foundation
{point, rect} = Atomic
{normalizeFontOptions} = Text.Metrics

{globalEpochCycle} = GlobalEpochCycle

propInternalName = BaseObject.propInternalName
propSetterName = BaseObject._propSetterName
module.exports = createWithPostCreate class TextElement extends FillableBase

  defaultSize: cs:1

  constructor: ->
    super
    @_textLayout = null

  @getter cacheable: -> true

  @drawLayoutProperty
    fontSize:     default: 16,        validate: (v) -> isNumber v
    fontFamily:   default: "Times",   validate: (v) -> isString v
    fontStyle:    default: "normal",  validate: (v) -> isString v
    fontVariant:  default: "normal",  validate: (v) -> isString v
    fontWeight:   default: "normal",  validate: (v) -> isString v
    align:        default: 0,         preprocess: (v) -> point v
    layoutMode:   default: "textualBaseline",  validate: (v) -> isString v
    leading:      default: 1.25,      validate: (v) -> isNumber v
    maxLines:     default: null,      validate: (v) -> !v? || isNumber v
    overflow:     default: "ellipsis",  validate: (v) -> isString v

    text:
      default: Text.Layout.defaultText
      preprocess: (t) ->
        if isPlainArray t
          t.join "\n"
        else
          "#{t}"

  @virtualProperty
    font:
      getter: (pending) ->
        {_fontFamily, _fontSize, _fontStyle, _fontVariant, _fontWeight} = @getState pending
        fontFamily:   _fontFamily
        fontSize:     _fontSize
        fontStyle:    _fontStyle
        fontVariant:  _fontVariant
        fontWeight:   _fontWeight
    format:
      getter: (pending) ->
        {_align, _layoutMode, _leading, _maxLines, _overflow} = @getState pending
        align:        _align
        layoutMode:   _layoutMode
        leading:      _leading
        maxLines:     _maxLines
        overflow:     _overflow

  getBaseDrawArea: ->
    @_textLayout?.getDrawArea() || rect()

  getPendingBaseDrawArea: ->
    # TODO: this doesn't actually fetch the Pending state.
    @_textLayout?.getDrawArea() || rect()

  customLayoutChildrenFirstPass: (size) ->
    ret = null
    globalEpochCycle.timePerformance "aimTL", =>
      @_textLayout = new Text.Layout @getPendingText(), @getPendingFont(), @getPendingFormat(), size.x, size.y
      ret = @_textLayout.getSize()
    ret

  customLayoutChildrenSecondPass: (size) ->
    @_textLayout.setWidth size.x
    @_textLayout.size

  fillShape: (target, elementToTargetMatrix, options) ->
    @_textLayout.draw target, elementToTargetMatrix, pureMerge options,
      layoutSize: @getCurrentSize()
      color:  options?.color || @_color

  strokeShape: (target, elementToTargetMatrix, options) ->
    @_textLayout.stroke target, elementToTargetMatrix, pureMerge options,
      layoutSize: @getCurrentSize()
      color:  options?.color || @_color