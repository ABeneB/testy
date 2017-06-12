require "algorithm/variants/combinedtourpair"

module Algorithm
  module Variants

    class SavingsPlusPlus < Heuristic

      def run(orders = [], drivers = [])

        day_orders = orders
        day_drivers = drivers
        while day_orders.any? do
          day_tours = init(day_orders, day_drivers)
          optimize(day_tours)
          #saveTours(day_tours, day_orders, day_drivers)
        end
      end

      def init(day_orders, day_drivers)
        day_tours = []
        first_order = day_orders[0]
        driver = best_driver(first_order, day_drivers)
        day_orders.delete_at(0)
        if driver
          tour = build_trivial_tour(first_order, driver)
          day_tours.push(tour)
          day_orders.each_with_index do |order, index|
            #build trivial tour for every order
            trivial_tour = build_trivial_tour(order, driver)
            if check_restriction(trivial_tour.order_tours, driver)
              day_tours.push(trivial_tour)
              day_orders.delete_at(index)
            end
          end
          return day_tours
        else
          init(day_orders, day_drivers) # recursive call
        end
      end

      def optimize(day_tours)
        compatible_combined_tours = compatible_tour_pairs(day_tours)
        calc_and_add_savings(compatible_combined_tours)
        binding.pry
        while savings.any? do

        end
      end

      def saveTours
        # TODO
      end

      private

        def best_driver(order, drivers)
          #for identifying the best driver among possible drivers
          compatible_trivial_tours = []
          drivers.each do |driver|
            trivial_tour = build_trivial_tour(order, driver)
            if check_restriction(trivial_tour.order_tours, driver)
              compatible_trivial_tours.push(trivial_tour)
            end
          end

          unless compatible_trivial_tours.empty?
            #return tours with lowest tour duration
            best_trivial_tour = compatible_trivial_tours.min_by { |tour| tour.duration } # return tours with lowest tour duration
            return best_trivial_tour.driver
          end
          return nil
        end

        def build_trivial_tour(order, driver)
          trivial_tour = Tour.create(driver_id: driver.id, duration: 0)
          # startpostion einfügen
          vehicle_position = create_vehicle_position(driver)
          vehicle_position.tour = trivial_tour
          vehicle_position.place = 0
          vehicle_position.save

          #depot einfügen
          depot = create_depot(vehicle_position)
          depot.tour = trivial_tour
          depot.capacity = driver.vehicle.capacity # Fahrzeug vollbeladen
          depot.place = 1
          depot.save

          # home einfügen - entspricht unternehmensadresse
          home1 = create_home(depot, driver)
          home1.tour = trivial_tour
          home1.place = 2
          home1.save

          delivery = create_delivery(order)
          delivery.tour = trivial_tour
          delivery.time = time_for_distance(home1, delivery)
          delivery.duration = order.duration_delivery
          delivery.place = 3
          delivery.save

          home2 = create_home(depot, driver)
          home2.tour = trivial_tour
          home2.time = time_for_distance(delivery, home2)
          home2.place = 4
          home2.save

          # trivial_tour befüllen
          tour_container = []
          tour_container.push(vehicle_position)
          tour_container.push(depot)
          tour_container.push(home1)
          tour_container.push(delivery)
          tour_container.push(home2)

          return trivial_tour
        end

        # returns compatible combinations of day tours as array with [combined_tour, tour1, tour2]
        def compatible_tour_pairs(day_tours)
          tour_pairs = build_tour_pairs(day_tours)

          driver = day_tours[0].driver
          compatible_combined_tours = []
          tour_pairs.each do |tour1, tour2|
            # combine order_tours from two tours and remove redundant home and depot
            tour1_orders = tour1.order_tours
            tour2_orders = tour2.order_tours
            combined_tour = tour1_orders.values_at(0..(tour1_orders.length - 2)).concat(tour2_orders.values_at(2..(tour2_orders.length - 1)))
            # update of times for recently combined tour
            update_order_tour_times(combined_tour)
            if check_restriction(combined_tour, driver)
              combined_tour_pair = CombinedTourPair.new(tour1, tour2, combined_tour)
              compatible_combined_tours.push(combined_tour_pair)
            end
          end
          compatible_combined_tours
        end

        def build_tour_pairs(day_tours)
          #cartesian product of all day_tours without product of same tour and nil objects
          day_tours.product(day_tours).map { |x, y| [x, y] if x != y }.compact
        end

        def calc_and_add_savings(combined_tours)
          combined_tours.each_with_index do |combined_tour_pair, index|
            combined_tour_duration = calc_tour_time(combined_tour_pair.combined_tour)
            tour1_duration = calc_tour_time(combined_tour_pair.tour1)
            tour2_duration = calc_tour_time(combined_tour_pair.tour2)
            saving = (combined_tour_pair.tour1.duration + combined_tour_pair.tour2.duration) - combined_tour_duration
            combined_tours[index].saving = saving
          end
        end

        def update_order_tour_times(order_tours)
          order_tours.each_with_index do |order, index|
            unless index == (order_tours.length - 1)
            update_time(order_tours, index + 1)
            end
          end
        end
    end
  end
end
