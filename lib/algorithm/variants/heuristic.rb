module Algorithm
  module Variants

    class Heuristic

      #Override of ruby built in object initialization
      def initialize(company)
        @company = company unless company.nil?
      end

      def run(orders = [], vehicles = [])
        raise NotImplementedError, "Subclasses must define `run`."
      end

      def check_restriction(order_tours, driver)
        tour_stops = order_tours.to_a
        if @company.time_window_restriction?
            if time_window?(tour_stops, order, driver)
                return false
            end
        end

        if @company.capacity_restriction?
            if capacity?(tour_stops, driver)
                return false
            end
        end

        if @company.work_time_restriction?
            if working_time?(tour_stops, driver)
                return false
            end
        end
        true # liefert true, wenn alle Beschränkungen eingehalten werden
      end

      def calc_tour_duration(tour)
        tour_time = 0
        if tour.kind_of?(Array)
          tour.each do |order_tour|
            tour_time += order_tour.time # Fahrzeit
            if order_tour.duration # Manche Aufträge haben ggf. keine Arbeitszeit
                tour_time += order_tour.duration # Arbeitszeit
            end
          end
        else # gespeicherte Tour Relation
          tour.order_tours.each do |order_tour|
            tour_time += order_tour.time # Fahrzeit
            if order_tour.duration # Manche Aufträge haben ggf. keine Arbeitszeit
                tour_time += order_tour.duration # Arbeitszeit
            end
          end
        end
        # damit nicht durch 0 geteilt wird
        if tour_time == 0
            tour_time = 1
        end
        tour_time
      end

      # Berechnet die Zeit für die Fahrt von order_tour1 nach order_tour2
      def time_for_distance(order_tour1, order_tour2)
          # Google Maps
          driveTime = DriveTimeBetweenAddresses.new(order_tour1.location, order_tour2.location)
          time = driveTime.cached_drive_time_in_minutes()
          time # return
      end

      private

        def capacity?(tour, driver) # liefert true, wenn gegen restriction verstoßen wird
          tour.each_with_index do |order_tour, index|
              # Wenn eine bei einem Punkt in Tour die Capacity überschritten wird
              if order_tour.capacity_status > driver.vehicle.capacity
                  if @company.restriction == "PP" # Und es ein PP ist,...
                      #... dann soll ein Depot davor eingesetzt werden
                      depot = create_depot()
                      # Fahrzeug komplett entleeren
                      depot.capacity = tour[index-1]*-1
                      # Vor Verstoß einsetzen
                      tour.insert(index-1, depot)
                      # update capacity_status
                      tour = update_capacity(tour, index)
                  else
                      return true # Wenn es PDP ist, dann Verstoß
                  end
              elsif order_tour.capacity_status <= 0  # oder kleiner, gleich 0 ist
                  if @company.restriction == "DP" # Und es ein DP ist,...
                      #... dann soll ein Depot davor eingesetzt werden
                      depot = create_depot()
                      # Fahrzeug vollbeladen
                      depot.capacity = driver.capacity - tour[index-1]
                      # Vor Verstoß einsetzen
                      tour.insert(index-1, depot)
                      # Capacity_status updaten
                      tour = update_capacity(tour, index)
                  else
                      return true # Wenn es PDP ist, dann Verstoß
                  end
              end
          end
          return false
        end


        # Überprüfen ob Time Windows eingehalten werden
        def time_window?(tour, driver) # liefert true, wenn gegen restriction verstoßen wird
          time_now = Time.now.to_time.to_i # Jetziger Zeitpunkt in Unixtime
          # Jede Order_tour überprüfen, ob der Zeitpunkt im Zeitfenster von Order ist
          tour.each_with_index do |order_tour, index|
              # Zeit bis zu Order_tour
              tour_until = tour[0..index]
              time_until = calc_tour_time(tour_until)
              # time_now plus Zeit bis Order_time
              time_point = time_now + time_until
              # time_point nach end_time oder vor starttime
              if time_point > order_tour.order.end_time || time_point < order_tour.order.start_time
                  return true
              end
          end
          return false
        end

        # Überprüfen ob working time eingehalten wird
        # Kann dazu führen, kann das keine Tour gebildet wird! Passiert vor allem bei nur einem Fahrer
        def working_time?(tour, driver) # liefert true, wenn gegen restriction verstoßen wird
          # Prüfen ob die Tourdauer > als working_time vom Driver
          if calc_tour_duration(tour) > driver.working_time
              # true wenn tour zu lang ist
              return true
          end
          false
        end

        def create_vehicle_position(driver)
          # carrier.vehicle.position einsetzen als OrderTour
          vehicle_position = OrderTour.new
          vehicle_position.order_id = nil
          # tour_id wird in commit gesetzt
          # @company_id wird im algo gesetzt
          driver_vehicle = Vehicle.where(driver_id: driver.id).take
          vehicle_position.location = driver_vehicle.position
          # place (Platzierung) wird im commit gesetzt
          vehicle_position.comment = "Start der Tour"
          vehicle_position.kind = "position"
          vehicle_position.capacity = 0
          vehicle_position.capacity_status = 0
          vehicle_position.time = 0 # Keine Zeit vergangen
          vehicle_position.duration = 0 # Keine Zeit benötigt
          vehicle_position
        end

        def create_home(vehicle_position)
          # home = @company.address
          home = OrderTour.new
          #home.user_id = user.id
          home.order_id = nil
          # tour_id wird in commit gesetzt
          # @company_id wird im algo gesetzt
          home.location = @company.address
          # place (Platzierung) wird im commit gesetzt
          home.comment = "Ende der Tour"
          home.kind = "home"
          home.capacity = 0
          # capacity_status (Ladestatus Fahrzeug) wird im algo gesetzt
          home.time = time_for_distance(vehicle_position, home)
          home.duration = 0 # Keine Zeit benötigt
          home
        end

        # erstellt OrderTour depot
        def create_depot(location)
          # depot = @company.depot
          depot = OrderTour.new
          depot.order_id = nil
          # tour_id wird in commit gesetzt
          # @company_id wird in commit gesetzt
          company_depot = Depot.where(company_id: @company.id).take
          depot.location = company_depot.address
          # place wird im algo gesetzt
          depot.comment = "Warenbestand auffüllen"
          depot.kind = "depot"
          # Cpacity wird im Algo gesetzt - Fahrzeug soll voll beladen oder entladen werden
          # capacity_status wird in algo gesetzt
          depot.time = time_for_distance(location, depot)
          depot.duration = company_depot.duration
          depot
        end

        def create_delivery(order)
          order_tour_delivery = OrderTour.new
          # user_id wird in commit gesetzt
          order_tour_delivery.order_id = order.id
          # tour_id wird in commit gesetzt
          # @company_id wird in commit gesetzt
          order_tour_delivery.location = order.delivery_location
          # place (Plazierung) wird im algo gesetzt
          order_tour_delivery.comment = order.comment
          order_tour_delivery.kind = "delivery"
          # Nur bei Capacity Restriction wichtig
          if @company.capacity_restriction?
              order_tour_delivery.capacity = order.capacity*-1 # negativ weil entladen wird
          else
              order_tour_delivery.capacity = 0
          end
          # capacity_status (Ladestatus Fahrzeug) wird im algo gesetzt
          # time wird im Algo gesetzt
          order_tour_delivery.duration = order.duration_delivery
          # latitude/longitude werden von Geocoder gesetzt
          order_tour_delivery
        end

        def update_time(order_tours, index)
          order_tours[index].time = time_for_distance(order_tours[index - 1], order_tours[index])
        end
    end
  end
end
