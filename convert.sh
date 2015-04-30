#!/bin/bash

fps=15.625

c1='\033[0;33m'
c2='\033[0;32m'
nc='\033[0m'

echo -e "${c2}File: clips/${1}${nc}"
echo -e "${c1}Removing old stuff...${nc}"

rm frames/*

echo -e "${c1}Extracting frames at ${fps} FPS...${nc}"

bin/ffmpeg -loglevel error -stats -i clips/$1 -r $fps frames/%d.jpg
frame_count=`ls -1 frames | wc -l`

echo -e "${c2}Extracted ${frame_count} frames${nc}"

echo -e "s_mov_playing DEFB \"Playing\", 0\nALIGN" > src/movie.s
echo -e "s_mov_title DEFB \"${1}\", 0\nALIGN" >> src/movie.s
echo -e "mov_frame_count DEFW ${frame_count}" >> src/movie.s

echo -e "${c1}Preprocessing frames...${nc}"

for i in `seq 1 ${frame_count}`; do
    printf "$(((100*i)/frame_count))%% (${i}/${frame_count})\r"
    convert frames/$i.jpg -contrast -resize 23x16! -type bilevel frames/$i.gif
done

echo -e "\n${c1}Converting frames to assembly...${nc}"

echo "mov_data" >> src/movie.s
bin/frames2asm $frame_count >> src/movie.s
echo -e "ALIGN" >> src/movie.s

echo -e "${c2}Done!${nc}"