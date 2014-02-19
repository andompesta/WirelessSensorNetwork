#!/bin/bash

counter=$((0));
NUM_TESTS=$((20));

date1=$(date +"%s");
date2=$(date +"%s");
while [ $counter -lt $NUM_TESTS ]; do
	echo The counter is $counter
	let counter=counter+1
	date1=$(date +"%s");
	python basic_sim.py > 2&> "RR-30-OUTPUT-"$counter".txt"
	date2=$(date +"%s");
	diff=$(($date2-$date1))
	echo "execution time ---->  $diff";
	echo "$(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
done
