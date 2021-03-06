{
  log
  isFunction
  isNumber
  isString
  isPlainArray
  merge
  propsEq
  nextTick
} = require './StandardImport'
{stateEpoch} = StateEpoch = require "./StateEpoch"

{PersistantAnimator, EasingPersistantAnimator, PeriodicPersistantAnimator} = require '../Animation'

processedAnimators = null
_addAnimator = (prop, options) =>
  processedAnimators ||= {}
  if match = prop.match /^_(.*)/
    internalName = prop
    [__, prop] = match
  else
    internalName = "_#{prop}"

  processedAnimators[internalName] = if options instanceof PersistantAnimator
    options
  else if isFunction options
    new PersistantAnimator prop, animate: options
  else if isNumber options?.period
    new PeriodicPersistantAnimator prop, merge options, continuous: true
  else if options?.animate
    new PersistantAnimator prop, options
  else
    new EasingPersistantAnimator prop, options

_addAnimators = (v) ->
  return unless v
  if isString v
    _addAnimator prop for prop in v.match /[a-z]+/gi
  else if isPlainArray v
    _addAnimators el for el in v
  else
    _addAnimator prop, options for prop, options of v when options

module.exports = (superClass) -> class AnimatedElementMixin extends superClass

  ######################
  # ELEMENT PROPERTIES
  ######################
  @concreteProperty
    animateOnCreation:
      default: false
      validate: (v) -> !v || v == true

    animators:
      default: null
      setter: (v) ->
        processedAnimators = null

        if internalAnimators = @internalAnimators
          _addAnimators internalAnimators
        _addAnimators v

        processedAnimators


  # <override this for Elements with custom animators>
  @getter
    internalAnimators: ->

  constructor: (options) ->
    super
    if _ia = @internalAnimators
      @setAnimators options?.animators

  ######################
  # PRIVATE
  ######################

  _deactivatePersistantAnimators: ->
    for prop, animator of @animators
      animator.deactivate()

  _activateContinuousPersistantAnimators: ->
    nextTick => @_elementChanged()

  getPendingCreatedAndAddedToExistingParent: ->
    {_parent, _animateOnCreation} = @_pendingState
    @__stateEpochCount == 0 && (_animateOnCreation || !(@_pendingState._parent?.__stateEpochCount == 0))

  loggedAnimationErrors = 0
  preprocessForEpoch: ->
    if pendingAnimators = @_pendingState._animators
      animateFromVoid = @getPendingCreatedAndAddedToExistingParent()

      {frameSecond, epochCount} = stateEpoch

      for prop, animator of pendingAnimators
        {active} = animator

        try
          pendingValue = @_pendingState[prop]

          baseValue = if @__stateEpochCount == 0
            pendingValue
          else
            @[prop]

          currentValue = if animateFromVoid && hasFromVoidAnimation = animator.hasFromVoidAnimation
            @_animatingFromVoid = true
            animator.getPreprocessedFromVoid @, baseValue
          else baseValue

          newValue = if active || !propsEq currentValue, pendingValue
            animator.animateAbsoluteTime @, currentValue, pendingValue, frameSecond
          else pendingValue

          @_pendingState[prop] = newValue

        catch error
          @_pendingState[prop] = pendingValue
          if loggedAnimationErrors++ < 10

            log.error ArtEngine: AnimatedElementMixin: errorApplyingProp: {
              element: @inspectedName
              prop
              currentValue: @[prop]
              pendingValue: @_pendingState[prop]
              animator
              error
            }

    null
