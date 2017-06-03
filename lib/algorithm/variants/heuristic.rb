module Algorithm
  module Variants

    class Heuristic

      def run(orders = [], vehicles = [])
        raise NotImplementedError, "Subclasses must define `run`."
      end

    end
  end
end
