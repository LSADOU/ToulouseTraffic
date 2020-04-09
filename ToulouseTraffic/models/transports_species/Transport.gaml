/***
* Name: Transport
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Transport

import "../MAIN.gaml"

species Transport skills: [moving]{
	string id <- nil;
	matrix trip_stop_times <- nil;
	int target_seq_stop <- 0;
	string status <- nil;
	point target <- nil;
	int day_of_departure <- 0;
	float mean_late_time <- 0.0;
	
	reflex departure_timer when: ((int(trip_stop_times[5,target_seq_stop]) < current_time and day_of_departure = current_day)
									or day_of_departure < current_day) and status = "waiting"{
		status <- "moving";
		target_seq_stop <- target_seq_stop +1;
		target <- trip_stop_times[2,target_seq_stop];
	}
	
	reflex move when: status = "moving"{}
	
	aspect base{
		draw circle(80) color: #blue border: #black;
	}
}
	