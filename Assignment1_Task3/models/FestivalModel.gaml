/**

 * Name: FestivalAssignment

 * Description: Assignment1, Task3

 * Author: Agata Mazzani, Daniele Priola, Jacopo Veronese

 */
model FestivalAssignment

global {
	int num_guests <- 15;
	int num_stores <- 3;
	float totalDistance;
	InformationCenter info_center;
	float guestSpeed <- 0.001;
	float guardSpeed <- guestSpeed * 4;
	float distanceThreshold <- 2.0;
	float meetTroubleMakerThreshold <- distanceThreshold * 20;

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
			add self to: my_info_center.totalGuests;
		}

		create SecurityGuard number: 1 {
			location <- {rnd(0, 100), rnd(0, 100)};
		}

	}

}

species SecurityGuard skills: [moving] {
	Guest troubleMakerToChase <- nil;

	aspect base {
		draw circle(1.5) color: #black;
	}

	reflex chaseTroubleMaker when: troubleMakerToChase != nil {
		do goto target: troubleMakerToChase.location speed: guardSpeed;
		if (!dead(troubleMakerToChase)) {
			if (troubleMakerToChase != nil) {
				if (self.location distance_to troubleMakerToChase.location < distanceThreshold) {
					ask troubleMakerToChase as: Guest {
						do die;
					}

					troubleMakerToChase <- nil;
					ask InformationCenter {
						self.troubleMakers <- nil;
					}

				}

			}

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
	list<Guest> totalGuests;
	list<Guest> troubleMakers;

	aspect base {
		draw triangle(2) color: #yellow;
	}

	reflex callSecurityGuard {
		if (!empty(troubleMakers)) {
			ask SecurityGuard {
				if (self.troubleMakerToChase = nil) {
					do goto target: myself.location speed: guardSpeed;
					if (self.location distance_to myself.location < distanceThreshold) {
						self.troubleMakerToChase <- first(myself.troubleMakers);
						remove self.troubleMakerToChase from: myself.troubleMakers;
					}

				}

			}

		}

	}

	Store find_store_for (string need) {
		float dist <- 99999.9;
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
	bool isTroubleMaker <- false;
	bool reporting_troublemaker <- false;
	Guest troublemaker_to_report <- nil;

	aspect base {
		if (going_to_info) {
			draw circle(1.5) color: #yellow;
		} else if (target_store != nil and thirst) {
			draw circle(1.5) color: #lightblue;
		} else {
			draw circle(1.5) color: #orange;
		}

		if (isTroubleMaker) {
			draw circle(1.5) color: #red;
		}

	}

	reflex meetTroubleMakers when: !reporting_troublemaker and !isTroubleMaker {
		loop guest over: my_info_center.totalGuests {
			if (self distance_to guest < meetTroubleMakerThreshold and !dead(guest) and guest.isTroubleMaker) {
				troublemaker_to_report <- guest;
				reporting_troublemaker <- true;
			}

		}

	}

	reflex reportTroubleMaker when: reporting_troublemaker and !isTroubleMaker {
		do goto target: my_info_center.location speed: guestSpeed;
		if (location distance_to my_info_center.location < distanceThreshold) {
			ask InformationCenter {
				if (!(myself.troublemaker_to_report in self.troubleMakers)) {
					add myself.troublemaker_to_report to: self.troubleMakers;
				}

			}

		}

		troublemaker_to_report <- nil;
		reporting_troublemaker <- !reporting_troublemaker;
	}

	reflex main_behaviors when: !reporting_troublemaker and !isTroubleMaker {
		if (going_to_info) {
			do goto target: my_info_center.location speed: guestSpeed;
			if (location distance_to my_info_center.location < distanceThreshold) {
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
			if (location distance_to target_store.location < distanceThreshold) {
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

			if (!isTroubleMaker) {
				tmp <- rnd(0, 100);
				if (tmp >= 95) {
					isTroubleMaker <- true;
				}

			}

			if (hunger = true or thirst = true) {
				going_to_info <- true;
			} } }

	reflex makeTroubles when: isTroubleMaker {
		do wander speed: 1 / 25 bounds: square(100) amplitude: 120.0;
	} }

experiment FestivalSimulation type: gui {
	output {
		display main_display {
			species Guest aspect: base;
			species Store aspect: base;
			species InformationCenter aspect: base;
			species SecurityGuard aspect: base;
		}

	}

}

