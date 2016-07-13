#include <tap.h>

int main (void) {
    plan(3);
    is("good", "good", "a thing that works");
    is("bad", "good", "a thing that doesn't");
    ok(1, "well that's fine, then");
    done_testing();
}
