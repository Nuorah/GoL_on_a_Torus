#version 330 core
in vec2 FragUV;
out vec4 FragColor;

uniform sampler2D uGrid;
uniform vec2 uTexelSize; // 1.0 / grid_size

void main() {
    // sample all 8 neighbors
    float tl = texture(uGrid, FragUV + vec2(-1, -1) * uTexelSize).r;
    float t  = texture(uGrid, FragUV + vec2( 0, -1) * uTexelSize).r;
    float tr = texture(uGrid, FragUV + vec2( 1, -1) * uTexelSize).r;
    float l  = texture(uGrid, FragUV + vec2(-1,  0) * uTexelSize).r;
    float r  = texture(uGrid, FragUV + vec2( 1,  0) * uTexelSize).r;
    float bl = texture(uGrid, FragUV + vec2(-1,  1) * uTexelSize).r;
    float b  = texture(uGrid, FragUV + vec2( 0,  1) * uTexelSize).r;
    float br = texture(uGrid, FragUV + vec2( 1,  1) * uTexelSize).r;

    float neighbors = tl + t + tr + l + r + bl + b + br;
    float self = texture(uGrid, FragUV).r;

    // Conway's rules:
    // alive + 2 or 3 neighbors = stay alive
    // dead + exactly 3 neighbors = become alive
    // everything else = dead
    
    float alive;
    if (self > 0.5) {
        // currently alive
        alive = (neighbors > 1.5 && neighbors < 3.5) ? 1.0 : 0.0;
    } else {
        // currently dead
        alive = (neighbors > 2.5 && neighbors < 3.5) ? 1.0 : 0.0;
    }

    FragColor = vec4(alive, 0.0, 0.0, 1.0);
}
