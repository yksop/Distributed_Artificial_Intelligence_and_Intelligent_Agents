/**
 * Name: FestivalAssignment
 * Description: Assignment1, Task2
 * Author: Agata Mazzani, Daniele Priola, Jacopo Veronese
 */
model FestivalAssignment

global {
	int num_guests <- 1;
	int num_stores <- 6;
	int num_water_stores <- 0;
	int num_food_stores <- 0;
	int store_counter <- 0;
	float totalDistance;
	InformationCenter info_center;
	float guestSpeed <- 0.01 / 1.5;

	init {
		create InformationCenter number: 1 {
			location <- {50, 50};
		}

		info_center <- first(InformationCenter);
		create Store number: num_stores {
			store_id <- store_counter;
			store_counter <- store_counter + 1;
			if (flip(0.5)) {
				store_type <- "FOOD";
				num_food_stores <- num_food_stores + 1;
			} else {
				store_type <- "WATER";
				num_water_stores <- num_water_stores + 1;
			}

		}

		info_center.known_stores <- list(Store);
		create Guest number: num_guests {
			my_info_center <- info_center;
		}

	}

}

species Store {
	int store_id;
	string store_type;

	aspect base {
		if (store_type = "FOOD") {
			draw square(3) color: #darkorange;
		} else {
			draw square(3) color: #cyan;
		}

	}

}

species InformationCenter {
	list<Store> known_stores;

	aspect base {
		draw triangle(2) color: #yellow;
	}

	Store find_store_for (string need) {
		list<Store> candidates <- known_stores where (each.store_type = need);
		if empty(candidates) {
			return nil;
		}

		return one_of(candidates);
	}

}

species Guest skills: [moving] {
	bool hunger <- false;
	bool thirst <- false;
	list stateNull <- [false, false];
	list stateThirsty <- [false, true];
	list stateHungry <- [true, false];
	float need_threshold <- 80.0;
	string my_need <- nil;
	InformationCenter my_info_center;
	Store target_store <- nil;
	bool going_to_info <- false;
	list<Store> visitedStores <- nil;

	aspect base {
		if (going_to_info) {
			draw circle(1.5) color: #yellow;
		} else if (target_store != nil and thirst) {
			draw circle(1.5) color: #lightblue;
		} else {
			draw circle(1.5) color: #orange;
		}

	}

	reflex main_behaviors {
		if (going_to_info) {
			do goto target: my_info_center.location speed: guestSpeed;
			if (location distance_to my_info_center.location < 2.0) {
				if (thirst) {
					my_need <- "WATER";
				} else if (hunger) {
					my_need <- "FOOD";
				}

				target_store <- my_info_center.find_store_for(my_need);
				loop while: hasStoreBeenVisited(visitedStores, target_store) {
					target_store <- my_info_center.find_store_for(my_need);
				}

				add target_store to: visitedStores;

				// Controlla se ho visitato tutti gli store di questo tipo
 do checkAndResetVisitedStores(my_need);
				going_to_info <- false;
				float distance <- self distance_to target_store.location;
				totalDistance <- totalDistance + distance;
				write "Total covered distance:" + totalDistance;
			}

		} else if (target_store != nil) {
			do goto target: target_store.location speed: guestSpeed;
			if (location distance_to target_store.location < 2.0) {
				thirst <- false;
				hunger <- false;
				target_store <- nil;
			}

		} else if (target_store = nil) {
			do wander speed: guestSpeed;
			int tmp <- rnd(1, 3);
			if (tmp = 1) {
				hunger <- false;
				thirst <- false;
			} else if (tmp = 2) {
				hunger <- true;
				thirst <- false;
			} else if (tmp = 3) {
				hunger <- false;
				thirst <- true;
			}

			if (hunger = true or thirst = true) {
				going_to_info <- true;
			} } }

	bool hasStoreBeenVisited (list<Store> listOfStores, Store assignedStore) {
		bool res <- false;
		loop store over: listOfStores {
			if (store.store_id = assignedStore.store_id) {
				res <- true;
			}

		}

		return res;
	}

	action checkAndResetVisitedStores (string storeType) {
		int totalStoresOfType <- length(my_info_center.known_stores where (each.store_type = storeType));
		int visitedStoresOfType <- length(visitedStores where (each.store_type = storeType));
		if (visitedStoresOfType >= totalStoresOfType) {
			visitedStores <- visitedStores where (each.store_type != storeType);
		}

	} }

experiment FestivalSimulation type: gui {
	output {
		display main_display {
			species Guest aspect: base;
			species Store aspect: base;
			species InformationCenter aspect: base;
		}

	}

}