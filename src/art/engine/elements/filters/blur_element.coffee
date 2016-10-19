Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './filter_element'

{defineModule} = Foundation

defineModule module, class BlurElement extends FilterElement
  defaultRadius: 10
  defaultCompositeMode: "replace"

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blur @radius * scale
