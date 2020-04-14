/***
* Name: Hub
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Hub

import "../MAIN.gaml"
import "TransportLine.gaml"

species Hub{
	
	string id <- "0";
	string name <- nil;
	
	//This list store all the transport line that pass trough this hub
	list<TransportLine> lines <- nil;
	
	aspect base { 
    	draw square(20) color: #white empty: false border: #black; 
	}
}



