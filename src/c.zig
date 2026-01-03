pub const c = @cImport({
    @cInclude("glad.h");
    @cInclude("glfw/include/GLFW/glfw3.h");
    @cInclude("dcimgui.h");
    @cInclude("dcimgui_impl_glfw.h");
    @cInclude("dcimgui_impl_opengl3.h");
});
