/***
* Name: Tram
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Tram

import "../MAIN.gaml"
import "PublicTransport.gaml"

species Tram parent:PublicTransport {
	
	reflex move when: status = "moving"{
		if location = target.location {
			//mise à jour du retard moyen du tram
			mean_late_time <- (mean_late_time * target_seq_stop + (target_arrival_time - current_time)*(-1))/target_seq_stop;
			if last_target{
				// le transport est arrivé à son terminus
				write "Tram terminus";
				do die;
			}else{
				status <- "waiting";
			}	
		}else{
			do goto target: target;
		}
	}
	
	aspect arrowAspect { 
    	draw square(1) color: #green end_arrow: 80 rotate: heading-90 empty: false border: #black; 
	}
	
}