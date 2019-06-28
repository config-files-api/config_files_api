# typed: strong
# frozen_string_literal: true

module CFA
  # Places a new {AugeasElement} into an {AugeasTree}.
  # @abstract Subclasses implement different ways **where**
  #   to place the entry by overriding {#new_element}.
  class Placer
    # @overload new_element(tree)
    #   @param  [AugeasTree] tree
    #   @return [AugeasElement,Hash] the new element; it is empty!
    #     Note that the return value is actually a Hash; {AugeasElement}
    #     documents its structure.
    sig {params(_tree: T.untyped).void}
    def new_element(_tree)
    end

  protected

    sig {returns(T::Hash[T.untyped, T.untyped])}
    def create_element
    end
  end

  # Places the new element at the end of the tree.
  class AppendPlacer < Placer
    # (see Placer#new_element)
    sig {params(tree: T.untyped).void}
    def new_element(tree)
    end
  end

  # Finds a specific element using a {Matcher} and places the new element
  # **before** it. Appends at the end if a match is not found.
  #
  # Useful when a config option should be inserted to a specific location,
  # or when assigning a comment to an option.
  class BeforePlacer < Placer
    # @param [Matcher] matcher
    sig { params(matcher: Matcher).void }
    def initialize(matcher)
    end

    # (see Placer#new_element)
    sig {params(tree: T.untyped).void}
    def new_element(tree)
    end
  end

  # Finds a specific element using a {Matcher} and places the new element
  # **after** it.  Appends at the end if a match is not found.
  #
  # Useful when a config option should be inserted to a specific location.
  class AfterPlacer < Placer
    # @param [Matcher] matcher
    sig { params(matcher: Matcher).void }
    def initialize(matcher)
    end

    # (see Placer#new_element)
    sig {params(tree: T.untyped).void}
    def new_element(tree)
    end
  end

  # Finds a specific element using a {Matcher} and **replaces** it
  # with the new element.  Appends at the end if a match is not found.
  #
  # Useful in key-value configuration files where a specific key
  # needs to be assigned.
  class ReplacePlacer < Placer
    # @param [Matcher] matcher
    sig { params(matcher: Matcher).void }
    def initialize(matcher)
      @matcher = matcher
    end

    # (see Placer#new_element)
    sig {params(tree: T.untyped).void}
    def new_element(tree)
    end
  end
end
