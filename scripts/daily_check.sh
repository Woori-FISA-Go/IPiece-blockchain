#!/bin/bash
echo "📊 $(date) - Daily Check"
./check_network.sh
./check_disk.sh
echo "---"
