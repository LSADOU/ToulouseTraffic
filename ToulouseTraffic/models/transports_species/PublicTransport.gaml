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
	
	TransportLine tp_line <- nil;
	Hub target <- nil;
	int target_seq_stop <- 0;
	int target_arrival_time <- 0;
	int target_departure_time <- 0;
	bool last_target <- false;
	
	reflex departure_timer when: ((target_departure_time <= current_time and day_of_departure = current_day)
									or day_of_departure < current_day) and status = "waiting"{
		status <- "moving";
		target_seq_stop <- target_seq_stop +1;
		ask tp_line{
			list target_info <- self.getHubInfo(myself.id,myself.target_seq_stop);
			myself.target <- Hub(target_info[0]);
			myself.target_arrival_time <- target_info[1];
			myself.target_departure_time <- target_info[2];
			myself.last_target <- target_info[3];
		}
	}
	
	reflex move when: status = "moving"{}
	
	aspect base{
		draw circle(80) color: #blue border: #black;
	}
}

