#!/bin/bash

# This script filters all results from the test and script directories

mv test _test
mv script _script

slither .

mv _test test
mv _script script