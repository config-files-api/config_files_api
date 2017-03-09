module CFA
  # Places a new {AugeasElement} into an {AugeasTree}.
  # @abstract Subclasses implement different ways **where**
  #   to place the entry by overriding {#new_element}.
  class Placer
    # @param  [AugeasTree] tree
    # @return [AugeasElement,Hash] the new element; it is empty!
    #   Note that the return value is actually a Hash; {AugeasElement}
    #   documents its structure.
    def new_element(_tree)
      raise NotImplementedError,
        "Subclasses of #{Module.nesting.first} must override #{__method__}"
    end

  protected

    def create_element
      { operation: :add }
    end
  end

  # Places the new element at the end of the tree.
  class AppendPlacer < Placer
    # (see Placer#new_element)
    def new_element(tree)
      res = create_element
      tree.data(filtered: false) << res

      res
    end
  end

  # Finds a specific element using a {Matcher} and places the new element
  # **before** it. Appends at the end if a match is not found.
  #
  # Useful when a config option should be inserted to a specific location,
  # or when assigning a comment to an option.
  class BeforePlacer < Placer
    # @param [Matcher] matcher
    def initialize(matcher)
      @matcher = matcher
    end

    # (see Placer#new_element)
    def new_element(tree)
      index = tree.data(filtered: false).index(&@matcher)

      res = create_element
      if index
        tree.data(filtered: false).insert(index, res)
      else
        tree.data(filtered: false) << res
      end

      res
    end
  end

  # Finds a specific element using a {Matcher} and places the new element
  # **after** it.  Appends at the end if a match is not found.
  #
  # Useful when a config option should be inserted to a specific location.
  class AfterPlacer < Placer
    # @param [Matcher] matcher
    def initialize(matcher)
      @matcher = matcher
    end

    # (see Placer#new_element)
    def new_element(tree)
      index = tree.data(filtered: false).index(&@matcher)

      res = create_element
      if index
        tree.data(filtered: false).insert(index + 1, res)
      else
        tree.data(filtered: false) << res
      end

      res
    end
  end

  # Finds a specific element using a {Matcher} and **replaces** it
  # with the new element.  Appends at the end if a match is not found.
  #
  # Useful in key-value configuration files where a specific key
  # needs to be assigned.
  class ReplacePlacer < Placer
    # @param [Matcher] matcher
    def initialize(matcher)
      @matcher = matcher
    end

    # (see Placer#new_element)
    def new_element(tree)
      index = tree.data(filtered: false).index(&@matcher)
      res = create_element

      if index
        # remove old one and add new one, as it can have different key
        # which cause problem to simple modify
        tree.data(filtered: false)[index][:operation] = :remove
        tree.data(filtered: false).insert(index + 1, res)
      else
        tree.data(filtered: false) << res
      end

      res
    end
  end
end
