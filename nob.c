#define NOB_IMPLEMENTATION
#include "nob.h"

int main(int argc, char **argv) {
    NOB_GO_REBUILD_URSELF(argc, argv);

    Nob_Cmd cmd = {0};

    nob_cmd_append(&cmd, "cc");
    nob_cmd_append(&cmd, "-o", "window");
    nob_cmd_append(&cmd, "src/main.c");
    nob_cmd_append(&cmd, "-I", "libs/rgfw");
    nob_cmd_append(&cmd, "-lX11", "-lGL", "-lm", "-lXrandr");
    nob_cmd_append(&cmd, "-Wall", "-Wextra");

    if (!nob_cmd_run_sync(cmd)) return 1;

    return 0;
}
