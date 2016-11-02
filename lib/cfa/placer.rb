module CFA
  # Places a new {AugeasElement} into an {AugeasTree}.
  # Children of this abstract class implement different ways **where**
  # to place the entry.
  class Placer
    # @param  [AugeasTree] tree
    # @return [AugeasElement,Hash] the new element; it is empty!
    #   Note that the return value is actually a Hash; {AugeasElement}
    #   documents its structure.
    def new_element(tree)
      abstract_method(tree)
    end
  end

  # Places the new element at the end of the tree.
  class AppendPlacer < Placer
    def new_element(tree)
      res = {}
      tree.data << res

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

    def new_element(tree)
      index = tree.data.index(&@matcher)

      res = {}
      if index
        tree.data.insert(index, res)
      else
        tree.data << res
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

    def new_element(tree)
      index = tree.data.index(&@matcher)

      res = {}
      if index
        tree.data.insert(index + 1, res)
      else
        tree.data << res
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

    def new_element(tree)
      index = tree.data.index(&@matcher)
      res = {}

      if index
        tree.data[index] = res
      else
        tree.data << res
      end

      res
    end
  end
end
