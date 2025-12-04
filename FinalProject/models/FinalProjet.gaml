

/**
* Name: FinalProject
* Based on the internal skeleton template. 
* Author: Agata Mazzani, Daniele Priola, Jacopo Veronese
* Tags: 
*/
model FinalProject

global {
	point entrance_door <- {15, 88};
	point exit_door <- {85, 88};
	point bar_counter <- {85, 60};
	point dj_point <- {25, 25};
	int maxNumGuestsInQueue <- 50;
	int queue_spacing <- 2;
	Bouncer the_bouncer <- nil;
	Barman the_barman <- nil;
	ResidentDJ dj <- nil;
	int playing_song <- -1;
	geometry dance_floor <- polygon([{0, 0}, {100, 0}, {100, 50}, {0, 50}]);
	geometry bar <- polygon([{30, 50}, {100, 50}, {100, 85}, {30, 85}]);
	geometry chill_area <- polygon([{0, 50}, {30, 50}, {30, 85}, {0, 85}]);
	geometry entrance <- polygon([{0, 85}, {100, 85}, {100, 100}, {0, 100}]);
	list<geometry> zone_shapes <- [dance_floor, bar, chill_area, entrance];
	list<rgb> zone_colors <- [#purple, #blue, #green, #darkred];
	float global_happiness <- 0.0;
	int current_tick <- 0;
	bool is_closing <- false;

	reflex update_stats {
		current_tick <- current_tick + 1;
		list<Guest> all_guests <- (Dancer where (each.is_inside)) + (ShyPerson where (each.is_inside));
		if (length(all_guests) > 0) {
			global_happiness <- mean(all_guests collect each.happiness);
		}

	}

	init {
		create Zone number: length(zone_shapes) {
			shape <- zone_shapes[index];
			color <- zone_colors[index];
		}

		create Dancer number: maxNumGuestsInQueue / 2 {
			location <- {entrance_door.x + index * queue_spacing, entrance_door.y};
			age <- 18 + rnd(10);
		}

		create ShyPerson number: maxNumGuestsInQueue / 2 {
			location <- {entrance_door.x + index * queue_spacing + maxNumGuestsInQueue / 2 * queue_spacing, entrance_door.y};
			age <- 18 + rnd(10);
		}

		create Bouncer number: 1 {
			location <- {11, 83};
			the_bouncer <- self;
		}

		create Barman number: 1 {
			location <- bar_counter;
			the_barman <- self;
		}

		create ResidentDJ number: 1 {
			location <- dj_point;
			dj <- self;
		}

	}

	reflex sync_song {
		if (dj != nil) {
			playing_song <- dj.current_song;
		}

	}

}

species Zone {
	geometry shape;
	rgb color;

	aspect default {
		draw shape color: color border: #white;
	}

}

species Person skills: [moving, fipa] {
	int age;
}

species ResidentDJ parent: Person {
	list<int> song_queue <- [];
	int current_song <- -1;
	int song_timer <- 0;

	reflex play_songs {
		if (current_song = -1 and !empty(song_queue)) {
			current_song <- song_queue[0];
			song_timer <- 20;
		}

		if (current_song != -1) {
			song_timer <- song_timer - 1;
			if (song_timer <= 0) {
				current_song <- -1;
				remove song_queue[0] from: song_queue;
			}

		}

	}

	reflex answer_requests when: !empty(requests) {
		message req <- requests[0];
		list content <- list(req.contents);
		int requested_song <- int(content[0]);
		if (length(song_queue) > 10) {
			do refuse message: req contents: ['N'];
		} else {
			add requested_song to: song_queue;
			do agree message: req contents: ['Y'];
		}

	}

	aspect default {
		draw circle(2) color: #yellow;
	}

}

species Bouncer parent: Person {
	Guest chasing_target <- nil;

	reflex answer_guests when: !empty(requests) {
		message cfp <- requests[0];
		list content_list <- list(cfp.contents);
		int guest_age <- int(content_list[0]);
		if (guest_age >= 21) {
			do agree message: cfp contents: ['Y'];
		} else {
			do refuse with: [message: cfp, contents: ["N"]];
		}

	}

	reflex check_drunk_guests when: chasing_target = nil {
		list<Guest> drunk_guests <- Guest where (each.is_inside and each.alcohoLevel > 74 and !each.is_leaving);
		if (!empty(drunk_guests)) {
			chasing_target <- one_of(drunk_guests);
		}

	}

	reflex chase_drunk when: chasing_target != nil and !dead(chasing_target) {
		do goto target: chasing_target speed: 1.5;
		if (self distance_to chasing_target < 2.0) {
			ask chasing_target {
				is_leaving <- true;
			}

			chasing_target <- nil;
		}

	}

	reflex reset_chase when: chasing_target != nil and (dead(chasing_target) or chasing_target.is_leaving) {
		chasing_target <- nil;
		location <- {11, 83};
	}

	aspect default {
		draw circle(1.5) color: #black border: #white;
	}

}

species Barman parent: Person {
	float impatience <- rnd(0.1, 0.9); // change this in final report to see how happiness changes over time
	float generosity <- rnd(0.1, 0.9); // change this in final report to see how happiness changes over time
	reflex giveDrink when: !empty(requests) {
		message cfp <- requests[0];
		list content_list <- list(cfp.contents);
		int alcohoLevel <- int(content_list[0]);
		int alcohol_tolerance_limit <- int(30 + (impatience * 35));
		bool alcohol_check;
		if (alcohoLevel > alcohol_tolerance_limit) {
			alcohol_check <- false;
		} else {
			alcohol_check <- true;
		}

		if (alcohol_check) {
			do agree message: cfp contents: ['Y', generosity];
		} else {
			do refuse with: [message: cfp, contents: ["N"]];
		}

	}

	aspect default {
		draw circle(1) color: #brown;
	}

}

species Guest parent: Person {
	bool is_inside <- false;
	bool is_dancing <- false;
	bool is_leaving <- false;
	point target <- nil;
	int alcohoLevel <- rnd(0, 50);
	float happiness <- 0.5;
	int time_inside <- 0;
	int time_since_last_drink <- 0;

	reflex moveTowardsEntrance {
		if (!is_inside and !is_leaving) {
			do goto target: entrance_door speed: 0.5;
		}

	}

	reflex ask_to_enter when: !is_inside and !is_leaving and (location distance_to entrance_door) < 2.0 {
		if (the_bouncer != nil) {
			do start_conversation to: [the_bouncer] protocol: 'fipa-request' performative: 'request' contents: [age];
		}

	}

	reflex checkMail when: !empty(mailbox) {
		message cfp <- mailbox[0];
		list content_list <- list(cfp.contents);
		string decision <- content_list[0];
		if (agent(cfp.sender) = the_bouncer) {
			if (decision = 'Y') {
				is_inside <- true;
				target <- any_location_in(chill_area);
			} else {
				do die;
			}

		} else if (agent(cfp.sender) = the_barman) {
			if (decision = 'Y') {
				float generosity <- float(content_list[1]);
				alcohoLevel <- min([alcohoLevel + 40, 100]);
				happiness <- min([(happiness + 0.1) * generosity, 1.0]);
				time_since_last_drink <- 0;
			}

		} else if (agent(cfp.sender) = dj) {
			if (decision = 'N') {
				happiness <- happiness - 0.1;
			}

		} }

	reflex getDrinks when: alcohoLevel <= 50 and is_inside and !is_leaving {
		is_dancing <- false;
		target <- bar_counter;
		do goto target: target speed: 1.0;
		if (self distance_to target < 1.5) {
			do start_conversation to: [the_barman] protocol: 'fipa-request' performative: 'request' contents: [alcohoLevel];
		}

	}

	reflex go_relax when: is_inside and !is_leaving and flip(0.01) {
		is_dancing <- false;
		target <- any_location_in(chill_area);
		do goto target: target speed: 0.8;
		if (location distance_to target < 3.0 and flip(0.05)) {
			happiness <- min([happiness + 0.05, 1.0]);
		}

	}

	reflex decrease_alcohol when: is_inside and flip(0.05) {
		alcohoLevel <- max([alcohoLevel - 2, 0]);
		time_since_last_drink <- time_since_last_drink + 1;
	}

	reflex decrease_happiness when: is_inside and flip(0.03) {
		happiness <- max([happiness - 0.02, 0.0]);
	}

	reflex leave_club when: is_leaving {
		is_dancing <- false;
		target <- exit_door;
		do goto target: target speed: 1.0;
		if (self distance_to exit_door < 2.0) {
			do die;
		}

	} }

species Dancer parent: Guest {
	int my_song <- [];
	bool isGoingToDJ;

	init {
		my_song <- rnd(1, 10);
		isGoingToDJ <- false;
	}

	reflex dance when: is_inside and alcohoLevel > 50 and !is_leaving and !isGoingToDJ and flip(0.8) {
		target <- any_location_in(dance_floor);
		do goto target: target speed: 1.0;
		is_dancing <- true;
		happiness <- min([happiness + 0.01, 1.0]);
	}

	reflex go_chill when: is_inside and alcohoLevel <= 50 and !is_leaving and !isGoingToDJ {
		target <- any_location_in(chill_area);
		is_dancing <- false;
		do goto target: target speed: 0.8;
		if (location distance_to target < 3.0 and flip(0.1)) {
			target <- bar_counter;
		}

	}

	reflex take_break when: is_inside and !is_leaving and is_dancing and !isGoingToDJ and flip(0.008) {
		is_dancing <- false;
		target <- any_location_in(chill_area);
		do goto target: target speed: 0.8;
	}

	reflex request_song when: is_inside and !is_leaving and flip(0.1) {
		isGoingToDJ <- true;
		int s <- one_of(my_song);
		target <- dj.location;
		do goto target: target speed: 1.0;
		if (self distance_to dj < 0.05) {
			isGoingToDJ <- false;
			do start_conversation to: [dj] protocol: "fipa-request" performative: "request" contents: [s];
		}

	}

	int last_song_tick <- 0;

	reflex enjoy_song when: playing_song != -1 and is_inside and !is_leaving and playing_song = my_song {
		happiness <- min([happiness + 0.25 / 20, 1.0]);
		last_song_tick <- cycle;
	}

	reflex post_song_drop when: playing_song = -1 and (cycle - last_song_tick) > 15 {
		happiness <- max([happiness - 0.05, 0.0]);
	}

	aspect default {
		draw circle(1) color: #black;
	}

}

species ShyPerson parent: Guest {
	int boredom <- 0;
	float dance_desire <- rnd(0.3, 0.7);

	reflex increase_boredom when: is_inside and !is_dancing {
		boredom <- boredom + 1;
	}

	reflex get_bored when: is_inside and boredom > 150 and !is_leaving {
		is_dancing <- false;
		if (alcohoLevel < 60) {
			target <- bar_counter;
			do goto target: target speed: 0.7;
			if (self distance_to target < 1.5) {
				do start_conversation to: [the_barman] protocol: 'fipa-request' performative: 'request' contents: [alcohoLevel];
				boredom <- 0;
			}

		} else {
			target <- any_location_in(chill_area);
			do goto target: target speed: 0.6;
			if (flip(0.1)) {
				boredom <- max([boredom - 10, 0]);
			}

		}

	}

	reflex call_dancer_for_boost when: is_inside and dance_desire < 0.4 and !is_dancing and flip(0.02) {
		list<Dancer> nearby_dancers <- Dancer where (each.is_inside and (each distance_to self) < 15);
		if (!empty(nearby_dancers)) {
			Dancer friend <- one_of(nearby_dancers);
			dance_desire <- dance_desire + 0.3;
			happiness <- happiness + 0.15;
			target <- any_location_in(dance_floor);
			is_dancing <- true;
			ask friend {
				self.is_dancing <- true;
			}

		}

	}

	reflex decrease_dance_desire when: is_inside and flip(0.05) {
		dance_desire <- max([dance_desire - 0.05, 0.0]);
	}

	reflex dance when: is_inside and alcohoLevel > 70 and dance_desire > 0.5 and !is_leaving and flip(0.7) {
		target <- any_location_in(dance_floor);
		do goto target: target speed: 1.0;
		is_dancing <- true;
		boredom <- 0;
		happiness <- min([happiness + 0.01, 1.0]);
	}

	reflex prefer_chill when: is_inside and !is_leaving and flip(0.015) {
		is_dancing <- false;
		target <- any_location_in(chill_area);
		do goto target: target speed: 0.6;
		if (location distance_to target < 3.0) {
			happiness <- min([happiness + 0.03, 1.0]);
			boredom <- max([boredom - 5, 0]);
		}

	}

	aspect default {
		draw circle(1) color: #pink;
	}

}

experiment FinalProject type: gui {
	output {
		display main_display background: #black {
			species Zone;
			species Guest;
			species Dancer;
			species ShyPerson;
			species Bouncer;
			species Barman;
			species ResidentDJ;
		}

		display charts {
			chart "Global Happiness Over Time" type: series {
				data "Average Happiness" value: global_happiness color: #green;
			}

		}

		monitor "Current Time" value: current_tick;
		monitor "Global Happiness" value: global_happiness;
		monitor "Guests Inside" value: length(Guest where each.is_inside);
		monitor "Club Status" value: is_closing ? "CLOSING" : "OPEN";
	}

	init {
		inspect "Agent Beliefs" value: (list(Dancer) + list(ShyPerson)) attributes: ['name', 'happiness', 'alcohoLevel', 'boredom'] type: table;
	}

}
