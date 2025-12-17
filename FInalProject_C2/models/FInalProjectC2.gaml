

/**
* Name: FinalProjectC2
* Based on the internal skeleton template. 
* Author: Agata Mazzani, Daniele Priola, Jacopo Veronese
* Tags: 
*/

model FinalProjectC2

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
	int tot_refuse <- 0;
	

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
	int memory <- rnd(3, 10);
	int ego <- rnd(0, 1);
	int laziness <- rnd(0, 30);
	int break_timer <- 0;

	reflex play_manager {
		if (current_song != -1) {
			song_timer <- song_timer - 1;
			if (song_timer <= 0) {
				current_song <- -1;
				if (!empty(song_queue)) {
					remove song_queue[0] from: song_queue;
				}

				break_timer <- laziness;
			}

		} else if (break_timer > 0) {
			break_timer <- break_timer - 1;
		} else if (current_song = -1 and break_timer <= 0 and !empty(song_queue)) {
			current_song <- song_queue[0];
			song_timer <- 20;
		} }

	reflex answer_requests when: !empty(requests) {
		message req <- requests[0];
		list content <- list(req.contents);
		int requested_song <- int(content[0]);
		if (length(song_queue) > memory and flip(ego)) {
			do refuse message: req contents: ['N'];
		} else {
			add requested_song to: song_queue;
			do agree message: req contents: ['Y'];
		}

	}

	aspect default {
		draw circle(2) color: #yellow;
	} }

species Bouncer parent: Person {
	int guests_entered_in_batch <- 0;
	int batch_limit <- 20;
	int break_duration <- 100;
	int break_timer <- 0;
	Guest chasing_target <- nil;
	bool handelingQueue <- true;
	int guest_entered <- 0;
	bool is_taking_break <- false;
	float corrupted <- rnd(0.1, 0.9);

	reflex manage_break when: is_taking_break {
		break_timer <- break_timer - 1;
		color <- #red;
		if (break_timer <= 0) {
			is_taking_break <- false;
			guests_entered_in_batch <- 0;
			color <- #black;
			write "Bouncer: Pausa finita, avanti il prossimo!";
		}

	}

	reflex answer_guests when: !empty(requests) and !is_taking_break {
		handelingQueue <- true;

		loop while: !empty(requests) {
			message cfp <- requests[0];
			list content_list <- list(cfp.contents);
			int guest_age <- int(content_list[0]);
			if (guest_age >= 21) {
				do agree message: cfp contents: ['Y'];
				guests_entered_in_batch <- guests_entered_in_batch + 1;
				if (guests_entered_in_batch >= batch_limit) {
					is_taking_break <- true;
					break_timer <- break_duration;
					write "Bouncer: Ho fatto entrare 20 persone. Ora mi prendo una pausa.";
					break; 
				}

			} else if (flip(corrupted)){
				do agree message: cfp contents: ['Y'];
				write "ho fatto entrare un minorenne che non doveva";
			}
			else{
				do refuse with: [message: cfp, contents: ["N"]];	
			}

		}

		handelingQueue <- false; 
	}

	reflex check_drunk_guests when: chasing_target = nil and !handelingQueue and !is_taking_break {
		//list<Guest> drunk_guests <- (Guest where (each.is_inside and each.alcohoLevel > 90)) + (ShyPerson where (each.is_inside and each.alcohoLevel > 90));
		list<Guest> drunk_guests <- (Guest where (each.is_inside and each.alcohoLevel > 90)); //change to see when the bouncer goes to people
		if (!empty(drunk_guests)) {
			chasing_target <- one_of(drunk_guests);
			write "Bouncer: Ho trovato un ubriaco da buttare fuori!";
		}

	}

	reflex chase_drunk when: chasing_target != nil and !dead(chasing_target) and !handelingQueue {
		do goto target: chasing_target speed: 1.5;
		if (self distance_to chasing_target < 2.0) {
			ask chasing_target {
				write "Bouncer: Ubriaco buttato fuori!";
				do die;
			}

			location <- {11, 83};
			chasing_target <- nil;
		}

	}

	aspect default {
		draw circle(1.5) color: #black border: #white;
	}

}

species Barman parent: Person {
	float impatience <- rnd(0.1, 0.9); // change this in final report to see how happiness changes over time
	float generosity <- rnd(0.1, 0.9); // change this in final report to see how happiness changes over time
	int max_stock <- 600;
	int current_stock <- 600;
	bool is_restocking <- false;

	reflex giveDrink when: !empty(requests) {
    loop while: !empty(requests) {
        message cfp <- requests[0];
        list content_list <- list(cfp.contents);
        int alcohoLevel <- int(content_list[0]);
        
        remove cfp from: requests; 

        int alcohol_tolerance_limit <- int(30 + (impatience * 35));
        bool alcohol_check <- (alcohoLevel <= alcohol_tolerance_limit);

        if (alcohol_check and current_stock > 0) {
            current_stock <- current_stock - 1;
            do agree message: cfp contents: ['Y', generosity];
            if (current_stock = 0) {
                is_restocking <- true;
                write ("Bar is closed for restocking");
            }
        } else {
            tot_refuse <- tot_refuse + 1; 
            do refuse with: [message: cfp, contents: ["N"]];
        }
    }
}

	reflex stocking_process when: is_restocking {
		current_stock <- current_stock + 100;
		if (current_stock >= max_stock) {
			is_restocking <- false;
			write ("Bar is open again!");
		}

	}

	aspect default {
		draw circle(3) color: #brown;
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
	bool isGoingToDJ <- false;
	bool waiting_for_response <- false;
	int patience_timer <- 0;
	
	//variables for RL
	map<string, float> q_table <- [
		"soberDrink"::0.0, "soberDance"::0.0, "soberChill"::0.0,
        "tipsyDrink"::0.0, "tipsyDance"::0.0, "tipsyChill"::0.0,
        "drunkDrink"::0.0, "drunkDance"::0.0, "drunkChill"::0.0
    ];

    string last_state <- "";
    string last_action <- "";

    float alpha <- 0.5;      
    float gamma <- 0.9;      
    float epsilon <- 0.1;
    

	reflex moveTowardsEntrance {
		if (!is_inside and !is_leaving) {
			do goto target: entrance_door speed: 0.5;
		}

	}

	reflex ask_to_enter when: !is_inside and !is_leaving and (location distance_to entrance_door) < 2.0 and !waiting_for_response {
		if (the_bouncer != nil) {
			do start_conversation to: [the_bouncer] protocol: 'fipa-request' performative: 'request' contents: [age];
			waiting_for_response <- true;
			patience_timer <- 0;
		}

	}

	reflex wait_patience when: waiting_for_response {
		patience_timer <- patience_timer + 1;
		if (patience_timer > 50) {
			waiting_for_response <- false;
		}

	}

	reflex checkMail when: !empty(mailbox) {
		message cfp <- mailbox[0];
		list content_list <- list(cfp.contents);
		string decision <- content_list[0];
		if (agent(cfp.sender) = the_bouncer) {
			waiting_for_response <- false;
			if (decision = 'Y') {
				is_inside <- true;
				//target <- any_location_in(chill_area);
			} else if (decision = 'N') {
				do die;
			}

		} else if (agent(cfp.sender) = the_barman) {
	        waiting_for_response <- false; 
	        float reward <- 0.0;
	
	        if (decision = 'Y') {
	            reward <- 10.0; 
	            float generosity <- float(content_list[1]);
	            alcohoLevel <- min([alcohoLevel + 40, 100]);
	            happiness <- min([(happiness + 0.1) * generosity, 1.0]);
	        } else {
	            reward <- -10.0; 
	            happiness <- max([happiness - 0.1, 0.0]);
	        }
	
	        string key <- last_state + last_action; 
	        if (key in q_table) {
	            q_table[key] <- q_table[key] + alpha * (reward - q_table[key]);
	        }
	        
	        target <- nil; 
        	last_action <- "";   // Smette di eseguire "Drink"
		} else if (agent(cfp.sender) = dj) {
			if (decision = 'N') {
				happiness <- happiness - 0.1;
			}

		} }

	reflex decrease_alcohol when: is_inside and flip(0.05) {
		alcohoLevel <- max([alcohoLevel - 2, 0]);
		time_since_last_drink <- time_since_last_drink + 1;
	}

	reflex decrease_happiness when: is_inside and flip(0.03) {
		happiness <- max([happiness - 0.02, 0.0]);
	} 
	
	reflex getDrinks when: is_inside and !is_leaving and last_action = "Drink" and  !waiting_for_response{		
		if (target = nil) { target <- bar_counter; is_dancing <- false; }
        do goto target: target speed: 1.0;
        if (location distance_to target < 2.0) {
            do start_conversation to: [the_barman] protocol: 'fipa-request' performative: 'request' contents: [alcohoLevel];
            target <- nil; 
            waiting_for_response <- true; 
        }
	}
	
	
	string get_current_state {
	    if (alcohoLevel < 30) { return "sober"; }
	    else if (alcohoLevel <= 70) { return "tipsy"; }
	    else { return "drunk"; }
	}
	
	action choose_action {
	    string current_state <- get_current_state();
	    last_state <- current_state; 
	
	    string chosen_act <- "";
	
	    if (flip(epsilon)) {
	        chosen_act <- one_of(["Drink", "Dance", "Chill"]);
	        write name + " (" + current_state + ") -> SCELTA CASUALE: " + chosen_act;
	    }
	    else {
	        float val_drink <- q_table[current_state + "Drink"];
	        float val_dance <- q_table[current_state + "Dance"];
	        float val_chill <- q_table[current_state + "Chill"]; 
	        
	        write name + " (" + current_state + ") Voti -> Drink: " + val_drink + " | Dance: " + val_dance + " | Chill: " + val_chill;

	        if (val_drink >= val_dance and val_drink >= val_chill) {
	            chosen_act <- "Drink";
	        }

	        else if (val_dance >= val_drink and val_dance >= val_chill) {
	            chosen_act <- "Dance";
	        }
	        else {
	            chosen_act <- "Chill";
	        }
	    }
	
	    last_action <- chosen_act;
	}
	
	
	reflex activate_brain when: is_inside and !is_leaving and target = nil and !waiting_for_response {
		write "attivo rl";
	    do choose_action;
	    target <- nil; 
	}
	
	}

species Dancer parent: Guest {
	int my_song <- [];

	init {
		my_song <- rnd(1, 10);
		isGoingToDJ <- false;
	}

	reflex dance when: is_inside and !is_leaving and !isGoingToDJ and last_action = "Dance" {
	    if (target = nil) {
	        target <- any_location_in(dance_floor);
	        is_dancing <- true;
	    }
	    
	    do goto target: target speed: 1.5;
	    if (location distance_to target < 1.0) {
	        float reward <- 5.0; 
	        
	        string key <- last_state + last_action; 
	        q_table[key] <- q_table[key] + alpha * (reward - q_table[key]);
	        
	        target <- nil;
	        happiness <- min([happiness + 0.05, 1.0]);
	    }
	}
	
	reflex chill when: is_inside and !is_leaving and last_action = "Chill" {
        if (target = nil) { target <- any_location_in(chill_area); is_dancing <- false; }
        do goto target: target speed: 1.0; 
        
        if (location distance_to target < 2.0) {
            float reward <- -5.0; // <--- REWARD NEGATIVO! (Si annoia a morte)
            
            string key <- last_state + last_action; 
            q_table[key] <- q_table[key] + alpha * (reward - q_table[key]);
            
            target <- nil;
            happiness <- max([happiness - 0.1, 0.0]); // Diventa triste
        }
    }

	reflex request_song when: is_inside and !is_leaving and flip(0.1) {
		// with reinforcement learning i have confilcts with the target so the guest can only 
		// aske fo the song by a message
		int s <- one_of(my_song);
		do start_conversation to: [dj] protocol: "fipa-request" performative: "request" contents: [s];

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
	
	//gestisco anche la boredom con il RL perchè altrimenti va in conflitto se lo faccio randomicamente
	reflex increase_boredom when: is_inside and !is_dancing {
		boredom <- boredom + 1;
	}

	reflex dance when: is_inside and !is_leaving and last_action = "Dance" {
	   if (target = nil) {
            target <- any_location_in(dance_floor);
            is_dancing <- true;
        }
        
        do goto target: target speed: 0.6; 
        // Quando arriva in pista:
        if (location distance_to target < 1.0) {
            // Più si annoia, meno gli piace ballare.
            // Se boredom è alta (es. > 100), il reward diventa negativo!
            float reward <- 2.0 - (boredom / 30.0); 

            string key <- last_state + last_action; 
            q_table[key] <- q_table[key] + alpha * (reward - q_table[key]);
            
            // Effetti collaterali
            if (reward > 0) {
                happiness <- min([happiness + 0.02, 1.0]);
                boredom <- max([boredom - 10, 0]); 
            } else {
                happiness <- max([happiness - 0.05, 0.0]); 
            }
            
            target <- nil;
        }
    
	}
	
	reflex chill when: is_inside and !is_leaving and last_action = "Chill" {
        if (target = nil) { target <- any_location_in(chill_area); is_dancing <- false; }
        do goto target: target speed: 1.0; 
        
        if (location distance_to target < 2.0) {
            float reward <- 5.0; 
            
            string key <- last_state + last_action; 
            q_table[key] <- q_table[key] + alpha * (reward - q_table[key]);
            
            target <- nil;
            happiness <- min([happiness + 0.1, 1.0]); 
            boredom <- 0; 
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

//		display charts {
//			chart "Global Happiness Over Time" type: series {
//				data "Average Happiness" value: global_happiness color: #green;
//			}
//
//		}

		display charts {
	    chart "Learning Process (Failures)" type: series {
	        data "Bar Refusals Cumulative" value: tot_refuse color: #red;
	    }
		}

		monitor "Current Time" value: current_tick;
		monitor "Global Happiness" value: global_happiness;
		monitor "Guests Inside" value: length(Guest where each.is_inside);
	}

//	init {
//		inspect "Agent Beliefs" value: (list(Dancer) + list(ShyPerson)) attributes: ['name', 'is_inside'] type: table;
//	}

}