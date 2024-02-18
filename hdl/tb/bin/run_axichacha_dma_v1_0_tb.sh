#!/bin/bash
set -e

# On Windows: Run in WSL.

# Execute gtkwave if it's not open
pidof gtkwave >/dev/null
if [[ $? -ne 0 ]] ; then
    echo "Running gtkwave..."
    gtkwave ./tb.vcd & > /dev/null
fi

function do_test {    
    DEF_NUM_BLOCKS=$1
    DEF_TDATA_WIDTH=$2
    DEF_NUMBIGBLOCKS=$3

    # Generate test files
    python3 chacha.py $DEF_NUM_BLOCKS $DEF_TDATA_WIDTH $DEF_NUMBIGBLOCKS

    # Compile
    iverilog -DTDATAWIDTH=$DEF_TDATA_WIDTH -DNUMBLOCKS=$DEF_NUM_BLOCKS -DNUMBIGBLOCKS=$DEF_NUMBIGBLOCKS -o /tmp/tb -pfileline=1 -g2005 -y ../ -y ../../src/ ../axichacha_dma_v1_0_tb.v 

    # Run
    vvp /tmp/tb
}
do_test 16 32 1
do_test 1 32 1
do_test 16 32 1
do_test 1 512 1
do_test 16 32 1
do_test 32 1024 1

do_test 1 32 16
do_test 16 32 16
do_test 1 512 16
do_test 16 32 16
do_test 32 1024 16
