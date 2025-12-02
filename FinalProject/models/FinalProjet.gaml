/**

* Name: NewModel

* Based on the internal skeleton template. 

* Author: Agata Mazzani, Daniele Priola, Jacopo Veronese

* Tags: 

*/
model FinalProject

global {
	point entrance_door <- {15, 88};
	point bar_counter <- {85, 60};
	int maxNumGuestsInQueue <- 10;
	int queue_spacing <- 2;
	Bouncer the_bouncer <- nil;
	Barman the_barman <- nil;
	geometry dance_floor <- polygon([{0, 0}, {100, 0}, {100, 50}, {0, 50}]);
	geometry bar <- polygon([{30, 50}, {100, 50}, {100, 85}, {30, 85}]);
	geometry chill_area <- polygon([{0, 50}, {30, 50}, {30, 85}, {0, 85}]);
	geometry entrance <- polygon([{0, 85}, {100, 85}, {100, 100}, {0, 100}]);
	list<geometry> zone_shapes <- [dance_floor, bar, chill_area, entrance];
	list<rgb> zone_colors <- [#purple, #blue, #green, #darkred];

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
}

species Bouncer parent: Person {

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

	aspect default {
		draw circle(1.5) color: #black border: #white;
	}

}

species Barman parent: Person {

	reflex giveDrink when: !empty(requests) {
		message cfp <- requests[0];
		list content_list <- list(cfp.contents);
		int alcohoLevel <- int(content_list[0]);
		if (alcohoLevel <= 80) {
			do agree message: cfp contents: ['Y'];
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
	point target <- nil;
	int alcohoLevel <- rnd(0, 50);

	reflex moveTowardsEntrance {
		if (!is_inside) {
			do goto target: entrance_door speed: 0.5;
		}

	}

	reflex ask_to_enter when: !is_inside and (location distance_to entrance_door) < 2.0 {
		if (the_bouncer != nil) {
			do start_conversation to: [the_bouncer] protocol: 'fipa-request' performative: 'request' contents: [age];
		}

	}

	reflex listen_bouncer when: !empty(mailbox) {
		message cfp <- mailbox[0];
		list content_list <- list(cfp.contents);
		string decision <- content_list[0];
		if (decision = 'Y') {
			is_inside <- true;
			target <- any_location_in(chill_area);
			do goto target: target speed: 1.0;
		} else {
			do die;
		}

	}

	reflex getDrinks when: alcohoLevel <= 50 and is_inside {
		target <- bar_counter;
		do goto target: target speed: 1.0;
		do start_conversation to: [the_barman] protocol: 'fipa-request' performative: 'request' contents: [alcohoLevel];
	}

	reflex listen_barman when: !empty(mailbox) and is_inside {
		message cfp <- mailbox[0];
		list content_list <- list(cfp.contents);
		string decision <- content_list[0];
		if (decision = 'Y') {
			alcohoLevel <- alcohoLevel + 10;
		}

	}

}

species Dancer parent: Guest {

	reflex dance when: is_inside and alcohoLevel > 50 {
		target <- any_location_in(dance_floor);
		do goto target: target speed: 1.0;
	}

	aspect default {
		draw circle(1) color: #white;
	}

}

species ShyPerson parent: Guest {

	reflex dance when: is_inside and alcohoLevel > 70 {
		target <- any_location_in(dance_floor);
		do goto target: target speed: 1.0;
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
		}

	}

}

