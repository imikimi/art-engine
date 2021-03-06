'use strict';

{
  log
  merge
  mergeInto
  capitalize
  compactFlattenFast
  compactFlattenAllFast
  isNumber
  isFunction
  shallowEq
  plainObjectsDeepEq
  isString
  inspect
  isPlainObject
  isPlainArray
  nextTick
  object
  BaseClass: {propInternalName}
  point0
  propsEq
  shallowPropsEq
} = require './StandardImport'

{stateEpoch} = StateEpoch = require "./StateEpoch"
{globalEpochCycle} = require './GlobalEpochCycle'

blankOptions = {}

module.exports = (superClass) -> class EpochedElementMixin extends superClass

  ############################
  # PROPERTIES
  ############################
  ###

  CONCRETE PROPERTIES
  -------------------

  Concrete-properties (non-virtual properties), once declared, take care of many common property tasks.
  For a property "foo":

    * @_foo and @_pendingState._foo are initialized on Element-instantiation
      - They are either intialized to default values (which are validated for consistency) or
      - Can be initialized by the instantiating code. Ex: new Element foo:123
    * Defines the following API
      - element.foo       # getter, returns @_foo
      - element.getFoo()  # old-school, alternative getter - faster in some browsers (Safari7 is 100x faster, Safary8 is 3x faster. Chrome is same speed.)
      - element.foo = v   # setter
      - element.setFoo(v) # old-school, alternative setter
      - element.pendingFoo / getPendingFoo() # returns @_pendingState.foo
      - element.fooChanged / getFooChanged() # returns propsEq @foo, @pendingFoo
    * Elements can override the default values for properties by setting:
      - prototype.defaultFoo to something other than undefined
      - Ex:
        class MyElement extends Element
          defaultSize: ps:1
    * Populates @class.metaProperties.foo with things like default values, names, preprocessors, etc...
      (this code is in flux; see below for current implementation)

  options:
    default:  # default value set when the Element is created
    setter: (preprocessedNewValue, oldValue, rawNewValue, preprocessAndValidate) ->
      THIS: the Element
      IN:
        preprocessedNewValue: the new value that has been validated and preprocssed

        oldValue: the currently set value.
          WARNING: Setting is replacing!
            The oldValue should not impact the newly set value in any
            LOGICALLY IMPORTANT WAY.

            Basically, only use oldValue to enhance performance OR trigger change-events;
            the actually-set-value should not be logically the same with or without it.

            For an example of how this is used to increase performance, see the
            'children' property. In this example we both enhance performance AND
            we can trigger detailed change-events.

        rawNewValue: the exact, unprocessed, unvalidated value of 'foo' passed by the setYourProp(foo) or @yourProp = foo statement.
        preprocessAndValidate: your custom preprocessor and validator are merged into a single function you can use
          as part of your custom setter if desired. A no-op function is provided by default, so this is always a valid function.

        preprocessAndValidate: your custom preprocessor and validator are merged into a single function you can use
          as part of your custom setter if desired. A no-op function is provided by default, so this is always a valid function.
      OUT: It should return the value to set in @_pendingState.
      SIDE EFFECTS:
        It should NOT actually set the value in @ or @_pendingState.
        It is best to use setProperty calls for all side-effects. This maintains the epoch
        consistency model: mutations only modify pendingState, not current-state.

      TODO:
        Verify and implement:
          Depricate concrete property setters:
            They are obsolete now that we can have postSetters.
            "postSetter" plus "preprocess" covers everything, I think.

      Use when:
        a) you need to do update other poperties when this one changes AND/OR
        b) you need to do something different when actually setting the value
           as opposed to simply preprocessing the value.
           NOTE: animations use the preprocessor when initializing their to and from values.

    postSetter: (newValue, oldValue, rawNewValue) ->
      THIS: the Element
      IN:
        newValue: the value after it has passed through the preprocessor and/or setter
        oldValue: the (custom-setter-processed) value that was last set
          i.e. the value in @_pendingState before the setter was called
      OUT: ignored
      STATE: @_pendingState has been updated with newValue; getPendingPropertyName() will return newValue
      SIDE EFFECTS:
        It is best to use setProperty calls for all side-effects. This maintains the epoch
        consistency model: mutations only modify pendingState, not current-state.

      Use when:
        a) You need to update other properties when this one changes. The simplest example is when
          this property defines default values for other properties that haven't been set yet.
        b) You need to fire off events when this property changes.

      This is particularly useful when writing custom Elements which consist of a struture of other
      elements. Often you'll want to update that structure in response to properties being set.

    # keyword: preprocessor
    preprocess: (rawValue, baseValue) -> processedValue
      IN:
        rawValue: raw value passed in to setter
        baseValue: a baseline value in case rawValue only partially specifies the final value.
          This is useful for size and location layouts where you may want to specify one dimension,
          but inherit the other dimension.
          toFrom-void Animators pass in the current value as the baseValue when they start. In this
          way you can say: "animators: size: toFrom: w: 0" and whatever the current height is
          will persist.
          Also note, that you can only pass in a baseCalue if you use "preprocessProperty."
          The normal setter will not pass through any baseValue you include.
          The normal setter is designed to fully replace the current value in a pure-functional way.
      THIS: not set
      OUT: normalized value to actually set

    # keyword: validator
    validate: (rawValue) -> boolean
      IN: raw value
      THIS: not set
      OUT: true or false
      Return false if the input is invalid which will trigger an exception.

  In all cases _elementChanged executes every time the property is set
  .setter takes precidence over .preprocess takes precidence over .validate; you can only have one

  VIRTUAL PROPERTIES
  ------------------

  Virtual properties are specified with the class method: @virtualProperty

  VPs have the same API from the client's perspective, but they don't have any storage in @ or @_pendingState.
  Virtual properties are used as alternative "views" into the Element's state. Ex:

     @currentLocation isn't actually stored as a point. It is derived from @elementToParentMatrix and @axis.

  As a short-cut, you can supply just a getter function instead of options to define a
  virtual property. See getter below for details. Here is how to use this shortcut:

    @virtualProperty
      foo: (pending) -> ...

  Virtual property options (when isPlainObject options)

    getter: (pending) ->
      REQUIRED
      THIS: the Element
      IN:   pending: true/false
      OUT:  if pending, return the pending value, else the current value

    setter: (preprocessedNewValue, rawNewValue, preprocessAndValidate) ->
      OPTIONAL
        If not provided, this virtual property cannot be set.
        Attempting to set this virtual property will be IGNORED
        I.E. attempting to set this property does not trigger errors.

      THIS: the Element
      IN:
        preprocessedNewValue: the new value that has been validated and preprocssed
        rawNewValue: the value passed in by the client
        preprocessAndValidate: your custom preprocessor and validator are merged into a single function you can use
          as part of your custom setter if desired. A no-op function is provided by default, so this is always a valid function.
      OUT: ignored

    validate: (v) ->
    preprocess: (v) ->
      works the same as the options for concrete-properties
      except they are only used by:
        preprocessAndValidate function passed to the setter
        animations

  Virtual property getter-function-only (if the 'options' passed in is actually a function)

    If you pass in a function only when defining a virtual property, you are setting the getter.
    Thus you can define a virtual property with just a getter.

  Virtual vs Concrete properties:

    * Virutal props don't have default values
    * Virtual props don't create property slots in Element instances or their _pendingState, BUT
    * Virtual props can have their setters invoked from initializers
    * preprocessors and validators can be specified
    * getter - you must specify a custom getter, see getter option above
    * setter specification/semantics are a little different. See setter option above

  ###

  ###################
  # PRIVATE / Must be before DEFINE PROPS section below
  ###################
  ###
  propertyInitializerList:
    list of tupples, one per property:
      [externalName, internalName, preprocessor, defaultValue]

  metaProperties fields:
    externalName:
    internalName:
    preprocessor:
    defaultValue:
    setterName:
    getterName:
  ###
  @extendableProperty
    propertyInitializerList: []
    metaProperties: {}

  ###
  Main method for defining properties. Used by concreteProp, virtualProp and others.
  ###
  @_defineElementProperty: (externalName, options={})  ->
    internalName = propInternalName externalName

    customValidator = options.validate
    customPreprocessor = options.preprocess

    defaultValue = options.default

    preprocessor = if customPreprocessor && customValidator
      # DEPRICATED: no longer passing in oldValues; setting a value should always fully replace the previous value
      # if customPreprocessor.length > 1 || customValidator.length > 1
      #   (v, oldValue) ->
      #     v = defaultValue unless v?
      #     throw new Error "invalid value for #{externalName}: #{inspect v}" unless customValidator v, oldValue
      #     customPreprocessor v, oldValue
      # else
        (v) ->
          v = defaultValue unless v?
          throw new Error "invalid value for #{externalName}: #{inspect v}" unless customValidator v
          customPreprocessor v
    else if customValidator
      # DEPRICATED: no longer passing in oldValues; setting a value should always fully replace the previous value
      # if customValidator.length > 1
      #   (v, oldValue) ->
      #     v = defaultValue unless v?
      #     throw new Error "invalid value for #{externalName}: #{inspect v}" unless customValidator v, oldValue
      #     v
      # else
        (v) ->
          v = defaultValue unless v?
          throw new Error "invalid value for #{externalName}: #{inspect v}" unless customValidator v
          v
    else customPreprocessor || (v) ->
      v = defaultValue unless v?
      v

    metaProperties =
      internalName: internalName
      externalName: externalName
      preprocessor: preprocessor
      getterName: @getPropGetterName externalName
      setterName: @getPropSetterName externalName

    if options.virtual
      metaProperties.virtual = true

      # if no setter, setting a virtual property is simply ignored
      _setter = options.setter || ->
      _getter = options.getter

      getter        = _getter
      pendingGetter = -> _getter.call @, true
      setter        = (rawValue) -> _setter.call @, preprocessor(rawValue), rawValue, preprocessor

    else
      metaProperties.defaultValue = defaultValue = preprocessor defaultValue

      getter        = (pending) -> if pending then @_pendingState[internalName] else @[internalName]
      pendingGetter = -> @_pendingState[internalName]

      {layoutProperty, drawProperty, drawAreaProperty, postSetter, setter} = options
      setter = if customSetter = setter
        if postSetter
          (rawNewValue) ->
            oldValue = @_pendingState[internalName]
            newValue = @_pendingState[internalName] = customSetter.call(
              @
              preprocessor rawNewValue
              oldValue
              rawNewValue
              preprocessor
            )
            @_elementChanged layoutProperty, drawProperty, drawAreaProperty
            postSetter.call @, newValue, oldValue, rawNewValue
            newValue
        else
          (rawNewValue) ->
            oldValue = @_pendingState[internalName]
            newValue = preprocessor rawNewValue
            newValue = @_pendingState[internalName] = customSetter.call(
              @
              preprocessor rawNewValue
              oldValue
              rawNewValue
              preprocessor
            )
            @_elementChanged layoutProperty, drawProperty, drawAreaProperty
            newValue
      else if postSetter
        (rawNewValue) ->
          oldValue = @_pendingState[internalName]
          newValue = @_pendingState[internalName] = preprocessor rawNewValue
          @_elementChanged layoutProperty, drawProperty, drawAreaProperty
          postSetter.call @, newValue, oldValue
          newValue
      else if preprocessor.length > 1
        (rawNewValue) ->
          oldValue = @_pendingState[internalName]
          newValue = @_pendingState[internalName] = preprocessor rawNewValue
          @_elementChanged layoutProperty, drawProperty, drawAreaProperty
          newValue
      else
        (rawNewValue) ->
          newValue = @_pendingState[internalName] = preprocessor rawNewValue
          @_elementChanged layoutProperty, drawProperty, drawAreaProperty
          newValue

      @extendPropertyInitializerList().push [internalName, defaultValue, externalName]
      # @_getPropertyInitializerDefaultValuesList().push defaultValue

    @extendMetaProperties externalName, metaProperties

    capitalizedExternalName = capitalize externalName
    @_addGetter @::, externalName,                         getter
    @_addGetter @::, "pending" + capitalizedExternalName, pendingGetter
    @_addGetter @::, externalName + "Changed",             -> !shallowPropsEq getter.call(@), pendingGetter.call(@)
    @_addSetter @::, externalName,                         setter

  ###################
  # DEFINE PROPS
  ###################
  @concreteProperty: (map)->
    for prop, options of map
      @_defineElementProperty prop, options

  ###
  IN: map from prop names to:
    a) property options object: see 'Virtual property options' above
    b) OR getter function f. Equivelent to (propName: getter: f)
  ###
  @virtualProperty: (map)->
    for prop, options of map
      options = getter: options if isFunction options
      options.virtual = true
      @_defineElementProperty prop, options

  ###################
  # SET PROPS
  ###################

  ###
  EFFECT: set each property in propertySet if it is a legitimate property; otherwise it is ignored
  ###
  _setPropertiesTempVirtualPropSetterNames = []
  _setPropertiesTempVirtualPropValues = []

  ###
  Sets all properties in propertySet
  undefined values and properties without setters are skipped
  ###
  setProperties: (props) ->
    {metaProperties} = @
    virtualPropCount = 0

    for prop, value of props when value != undefined && (mp = metaProperties[prop]) && setterName = mp.setterName
      if mp.virtual
        _setPropertiesTempVirtualPropSetterNames[virtualPropCount] = setterName
        _setPropertiesTempVirtualPropValues[virtualPropCount++] = value
      else
        @[setterName] value

    for i in [0...virtualPropCount]
      @[_setPropertiesTempVirtualPropSetterNames[i]] _setPropertiesTempVirtualPropValues[i]

    props

  ###
  EFFECT: set all properties, use propertySet values if present, otherwise use defaults

  TODO: this sets @parent and @children, it shouldn't, but they aren't virtual...
  TODO: if this is used much, it would be faster to have a concreteMetaProperties array so we don't have to test mp.virtual
    this "concreteMetaProperties" array would not include parent or children
  ###
  replaceProperties: (propertySet) ->
    metaProperties = @metaProperties
    for property, mp of metaProperties when !mp.virtual
      externalName = mp.externalName
      @[mp.setterName]? if propertySet.hasOwnProperty(externalName)
        propertySet[externalName]
      else
        mp.defaultValue
    propertySet

  setProperty: (property, value) ->
    if mp = @metaProperties[property]
      @[mp.setterName]? value

  preprocessProperty: (property, value, baseValue) ->
    if mp = @metaProperties[property]
      mp.preprocessor value, baseValue

  ###
  EFFECT: reset one property to its default
  ###
  resetProperty: (property) ->
    if mp = @metaProperties[property]
      @[mp.setterName]? mp.defaultValue

  ###################
  # READ/INSPECT PROPS
  ###################

  # used by Animator / Foundation.Transaction to normalize to/from values
  preprocessProperties: (propertySet) ->
    {metaProperties} = @
    for property, value of propertySet when mp = metaProperties[property]
      propertySet[property] = mp.preprocessor value, @[mp.internalName]
    propertySet

  getPendingPropertyValues: (propertyNames) ->
    ret = {}
    for property in propertyNames when metaProp = @metaProperties[property]
      ret[property] = @_pendingState[metaProp.internalName]
    ret

  getPropertyValues: (propertyNames) ->
    ret = {}
    for property in propertyNames when metaProp = @metaProperties[property]
      ret[property] = @[metaProp.internalName]
    ret

  minimalPropsIngore = ["children", "parent"]
  @getter
    props: ->
      ret = {}
      for k, {virtual} of @metaProperties
        ret[k] = @[k]
      ret

    concreteProps: ->
      ret = {}
      for k, {internalName, virtual} of @metaProperties when !virtual
        ret[k] = @[internalName]
      ret

    virtualProps: ->
      ret = {}
      for k, {virtual} of @metaProperties when virtual
        ret[k] = @[k]
      ret

    # conrete props which are not the default values
    minimalProps: ->
      ret = {}
      ret.currentLocation = @currentLocation unless point0.eq @currentLocation
      for k, {externalName, internalName, virtual, defaultValue} of @metaProperties
        unless virtual
          unless externalName in minimalPropsIngore
            unless propsEq defaultValue, value = @[internalName]
              ret[k] = value
      ret

    changingProps: ->
      object @_pendingState,
        when: (v, k) => @[k] != v
        with: (v, k) =>
          old: @[k]
          new: v


  @getConcreteProps: ->
    for k, mp of @getMetaProperties() when !mp.virtual
      k

  ##########################
  # OVERRIDES
  ##########################
  preprocessForEpoch: ->

  ##########################
  # EPOCHED STATE
  ##########################

  onNextReady:  (callback, forceEpoch = true) -> stateEpoch.onNextReady callback, forceEpoch, @
  @onNextReady: (callback, forceEpoch = true) -> stateEpoch.onNextReady callback, forceEpoch
  onNextEpoch:  (callback, forceEpoch = true) -> globalEpochCycle.onNextReady callback, forceEpoch, @
  @onNextEpoch: (callback, forceEpoch = true) -> globalEpochCycle.onNextReady callback, forceEpoch
  onIdle:       (callback) -> stateEpoch.onNextReady callback

  getState: (pending = false) -> if pending then @_pendingState else @
  getPendingState: -> @_pendingState


  ######################
  # CONSTRUCTOR
  ######################
  constructor: (options = blankOptions)->
    super

    @_initFields()

    @_initProperties options

  _initFields: ->
    @_pendingState = {}
    @__stateEpochCount = 0
    @__stateChangeQueued = false

    @__layoutPropertiesChanged = false
    @__drawAreaChanged = true
    @__drawPropertiesChanged = true

  ######################
  # PRIVATE: PROPS
  ######################

  ###
  TODO: 2018-4-17 I'll bet that we can get a big speedup by using
  the "_generateSetPropertyDefaults" pattern to:

    a)  inline pending state fields
    b)  _applyStateChanges with no loop

  RefactorSteps:

    0) design "real-world" object creation test
    1) rename @_pendingState to ensure no external dependencies
    2) add postCreate to run _generateSetPropertyDefaults and our
       new _applyStateChanges function
  ###
  @_generateSetPropertyDefaults: ->
    propertyInitializerList = @getPropertyInitializerList()
    metaProperties = @getMetaProperties()
    functionString = compactFlattenAllFast(
      """
      (function(options) {
      var _pendingState = this._pendingState;
      var metaProperties = this.metaProperties;
      """
      for [k, v, externalName], i in propertyInitializerList

        value = if (defaultOverride = @::[defaultName = "default" + capitalize externalName]) != undefined
          if preprocessor = metaProperties[externalName].preprocessor
            @::[defaultName] = preprocessor defaultOverride
          "this.#{defaultName}"
        else if v == null || v == false || v == true || v == undefined || isNumber(v)
          v
        else
          # NOTE: metaPropererties approach seems slower on Safari.
          # "propertyInitializerList[#{i}][1]"
          # "propertyInitializerDefaultValuesList[#{i}]"
          "metaProperties.#{externalName}.defaultValue;"
        "this.#{k} = _pendingState.#{k} = #{value};"
      # NOTE: This seems to be slower than just scanning the options even though scanning the options is slowish.
      # for externalName, {setterName, virtual} of metaProperties when !virtual
      #   "if (options.#{externalName} != undefined) this.#{setterName}(options.#{externalName});"
      # for externalName, {setterName, virtual} of metaProperties when virtual
      #   "if (options.#{externalName} != undefined) this.#{setterName}(options.#{externalName});"
      "})"
    ).join "\n"
    eval functionString

  _initProperties: (options) ->
    {metaProperties} = @

    # TODO 2018-4-17: Do this in postCreate!
    unless @__proto__.hasOwnProperty "_initPropertiesAuto"
      @__proto__._initPropertiesAuto = @class._generateSetPropertyDefaults()

    # IMPRORTANT OPTIMIZATION NOTE:
    # Creating _initPropertiesAuto the first time we instantiate the class is 2-4x faster than:
    # {propertyInitializerList, _pendingState} = @
    # for internalName, defaultValue of propertyInitializerList
    #   @[internalName] = _pendingState[internalName] = defaultValue
    @_initPropertiesAuto options

    @setProperties options

    @_elementChanged true, true, true
    null

  _getChangingStateKeys: ->
    k for k, v of @_pendingState when !shallowPropsEq @[k], @_pendingState[k]

  _logPendingStateChanges: ->
    oldValues = {}
    newValues = {}
    for k, v of @_pendingState when !(k.match /^__/) && !plainObjectsDeepEq v, @[k]
      oldValues[k] = @[k]
      newValues[k] = v
    log "ElementBase pending state changes": element: @inspectedName, old: oldValues, new: newValues


  ######################
  # PRIVATE: STATE EPOCH
  ######################
  _getIsChangingElement: -> stateEpoch._isChangingElement @

  _elementChanged: (layoutPropertyChanged, drawPropertyChanged, drawAreaPropertyChanged)->
    {_pendingState} = @

    if layoutPropertyChanged
      if StateEpoch._stateEpochLayoutInProgress
        console.error "__layoutPropertiesChanged while _stateEpochLayoutInProgress"
      @__layoutPropertiesChanged  = true

    @__drawPropertiesChanged     = true if drawPropertyChanged
    @__drawAreaChanged           = true if drawAreaPropertyChanged

    unless @__stateChangeQueued
      @__stateChangeQueued = true
      stateEpoch._addChangingElement @

  ###
  TODO:
    It would probably be faster overall to:

      a) move all the __* properties out of _pendingState
        Probably just promote them to the Element itself
        DONE

      b) replace _pendingState with a new, empty object after _applyStateChanges
        SBD March-2016: I think this is still a good idea.
          @_pendingState currently contains every property.
          That's a lot of extra work every state epoch!
          The problem is, we currently rely on that in many places!
          One thing to perf-test: We could make an array of the names of props that changed.
            Then, _applyStateChanges could iterate through that array, pulling values out of @_pendingState.
            (in this scenario we would keep @_pendingState fully of all properties, as it currently is)

      c) for faster Element creation
        - could we just say the Element "consumes" the props passed to it on creation?
        - then we can alter that props object
        - every prop in the passed-in props object gets run through the preprocessors/validators
        - and the result is assigned back to the props object
        - then the props object BECOMES the first @_pendingState
        SBD March-2016: I'm less sure this makes sense.

      d) SBD March-2016
        I have no idea if this would work, but what would be really cool is if new
        elements could directly apply there initial properties rather then putting them through
        the state-epoch pending cycle. This would probalby be a huge savings for object creation,
        which currently is one of out biggest performance problems.

        The problem is, new elements still need to go through a StateEpoch for layout...

  ###
  _applyStateChanges: ->
    @__stateChangeQueued = false
    @__stateEpochCount++

    mergeInto @, @_pendingState
