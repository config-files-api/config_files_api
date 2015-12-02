module ConfigFilesApi
  # allows to place element at the end of configuration. Default one.
  class AppendPlacer
    def new_element(tree)
      res = {}
      tree.data << res

      res
    end
  end

  # Specialized placer, that allows to place config value before found one.
  # If noone is found, then append to the end
  # Useful, when config option should be inserted to specific location.
  class BeforePlacer
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

  # Specialized placer, that allows to place config value after found one.
  # If noone is found, then append to the end
  # Useful, when config option should be inserted to specific location.
  class AfterPlacer
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

  # Specialized placer, that allows to place config value instead of found one.
  # If noone is found, then append to the end
  # Useful, when value already exists and detected by matcher. Then easy add
  # with this placer replace it carefully to correct location.
  class ReplacePlacer
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
