/**

 * Name: FestivalAssignment

 * Description: Assignment1, Task1

 * Author: Agata Mazzani, Daniele Priola, Jacopo Veronese

 */
model FestivalAssignment

global {
	int num_guests <- 15;
	int num_stores <- 3;
	float totalDistance;
	InformationCenter info_center;
	float guestSpeed <- 0.001 / 1.5;

	init {
		create InformationCenter number: 1 {
			location <- {50, 50};
		}

		info_center <- first(InformationCenter);
		create Store number: num_stores {
			store_type <- "FOOD";
		}

		create Store number: num_stores {
			store_type <- "WATER";
		}

		info_center.known_stores <- list(Store);
		create Guest number: num_guests {
			my_info_center <- info_center;
		}

	}

}

species Store {
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
		float dist <- 99999;
		Store res;
		loop store over: known_stores {
			if (need = store.store_type) {
				float tmp <- self distance_to store.location;
				if (tmp < dist) {
					dist <- tmp;
					res <- store;
				}

			}

		}

		write "Nearest store is store" + res;
		return res;
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

				ask InformationCenter {
					myself.target_store <- self.find_store_for(myself.my_need);
				}

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
			} } } }

experiment FestivalSimulation type: gui {
	output {
		display main_display {
			species Guest aspect: base;
			species Store aspect: base;
			species InformationCenter aspect: base;
		}

	}

}

