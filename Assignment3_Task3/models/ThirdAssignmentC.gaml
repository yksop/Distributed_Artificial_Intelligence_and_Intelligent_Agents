/**
* Name: Task2_Festival_Challenge1
* Description: Guests optimize global utility considering crowd mass preferences
* Challenge 1: Global Utility Function with Crowd Mass - PROPERLY FIXED
*/

model Task2_Festival_Challenge1

global {
	int num_guests <- 15;
	int num_stages <- 4;
	float show_duration <- 500.0;
	float elapsed_time <- 0.0;
	float global_utility <- 0.0;
	float initial_global_utility <- 0.0;
	float previous_global_utility <- 0.0;
	bool optimization_phase <- false;
	bool optimization_completed <- false;
	int optimization_rounds <- 0;
	int max_optimization_rounds <- 10;
	float convergence_threshold <- 0.001;
	Guest leader <- nil;

	init {
		write "=== FESTIVAL SIMULATION START ===";
		
		create Stage number: num_stages {
			location <- {rnd(10, 90), rnd(10, 90)};
			light_show <- rnd(100) / 100.0;
			sound_quality <- rnd(100) / 100.0;
			music_style <- rnd(100) / 100.0;
			my_color <- rnd_color(200);
			write "Stage " + name + " - Light: " + (light_show with_precision 2) + 
			      " Sound: " + (sound_quality with_precision 2) + 
			      " Music: " + (music_style with_precision 2);
		}

		create Guest number: num_guests {
			location <- {rnd(10, 90), rnd(10, 90)};
			pref_light <- rnd(100) / 100.0;
			pref_sound <- rnd(100) / 100.0;
			pref_music <- rnd(100) / 100.0;
			pref_crowd <- rnd(100) / 100.0;
			
			write "Guest " + name + 
			      " - Pref Light: " + (pref_light with_precision 2) + 
			      " Sound: " + (pref_sound with_precision 2) + 
			      " Music: " + (pref_music with_precision 2) +
			      " Crowd: " + (pref_crowd with_precision 2);
		}

		leader <- first(Guest);
		leader.is_leader <- true;
		write "Leader assigned: " + leader.name;
		
		write "=== GUESTS REQUESTING STAGE INFO ===";
		ask Guest {
			do request_stage_info;
		}
	}

	float calculate_global_utility {
		global_utility <- 0.0;
		ask Guest {
			if (has_chosen and target_stage != nil) {
				// Recalculate with current crowd
				current_utility <- calculate_utility(target_stage, target_stage.guest_count);
				global_utility <- global_utility + current_utility;
			}
		}
		return global_utility;
	}

	reflex monitor_optimization when: optimization_phase {
		previous_global_utility <- global_utility;
		do calculate_global_utility;
		
		float improvement <- global_utility - previous_global_utility;
		
		if (optimization_rounds >= max_optimization_rounds or 
		    (optimization_rounds > 0 and improvement < 0.001)) {
			optimization_phase <- false;
			optimization_completed <- true; // MARK AS COMPLETED!
			
			if (improvement < 0.001 and optimization_rounds > 0) {
				write "\n*** CONVERGENCE REACHED ***";
			} else {
				write "\n*** MAXIMUM OPTIMIZATION ROUNDS REACHED ***";
			}
			
			write "Initial Global Utility: " + (initial_global_utility with_precision 2);
			write "Final Global Utility: " + (global_utility with_precision 2);
			float total_improvement <- global_utility - initial_global_utility;
			write "Total Improvement: " + (total_improvement with_precision 2) + 
			      " (" + (total_improvement / initial_global_utility * 100 with_precision 1) + "%)";
			write "Guests can now enjoy their show!\n";
		} else {
			if (cycle mod 50 = 0) {
				ask leader {
					do coordinate_guests;
				}
			}
		}
	}

	reflex festival_loop {
		elapsed_time <- elapsed_time + 1;
		if (elapsed_time >= show_duration) {
			write "\n=== NEW SHOW ROUND ===";
			optimization_phase <- false;
			optimization_completed <- false; // RESET for new round!
			optimization_rounds <- 0;
			
			ask Guest {
				has_chosen <- false;
				target_stage <- nil;
				best_utility <- -1.0;
				responses_received <- 0;
				stage_utilities <- [];
				current_utility <- 0.0;
				do request_stage_info;
			}

			ask Stage {
				light_show <- rnd(100) / 100.0;
				sound_quality <- rnd(100) / 100.0;
				music_style <- rnd(100) / 100.0;
				my_color <- rnd_color(200);
			}

			elapsed_time <- 0.0;
		}
	}
}

species Stage skills: [fipa] {
	float light_show;
	float sound_quality;
	float music_style;
	rgb my_color;
	int guest_count <- 0 update: Guest count (each.target_stage = self and each.has_chosen);

	reflex handle_requests when: !empty(requests) {
		loop msg over: requests {
			do start_conversation to: [msg.sender] 
			   protocol: 'fipa-request' 
			   performative: 'inform' 
			   contents: [light_show, sound_quality, music_style, guest_count, my_color];
		}
		requests <- [];
	}

	aspect default {
		draw square(8) color: my_color border: #black;
		draw "Stage " + int(self) at: {location.x - 3, location.y - 8} 
		     color: #black font: font("Arial", 10, #bold);
		draw "Guests: " + guest_count at: {location.x - 2, location.y + 8} 
		     color: #blue font: font("Arial", 9, #bold);
	}
}

species Guest skills: [moving, fipa] {
	float pref_light;
	float pref_sound;
	float pref_music;
	float pref_crowd;
	Stage target_stage <- nil;
	float best_utility <- -1.0;
	float current_utility <- 0.0;
	bool has_chosen <- false;
	int responses_received <- 0;
	map<Stage, float> stage_utilities <- [];
	bool is_leader <- false;
	bool received_leader_command <- false;

	reflex wander_around when: !has_chosen {
		do wander speed: 0.3;
	}

	action request_stage_info {
		do start_conversation to: list(Stage) 
		   protocol: 'fipa-request' 
		   performative: 'request' 
		   contents: ["get_info"];
	}

	float calculate_utility (Stage stage, int crowd_size) {
		float base_utility <- (pref_light * stage.light_show) + 
		                      (pref_sound * stage.sound_quality) + 
		                      (pref_music * stage.music_style);
		
		float normalized_crowd <- crowd_size / num_guests;
		float crowd_utility <- 1.0 - abs(pref_crowd - normalized_crowd);
		float total_utility <- (0.7 * base_utility) + (0.3 * crowd_utility);
		
		return total_utility;
	}

	reflex evaluate_responses when: !empty(informs) and !has_chosen {
		loop msg over: informs {
			Stage sender <- Stage(msg.sender);
			list data <- msg.contents;
			float s_light <- float(data[0]);
			float s_sound <- float(data[1]);
			float s_music <- float(data[2]);
			int s_crowd <- int(data[3]);

			float utility <- self.calculate_utility(sender, s_crowd);
			stage_utilities[sender] <- utility;
			responses_received <- responses_received + 1;

			if (utility > best_utility) {
				best_utility <- utility;
				target_stage <- sender;
			}
		}
		informs <- [];

		if (responses_received >= num_stages and target_stage != nil) {
			has_chosen <- true;
			current_utility <- best_utility;
			write "Guest " + name + " initially chooses " + target_stage.name + 
			      " with utility: " + (best_utility with_precision 3);
		}
	}

	reflex leader_optimize when: is_leader and !optimization_phase and !optimization_completed and
	                              (Guest count (each.has_chosen)) = num_guests {
		write "\n*** LEADER STARTING OPTIMIZATION ***";
		initial_global_utility <- world.calculate_global_utility();
		write "Initial Global Utility: " + (initial_global_utility with_precision 2);
		
		optimization_phase <- true;
		optimization_rounds <- 0;
		previous_global_utility <- initial_global_utility;
		do coordinate_guests;
	}

	action coordinate_guests {
		optimization_rounds <- optimization_rounds + 1;
		write "\n--- Optimization Round " + optimization_rounds + " ---";
		
		// Calculate current situation
		float current_global <- world.calculate_global_utility();
		
		// Find THE BEST single move that improves global utility
		Guest best_guest <- nil;
		Stage best_new_stage <- nil;
		float best_improvement <- 0.0;
		
		// Test every possible move
		ask Guest where (!each.is_leader) {
			Stage my_current_stage <- target_stage;
			
			loop potential_stage over: list(Stage) {
				if (potential_stage != my_current_stage) {
					// Simulate this move
					float simulated_global <- 0.0;
					
					ask Guest {
						if (self = myself) {
							// This guest moves
							int new_crowd <- potential_stage.guest_count + 1;
							float new_util <- calculate_utility(potential_stage, new_crowd);
							simulated_global <- simulated_global + new_util;
						} else {
							// Other guests recalculate with new crowds
							Stage their_stage <- target_stage;
							int adjusted_crowd <- their_stage.guest_count;
							
							if (their_stage = my_current_stage) {
								adjusted_crowd <- adjusted_crowd - 1; // Someone left
							} else if (their_stage = potential_stage) {
								adjusted_crowd <- adjusted_crowd + 1; // Someone joined
							}
							
							float recalc_util <- calculate_utility(their_stage, adjusted_crowd);
							simulated_global <- simulated_global + recalc_util;
						}
					}
					
					float improvement <- simulated_global - current_global;
					
					if (improvement > best_improvement) {
						best_improvement <- improvement;
						best_guest <- self;
						best_new_stage <- potential_stage;
					}
				}
			}
		}
		
		// Execute ONLY if it improves
		if (best_guest != nil and best_improvement > 0.001) {
			ask best_guest {
				Stage old_stage <- target_stage;
				target_stage <- best_new_stage;
				current_utility <- calculate_utility(target_stage, target_stage.guest_count + 1);
				
				write "Guest " + name + " switches from " + old_stage.name + 
				      " to " + target_stage.name + 
				      " (utility: " + (current_utility with_precision 3) + 
				      ", global improvement: +" + (best_improvement with_precision 3) + ")";
			}
		} else {
			write "No beneficial moves found - stopping optimization!";
			optimization_phase <- false;
			optimization_completed <- true; // MARK AS COMPLETED!
		}
	}

	reflex move_to_stage when: has_chosen and target_stage != nil {
		do goto target: target_stage.location speed: 0.5;
	}

	aspect default {
		rgb display_color <- #gray;
		
		if (has_chosen and target_stage != nil) {
			display_color <- target_stage.my_color;
		}
		
		if (is_leader) {
			draw circle(3) color: display_color border: #gold;
			draw "L" at: {location.x - 1, location.y - 4} color: #gold font: font("Arial", 8, #bold);
		} else {
			draw circle(2) color: display_color border: #black;
		}
		
		if (has_chosen) {
			draw string(current_utility with_precision 2) at: {location.x + 2, location.y - 2} 
			     color: #black font: font("Arial", 7, #plain);
		}
	}
}

experiment Festival_Challenge1 type: gui {
	//parameter "Number of Guests" var: num_guests min: 5 max: 50;
	//parameter "Number of Stages" var: num_stages min: 2 max: 10;
	//parameter "Max Optimization Rounds" var: max_optimization_rounds min: 1 max: 20;
	
	output {
		display main_display {
			species Stage aspect: default;
			species Guest aspect: default;
		}
		
		monitor "Guests who chose" value: Guest count (each.has_chosen);
		monitor "Global Utility" value: global_utility with_precision 2;
		monitor "Initial Global Utility" value: initial_global_utility with_precision 2;
		monitor "Optimization Phase" value: optimization_phase;
		monitor "Optimization Rounds" value: optimization_rounds;
		monitor "Improvement" value: (global_utility - initial_global_utility) with_precision 2;
	}
}