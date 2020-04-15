/***
* Name: PublicTransport
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model PublicTransport

import "../MAIN.gaml"
import "../network_species/TransportLine.gaml"
import "../network_species/Hub.gaml"

species PublicTransport parent: Transport{
	string id <- "0";
	string status <- nil;
	int day_of_departure <- 0;
	float mean_late_time <- 0.0;
	rgb color <- #black;
	TransportLine tp_line <- nil;
	graph path_to_use <- nil;
	Hub target <- nil;
	// stop_times[i] = [int arrival_time, int departure_time, Hub hub_to_collect]
	matrix stop_times <- [];
	int seq_stop <- 0;
	
	
	reflex departure_timer when: ((int(stop_times[1,seq_stop]) <= current_time and day_of_departure = current_day)
									or day_of_departure < current_day) and status = "waiting"{
		status <- "moving";
		seq_stop <- seq_stop +1;
		target <- Hub(stop_times[2,seq_stop]);
	}
	
	reflex move when: status = "moving"{}
	
	aspect base{
		draw circle(80) color: #black border: #red;
	}
}

