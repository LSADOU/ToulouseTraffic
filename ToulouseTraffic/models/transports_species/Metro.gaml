/***
* Name: Metro
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Metro

import "../MAIN.gaml"
import "Transport.gaml"

//species that represent metro
species Metro parent: Transport {
	
	reflex move when: status = "moving"{
		if location = target {
			//mise à jour du retard moyen du metro
			mean_late_time <- (mean_late_time * target_seq_stop + (int(trip_stop_times[4,target_seq_stop]) - current_time)*(-1))/target_seq_stop;
			if target_seq_stop = trip_stop_times.rows-1{
				// le transport est arrivé à son terminus
				write "Metro terminus";
				do die;
			}else{
				status <- "waiting";
			}	
		}else{
			do goto target: target;
		}
	}
	
	aspect arrowAspect { 
    	draw square(1) color: #red end_arrow: 80 rotate: heading-90 empty: false border: #black; 
	}
}

