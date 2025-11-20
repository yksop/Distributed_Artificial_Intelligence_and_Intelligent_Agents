/**
 * Name: FestivalAssignment
 * Description: Assignment 2 - Dutch Auction COMPLETE BASE VERSION
 * Features: Items with genres, selective participation, FIPA protocol
 * Author: Complete Implementation
 */
model FestivalAssignment

global {
	int num_guests <- 15;
	int num_stores <- 6;
	int num_water_stores <- 0;
	int num_food_stores <- 0;
	int store_counter <- 0;
	InformationCenter info_center;
	float guestSpeed <- 0.01 / 1.5;
	int max_auctions <- 4;
	int guestsWillingToAuction <- 0;
	int total_auctions <- 0;
	int successful_auctions <- 0;
	int cancelled_auctions <- 0;
	float total_revenue <- 0.0;
	int auctioneer_spawn_time <- 3000;
	bool auctioneer_spawned <- false;

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

		// create Auctioneer number: 1 {
		// location <- {20, 80};
		// }
		write "FESTIVAL SIMULATION STARTED";
		write "Guests: " + num_guests;
		write "Auctioneer will appear after " + auctioneer_spawn_time + " cycles";
	}

	reflex spawn_auctioneer when: !auctioneer_spawned and cycle >= auctioneer_spawn_time {
		create Auctioneer number: 1 {
			location <- {20, 80};
		}

		auctioneer_spawned <- true;
		write "\n*** AUCTIONEER HAS APPEARED! ***\n";
	}

	reflex print_stats when: every(1000 #cycles) {
		write "\n--- AUCTION STATISTICS ---";
		write "Total auctions: " + total_auctions;
		write "Successful: " + successful_auctions;
		write "Cancelled: " + cancelled_auctions;
		if (total_auctions > 0) {
			write "Success rate: " + (successful_auctions / total_auctions * 100) + "%";
		}

		write "Total revenue: $" + total_revenue;
		write "-------------------------\n";
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

species Guest skills: [moving, fipa] {
	bool hunger <- false;
	bool thirst <- false;
	string my_need <- nil;
	InformationCenter my_info_center;
	Store target_store <- nil;
	bool going_to_info <- false;
	float my_max_price <- rnd(15.0, 50.0);
	bool willing_to_auction <- false;

	aspect base {
		rgb my_color <- #orange;
		if (target_store != nil) {
			my_color <- #lightblue;
		} else if (willing_to_auction) {
			my_color <- #violet;
		}

		draw circle(1.5) color: my_color;
	}

	reflex handle_auction_messages {
		if (!empty(informs)) {
			loop msg over: informs {
				willing_to_auction <- false;
			}

		}

	}

	reflex participate_in_auction when: willing_to_auction and !empty(cfps) {
		message cfp <- cfps[0];
		list content_list <- list(cfp.contents);
		float offered_price <- float(content_list[0]);
		if (my_max_price >= offered_price) {
			do propose with: [message: cfp, contents: [offered_price]];
			willing_to_auction <- false;
		} else {
			do refuse with: [message: cfp, contents: ['Price too high']];
		}

	}

	reflex receive_accept when: !empty(accept_proposals) {
		willing_to_auction <- false;
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
				going_to_info <- false;
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
			if (flip(0.45) and !willing_to_auction) {
				willing_to_auction <- true;
				guestsWillingToAuction <- guestsWillingToAuction + 1;
			}

			if (flip(0.35) and !willing_to_auction) {
				if (flip(0.5)) {
					hunger <- true;
				} else {
					thirst <- true;
				}

				going_to_info <- true;
			}

		} } }

species Auctioneer skills: [fipa] {
	float current_price;
	int auction_count <- 0;
	float starting_price <- 100.0;
	float min_price <- 10.0;
	float price_decrement <- 5.0;
	bool auction_running <- false;
	bool item_sold <- false;
	int time_counter <- 0;
	int round_duration <- 80;
	int wait_before_start <- 150;
	int cooldown_between_auctions <- 300;

	aspect base {
		rgb auctioneer_color <- auction_running ? #purple : #gray;
		draw circle(3) color: auctioneer_color;
		if (auction_running) {
			draw "AUCTION" at: location + {0, 5} color: #white font: font("default", 10, #bold);
			draw "$" + current_price at: location + {0, 1} color: #lime font: font("default", 12, #bold);
		} else {
			draw "Next auction" at: location + {0, 3} color: #darkgray font: font("default", 8);
			int cycles_left <- max([0, wait_before_start - time_counter]);
			draw "in " + cycles_left + " cycles" at: location + {0, 1} color: #darkgray font: font("default", 7);
		}

	}

	reflex start_auction when: !auction_running and !item_sold and time_counter >= wait_before_start and guestsWillingToAuction >= 3 {
		total_auctions <- total_auctions + 1;
		write "Guests willing to bid: " + guestsWillingToAuction;
		current_price <- starting_price;
		time_counter <- 0;
		write "NEW DUTCH AUCTION STARTED";
		write "Starting price: $" + starting_price;
		write "Minimum price: $" + min_price;
		write "Price reduction: $" + price_decrement + " per round\n";
		do start_conversation to: list(Guest) protocol: "fipa-contract-net" performative: "cfp" contents: [current_price];
		auction_running <- true;
	}

	reflex manage_auction when: auction_running and !item_sold {
		time_counter <- time_counter + 1;
		if (!empty(proposes)) {
			message proposal <- first(proposes);
			agent winner <- agent(proposal.sender);
			write "ITEM SOLD";
			write "Winner: " + winner.name;
			do accept_proposal message: proposal contents: ["You won!"];
			ask Guest {
				if (self != winner) {
					willing_to_auction <- false;
				}

			}

			item_sold <- true;
			auction_running <- false;
			successful_auctions <- successful_auctions + 1;
			total_revenue <- total_revenue + current_price;
			time_counter <- 0;
			guestsWillingToAuction <- 0;
		}

		if (!item_sold and time_counter mod round_duration = 0 and time_counter > 0) {
			current_price <- current_price - price_decrement;
			if (current_price < min_price) {
				write "AUCTION CANCELLED";
				write "Price dropped below minimum ($" + min_price + ")";
				write "No buyers found\n";
				ask Guest {
					willing_to_auction <- false;
				}

				auction_running <- false;
				cancelled_auctions <- cancelled_auctions + 1;
				time_counter <- 0;
			} else {
				write "Price reduced to: $" + current_price color: #orange;
				do start_conversation to: list(Guest) protocol: "fipa-contract-net" performative: "cfp" contents: [current_price];
			}

		}

	}

	reflex prepare_next_auction when: !auction_running {
		time_counter <- time_counter + 1;
		if (time_counter >= cooldown_between_auctions) {
			item_sold <- false;
			time_counter <- 0;
			ask Guest {
				willing_to_auction <- false;
			}

		}

	}

}

experiment FestivalSimulation type: gui {
	output {
		display main_display {
			species Guest aspect: base;
			species Store aspect: base;
			species InformationCenter aspect: base;
			species Auctioneer aspect: base;
		}

		monitor "Active Auctions" value: length(Auctioneer where each.auction_running);
		monitor "Total Auctions" value: total_auctions;
		monitor "Successful Sales" value: successful_auctions;
		monitor "Cancelled Auctions" value: cancelled_auctions;
		monitor "Total Revenue" value: total_revenue with_precision 2;
		monitor "Average Sale Price" value: successful_auctions > 0 ? total_revenue / successful_auctions : 0.0 with_precision 2;
	}

}
