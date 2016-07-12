#include <cups/cups.h>

int main (int argc, char *argv[]) {
    cupsBackChannelRead(NULL, 0, 0.0);
    return 0;
}
