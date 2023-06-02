#!/bin/bash

# This script prevents slither from analyzing the test and script directories

mv test _test
mv script _script

slither .

mv _test test
mv _script script
