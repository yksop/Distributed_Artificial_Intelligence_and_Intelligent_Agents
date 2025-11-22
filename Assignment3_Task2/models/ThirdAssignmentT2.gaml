/**
* Name: Task2_Festival
* Description: Guests choose stages based on utility function using FIPA communication
*/

model Task2_Festival
global {
	int num_guests <- 15;
	int num_stages <- 4;
	float show_duration <- 200.0; 
	float elapsed_time <- 0.0;

	init {
		write "=== FESTIVAL SIMULATION START ===";
		create Stage number: num_stages {
			// in this way I have random values for each variable
			// If i put the initialization inside the species all the guest will have the same random values
			location <- {rnd(10, 90), rnd(10, 90)};
			light_show <- rnd(100) / 100.0;
			sound_quality <- rnd(100) / 100.0;
			music_style <- rnd(100) / 100.0;
			my_color <- rnd_color(200);
			write "Stage " + name + " creato - Light: " + (light_show with_precision 2) + " Sound: " + (sound_quality with_precision 2) + " Music: " + (music_style with_precision 2);
		}

		create Guest number: num_guests {
			location <- {rnd(10, 90), rnd(10, 90)};
			pref_light <- rnd(100) / 100.0;
			pref_sound <- rnd(100) / 100.0;
			pref_music <- rnd(100) / 100.0;
			write "Guest " + name + " creato - Pref Light: " + (pref_light with_precision 2) + " Sound: " + (pref_sound with_precision 2) + " Music: " + (pref_music with_precision 2);
		}

		write "=== GUESTS REQUESTING STAGE INFO ===";
		ask Guest {
			do request_stage_info;
		}
	}

	reflex festival_loop {
    elapsed_time <- elapsed_time + 1;
    if (elapsed_time >= show_duration) {
        write "=== NUOVO ROUND DI SPETTACOLI ===";
        ask Guest {
            has_chosen <- false;
            target_stage <- nil;
            best_utility <- -1.0;
            responses_received <- 0;
            stage_utilities <- [];
            //location <- {rnd(10, 90), rnd(10, 90)};
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
			do start_conversation to: [msg.sender] protocol: 'fipa-request' performative: 'inform' contents: [light_show, sound_quality, music_style, my_color];
		}
		requests <- [];
	}

	aspect default {
		draw square(5) color: my_color border: #black;
		draw "Stage " + int(self) at: {location.x - 3, location.y - 6} color: #black font: font("Arial", 10, #bold);
	}

}

species Guest skills: [moving, fipa] {
	float pref_light;
	float pref_sound;
	float pref_music;
	Stage target_stage <- nil;
	float best_utility <- -1.0;
	bool has_chosen <- false;
	int responses_received <- 0;
	map<Stage, float> stage_utilities <- [];
	
	reflex wander_around when: !has_chosen {
    	do wander speed: 0.3;  // Vagano finché non scelgono uno stage
    }

	action request_stage_info {
		do start_conversation to: list(Stage) protocol: 'fipa-request' performative: 'request' contents: ["get_info"];
	}

	reflex evaluate_responses when: !empty(informs) and !has_chosen {
		loop msg over: informs {
			Stage sender <- Stage(msg.sender);
			list data <- msg.contents;
			float s_light <- float(data[0]);
			float s_sound <- float(data[1]);
			float s_music <- float(data[2]);

			float utility <- (pref_light * s_light) + (pref_sound * s_sound) + (pref_music * s_music);
			stage_utilities[sender] <- utility;
			responses_received <- responses_received + 1;
			write "utility " + sender.name + " for " + name + " is " + utility;
			if (utility > best_utility) {
				best_utility <- utility;
				target_stage <- sender;
			}
		}
		informs <- [];

		if (responses_received >= num_stages and target_stage != nil) {
			has_chosen <- true;
			write "Guest " + name + " choses " + target_stage.name + " con utility: " + (best_utility with_precision 3);
		}
	}


	reflex move_to_stage when: has_chosen and target_stage != nil {
		do goto target: target_stage.location speed: 0.5;
	}


	aspect default {
		rgb display_color <- has_chosen ? target_stage.my_color : #gray;
		draw circle(2) color: display_color border: #black;

	}
}

experiment Festival_Task2 type: gui {
	output {
		display main_display{
			species Stage aspect: default;
			species Guest aspect: default;
		}
		monitor "Guests who chose" value: Guest count (each.has_chosen);
	}
}
