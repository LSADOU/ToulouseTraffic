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
			//mise à jour du retard moyen du bus
			mean_late_time <- (mean_late_time * seq_stop + ((int(stop_times[0,seq_stop]) - current_time)*(-1)))/seq_stop;
			if seq_stop = stop_times.rows-1{
				// le transport est arrivé à son terminus
				do die;
			}else{
				status <- "waiting";
			}	
		}else{
			do goto target: target on: path_to_use;
		}
	}
	
	aspect base { 
    	draw circle(150) color: color rotate: heading-90 empty: false border: #black;
	}
	
}