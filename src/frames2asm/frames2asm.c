/*******************************************************************************
 * File: frames2asm.c
 * Author: Christoffer Rehn
 * Last modified: 30/4/2015
 *
 * Converts frames 1.gif to argv[1].gif in the frames directory into ARM
 * assembly format and outputs the result to standard output.
 *
 * Blockwise delta encoding between consecutive frames is used as compression.
 * The first byte of each frame specifies which blocks changed (there are only
 * 8 blocks in total). Each 5x8 pixel block is packed into 5 bytes.
 ******************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define IMAGE_WIDTH 23
#define IMAGE_HEIGHT 16
#define BLOCK_WIDTH 5
#define BLOCK_HEIGHT 8

#define NUM_CHARS 8
#define BYTES_PER_CHAR 5

#define GET_PIXEL_R(x, y) *(data + ((y) * IMAGE_WIDTH * comp) + ((x) * comp))
#define SET_BIT(byte, n) ((byte) |= 1 << (n))
#define BIT_IS_SET(byte, n) ((byte >> n) & 1)

int comp;
int num_bytes = 0;

// Two previous frames
unsigned char prev[NUM_CHARS][BYTES_PER_CHAR];
unsigned char curr[NUM_CHARS][BYTES_PER_CHAR];

int is_diff_char(int c) {
    for (int i = 0; i < BYTES_PER_CHAR; ++i)
        if (curr[c][i] != prev[c][i])
            return 1;
    return 0;
}

void delta_compress(int frame) {
    unsigned char delta = 0x00;
    for (int i = 0; i < NUM_CHARS; ++i)
        if (is_diff_char(i) || frame == 1) // Refresh whole screen at frame 1
            SET_BIT(delta, i);
    printf("DEFB 0x%02x", delta);
    ++num_bytes;
    for (int i = 0; i < NUM_CHARS; ++i)
        if (BIT_IS_SET(delta, i)) {
            printf(",0x%02x,0x%02x,0x%02x,0x%02x,0x%02x",
                   curr[i][0], curr[i][1], curr[i][2], curr[i][3], curr[i][4]);
            num_bytes += 5;
        }
    printf("\n");
}

void copy_curr_to_prev(void) {
    for (int i = 0; i < NUM_CHARS; ++i)
        for (int j = 0; j < BYTES_PER_CHAR; ++j)
            prev[i][j] = curr[i][j];
}

// Packs a frame into 40-bytes-per-frame format
void pack_frame(unsigned char *data) {
    int c = 0;
    unsigned char b1, b2, b3, b4, b5;
    for (int y_block = 0; y_block < 2; ++y_block) {
        for (int x_block = 0; x_block < 4; ++x_block) {
            int x_from = x_block * (BLOCK_WIDTH + 1);
            int x_to = x_from + BLOCK_WIDTH;
            int y_from = y_block * BLOCK_HEIGHT;
            int y_to = y_from + BLOCK_HEIGHT;
            b1 = b2 = b3 = b4 = b5 = 0x00;
            for (int y = y_from; y < y_to; ++y) {
                for (int x = x_from; x < x_to; ++x)
                    if (GET_PIXEL_R(x, y) == 0) {
                        int i = ((y - y_from) * BLOCK_WIDTH) + (x - x_from);
                        if (i < 8)
                            SET_BIT(b1, 7 - i);
                        else if (i < 16)
                            SET_BIT(b2, 7 - (i - 8));
                        else if (i < 24)
                            SET_BIT(b3, 7 - (i - 16));
                        else if (i < 32)
                            SET_BIT(b4, 7 - (i - 24));
                        else
                            SET_BIT(b5, 7 - (i - 32));
                    }
            }
            curr[c][0] = b1;
            curr[c][1] = b2;
            curr[c][2] = b3;
            curr[c][3] = b4;
            curr[c][4] = b5;
            c++;
        }
    }
}

int main(int argc, char **argv) {
    int num_frames = atoi(argv[1]);
    for (int i = 1; i <= num_frames; ++i) {
        char filename[32];
        sprintf(filename, "frames/%d.gif", i);
        int w, h;
        unsigned char *data = stbi_load(filename, &w, &h, &comp, 0);
        if (data == NULL) {
            fprintf(stderr, "Couldn't load image %s\n", filename);
            return EXIT_FAILURE;
        }
        if (w != IMAGE_WIDTH || h != IMAGE_HEIGHT) {
            fprintf(stderr, "Images should be monochrome %dx%d\n",
                            IMAGE_WIDTH, IMAGE_HEIGHT);
            return EXIT_FAILURE;
        }
        copy_curr_to_prev();
        pack_frame(data);
        delta_compress(i);
        stbi_image_free(data);
    }
    fprintf(stderr, "Compressed %d frames to %d KB (%d KB raw)\n",
                    num_frames,
                    num_bytes / 1024,
                    (num_frames * 40) / 1024);
    return EXIT_SUCCESS;
}