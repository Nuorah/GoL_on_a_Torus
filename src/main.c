#define RGFW_IMPLEMENTATION
#define RGFW_OPENGL
#include "RGFW.h"

#include <GL/gl.h>
#include <stdio.h>

int main(void) {
    RGFW_window *win = RGFW_createWindow(
        "hello rgfw",
        0, 0,
        800, 600,
        RGFW_windowCenter | RGFW_windowOpenGL
    );

    if (!win) {
        fprintf(stderr, "failed to create window\n");
        return 1;
    }

    printf("window created\n");

    while (RGFW_window_shouldClose(win) == RGFW_FALSE) {
        RGFW_event event;
        while (RGFW_window_checkEvent(win, &event)) {
            if (event.type == RGFW_quit) break;
        }

        // black screen, we're gaming
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        RGFW_window_swapBuffers_OpenGL(win);
    }

    RGFW_window_close(win);
    printf("window closed\n");

    return 0;
}
